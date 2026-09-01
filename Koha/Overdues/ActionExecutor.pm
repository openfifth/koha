package Koha::Overdues::ActionExecutor;

# Copyright Open Fifth 2025
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Koha::Logger;
use Koha::Items;
use Koha::Patron::Debarments qw( AddUniqueDebarment );
use C4::Circulation          qw( MarkIssueReturned );
use C4::Context;
use C4::Letters;
use Koha::Notice::Message;
use Koha::Notice::Messages;
use Koha::Patrons;
use Koha::Checkouts;
use Koha::Checkout;
use Koha::DateUtils qw( dt_from_string output_pref );

=head1 NAME

Koha::Overdues::ActionExecutor - Koha Overdue ActionExecutor object set class.

=head2 Class Methods

=cut

=head3 new

Instantiate the class.
=cut

sub new {
    my ($class) = @_;
    my $self = {
        action_batch_queue => [],
        notice_queue       => {},
    };
    return bless $self, $class;
}

=head3 route_item_actions_to_queue

Separate action sets into notice and standard action sets, and calls the relevant enqueing subroutine.

=cut

sub route_item_actions_to_queue {
    my ( $self, $effective_rule_sets, $overdue_item ) = @_;

    my $branchcode     = $self->_resolve_rule_context_branchcode($overdue_item);
    my $categorycode   = $overdue_item->{categorycode};
    my $itemtype       = $overdue_item->{itemtype};
    my $days_overdue   = $overdue_item->{days_overdue};
    my $borrowernumber = $overdue_item->{borrowernumber};

    my $actions_hashes = $effective_rule_sets->{"$branchcode|$categorycode|$itemtype|$days_overdue"}->{actions};

    if ( !$actions_hashes || !@$actions_hashes ) {
        return;
    }

    my %actions = map { $_->{type} => $_ } @$actions_hashes;

    # Build the non-notice action batch first: whether the trigger carries any
    # non-notice action decides how a notice on an already-lost item is treated
    # (see the notice block below).
    my %action_batch;
    for my $type (qw( restrict lost charge mark_returned forgive_fine )) {
        if ( !$actions{$type} ) {
            next;
        }

        if ( !defined $actions{$type}->{value} || $actions{$type}->{value} eq '' ) {
            next;
        }

        $action_batch{$type} = $actions{$type}{value};
    }

    # handle notice
    if ( $actions{notice} && defined $actions{notice}->{notice_code} && $actions{notice}->{notice_code} ne '' ) {

        # Parity with the itemlost = 0 filter legacy overdue_notices.pl applied:
        # once an item is lost, suppress a *bare* overdue reminder — a notice
        # whose trigger does nothing else. A notice that shares its trigger with
        # a non-notice action is an event notification ("item declared lost, you
        # have been charged …") and always sends, on this or a later trigger.
        # Lost items still flow through the pipeline so action triggers (e.g.
        # mark_returned) can act on them.
        my $bare_reminder_on_lost = $overdue_item->{itemlost} && !%action_batch;

        if ( !$bare_reminder_on_lost ) {
            my $mtts = $actions{notice}->{mtts} // [];

            for my $mtt (@$mtts) {
                my $per_mtt_action = { %{ $actions{notice} }, mtt => $mtt };
                delete $per_mtt_action->{mtts};

                $self->add_to_notice_queue(
                    $borrowernumber,
                    $actions{notice}->{notice_code},
                    $mtt,
                    $days_overdue,
                    [ $self->format_notice_item( $overdue_item, $per_mtt_action, $days_overdue ) ],
                );
            }
        }
    }

    # handle action batch
    if (%action_batch) {
        $self->add_to_action_batch_queue(
            {
                item    => $overdue_item,
                delay   => $days_overdue,
                actions => \%action_batch,
            }
        );
    }
}

=head3 print_queues

Dump the populated action-batch and notice queues as one structured line per
queued entry. Called between routing and enactment to give C<--verbose> mode
in C<process_circulation_triggers.pl> a preview of what the script is about
to do. Side-effect free.

=cut

sub print_queues {
    my ($self) = @_;

    printf "ACTION ENACTED: \n";

    foreach my $batch ( @{ $self->{action_batch_queue} } ) {
        my $item = $batch->{item};
        for my $type ( sort keys %{ $batch->{actions} } ) {
            printf "    type=%s value=%s borrower=%s item=%s days_overdue=%s\n",
                $type,
                $batch->{actions}->{$type},
                $item->{borrowernumber},
                $item->{itemnumber},
                $batch->{delay};
        }
    }

    printf "NOTICES ENQUEUED: \n";

    for my $borrowernumber ( sort { $a <=> $b } keys %{ $self->{notice_queue} } ) {
        my $by_code = $self->{notice_queue}{$borrowernumber};
        for my $notice_code ( sort keys %$by_code ) {
            my $by_mtt = $by_code->{$notice_code};
            for my $mtt ( sort keys %$by_mtt ) {
                for my $delay ( sort { $a <=> $b } keys %{ $by_mtt->{$mtt} } ) {
                    my $count = scalar @{ $by_mtt->{$mtt}{$delay} };
                    printf "    letter_code=%s mtt=%s borrower=%s days_overdue=%s items=%s\n",
                        $notice_code, $mtt, $borrowernumber, $delay, $count;
                }
            }
        }
    }
}

=head3 process_action_queue

Process the standard queue.

=cut

sub process_action_queue {
    my ($self) = @_;

    foreach my $batch ( @{ $self->{action_batch_queue} } ) {
        my $overdue_item = $batch->{item};
        my $actions      = $batch->{actions};

        if ( $actions->{restrict} ) {
            $self->enact_restrict($overdue_item);
        }

        if ( $actions->{forgive_fine} ) {
            $self->enact_forgive_fine($overdue_item);
        }

        if ( $actions->{lost} ) {
            $self->enact_lost( $overdue_item, $actions->{lost} );
        }

        if ( $actions->{charge} ) {
            $self->enact_charge($overdue_item);
        }

        if ( $actions->{mark_returned} ) {
            $self->enact_mark_returned($overdue_item);
        }
    }
}

=head3 process_notice_queue

Drain the notice queue, generating a prepared letter and inserting a pending
L<Koha::Notice::Message> row for each bucket
C<< $self->{notice_queue}{$borrowernumber}{$notice_code}{$mtt}{$delay} >>.
Every item routed to the same bucket in L</route_item_actions_to_queue>
renders into one letter via the template's repeat block.

Processes transports in reliability order — C<print>, then C<sms>, then
C<email>. When an C<sms> or C<email> entry can't be delivered (patron has no
C<smsalertnumber> / no C<notice_email_address>), a C<print> entry is
synthesised instead.

Every enqueue is guarded by L</_notice_exists>: a bucket is skipped when a
message_queue row for the same (borrower, letter_code, transport) was already
queued today and is still pending or sent. This makes a re-run idempotent —
including one that lands after C<SendQueuedMessages> has drained the queue to
C<sent> — while still letting a later day's overdue episode notify. It also
covers the synthesised-print case: an explicit or earlier-synthesised print for
the same pair blocks a duplicate fallback.

=cut

sub process_notice_queue {
    my ($self) = @_;

    for my $mtt (qw( print sms email )) {
        for my $borrowernumber ( sort keys %{ $self->{notice_queue} } ) {
            my $by_notice_code = $self->{notice_queue}{$borrowernumber};
            for my $notice_code ( sort keys %$by_notice_code ) {
                my $by_mtt = $by_notice_code->{$notice_code};
                next if !$by_mtt->{$mtt};

                for my $delay ( sort { $a <=> $b } keys %{ $by_mtt->{$mtt} } ) {
                    my $entries = $by_mtt->{$mtt}{$delay};
                    if ( !$entries || !@$entries ) {
                        next;
                    }

                    if ( $mtt eq 'print' ) {
                        next if $self->_notice_exists( $borrowernumber, $notice_code, 'print', [ 'pending', 'sent' ] );
                        $self->_enqueue_letter_for_bucket( $entries, 'print' );
                        next;
                    }

                    my $patron = Koha::Patrons->find($borrowernumber);
                    if ( !$patron ) {
                        Koha::Logger->get->warn("process_notice_queue: borrower $borrowernumber not found — skipping");
                        next;
                    }

                    my $viable = $mtt eq 'sms' ? $patron->smsalertnumber : $patron->notice_email_address;
                    if ($viable) {
                        next if $self->_notice_exists( $borrowernumber, $notice_code, $mtt, [ 'pending', 'sent' ] );
                        $self->_enqueue_letter_for_bucket( $entries, $mtt );
                        next;
                    }

                    if ( $self->_notice_exists( $borrowernumber, $notice_code, 'print', [ 'pending', 'sent' ] ) ) {
                        next;
                    }
                    $self->_enqueue_letter_for_bucket( $entries, 'print' );
                }
            }
        }
    }
}

=head3 _notice_exists

Returns true if a notice message_queue row already exists for this day, for this
(borrowernumber, letter_code) pair. Used to dedup synthesised notice fallbacks
against any notice — explicit, prior-pass synthesised, or leftover from a prior
run — already sitting in the pipeline. Status specific.

=cut

sub _notice_exists {
    my ( $self, $borrowernumber, $code, $type, $status ) = @_;
    my $today = dt_from_string->truncate( to => 'day' )->strftime('%Y-%m-%d %H:%M:%S');

    return Koha::Notice::Messages->search(
        {
            borrowernumber         => $borrowernumber,
            letter_code            => $code,
            message_transport_type => $type,
            status                 => $status,
            time_queued            => { '>=' => $today },
        }
    )->count > 0;
}

=head3 _enqueue_letter_for_bucket

Renders the bucket's items into a single prepared letter and stores it as a
pending L<Koha::Notice::Message> row. C<$mtt> is the transport the message is
queued under — may differ from the entries' originating mtt when this is being
called as a print fallback for an undeliverable sms/email bucket.

=cut

sub _enqueue_letter_for_bucket {
    my ( $self, $entries, $mtt ) = @_;

    my $head           = $entries->[0];
    my $borrowernumber = $head->{item}->{borrowernumber};
    my $notice_code    = $head->{action}->{notice_code};
    my $branchcode     = $self->_resolve_rule_context_branchcode( $head->{item} );

    my $patron = Koha::Patrons->find($borrowernumber);
    if ( !$patron ) {
        Koha::Logger->get->warn("process_notice_queue: borrower $borrowernumber not found — skipping");
        return;
    }

    my @item_rows;
    for my $entry (@$entries) {
        my $item = Koha::Items->find( $entry->{item}->{itemnumber} );
        if ( !$item ) {
            Koha::Logger->get->warn(
                "process_notice_queue: itemnumber $entry->{item}->{itemnumber} not found — skipping");
            next;
        }
        push @item_rows,
            {
            biblio      => $item->biblionumber,
            biblioitems => $item->biblionumber,
            items       => $item->itemnumber,
            issues      => $entry->{item}->{issue_id},
            };
    }

    if ( !@item_rows ) {
        return;
    }

    my $letter = C4::Letters::GetPreparedLetter(
        module      => 'circulation',
        letter_code => $notice_code,
        branchcode  => $branchcode,
        lang        => $patron->lang,
        tables      => {
            borrowers => $borrowernumber,
            branches  => $branchcode,
        },
        substitute => { count    => scalar @item_rows },
        repeat     => { item     => \@item_rows },
        loops      => { overdues => [ map { $_->{items} } @item_rows ] }
        ,    # for compatibility with templates expecting data that can be parsed like [% FOREACH overdue IN overdues %]
        message_transport_type => $mtt,
    );

    if ( !$letter ) {
        Koha::Logger->get->warn(
            "process_notice_queue: no letter for borrower=$borrowernumber code=$notice_code mtt=$mtt — skipping");
        return;
    }

    Koha::Notice::Message->new(
        {
            borrowernumber         => $borrowernumber,
            subject                => $letter->{title},
            content                => $letter->{content},
            content_type           => $letter->{'content-type'} // 'text/plain; charset="UTF-8"',
            letter_code            => $notice_code,
            message_transport_type => $mtt,
            status                 => 'pending',
            time_queued            => dt_from_string(),
        }
    )->store;
}

=head3 format_action_item

Takes in an item, an action, and a delay, and returns a formatted action_item to be processed.

=cut

sub format_action_item {
    my ( $self, $overdue_item, $action_hashref ) = @_;

    return { item => {%$overdue_item}, action => {%$action_hashref}, delay => $overdue_item->{days_overdue} };

    # FIXME: return { item =>  $overdue_item, action => $action_hashref, delay => $overdue_item->{days_overdue} };
}

=head3 format_notice_item

Takes in an item, an action, and a delay, and returns a formatted notice_item to be processed.

=cut

sub format_notice_item {
    my ( $self, $item, $action_hashref, $delay ) = @_;
    return { item => $item, action => $action_hashref, delay => $delay };
}

=head3 add_to_notice_queue

Pushes the given notice items onto the bucket addressed by
C<($borrowernumber, $notice_code, $mtt, $delay)>. Buckets autovivify on first
push.

=cut

sub add_to_notice_queue {
    my ( $self, $borrowernumber, $notice_code, $mtt, $delay, $notice_items ) = @_;
    push @{ $self->{notice_queue}{$borrowernumber}{$notice_code}{$mtt}{$delay} }, @$notice_items;
}

=head3 add_to_action_batch_queue

Adds an action item to the standard queue.

=cut

sub add_to_action_batch_queue {
    my ( $self, $action_item_batch ) = @_;
    push @{ $self->{action_batch_queue} }, $action_item_batch;
}

=head3 enact_restrict

Add an OVERDUES debarment for the patron associated with the overdue item.

=cut

sub enact_restrict {
    my ( $self, $overdue_item ) = @_;
    AddUniqueDebarment(
        {
            borrowernumber => $overdue_item->{borrowernumber},
            type           => 'OVERDUES',
            comment        => "OVERDUES_PROCESS " . output_pref( dt_from_string() ),
        }
    );
}

=head3 enact_lost

Set the item's lost status (and cancel outstanding transfers) via
L<Koha::Item/mark_lost>.

=cut

sub enact_lost {
    my ( $self, $overdue_item, $lost_value ) = @_;
    my $item = Koha::Items->find( $overdue_item->{itemnumber} );
    if ( !$item ) {
        Koha::Logger->get->warn("enact_lost: itemnumber $overdue_item->{itemnumber} not found — skipping");
        return;
    }
    $item->mark_lost($lost_value);
}

=head3 enact_forgive_fine

Forgive any outstanding UNRETURNED OVERDUE accountline(s) for this checkout via
L<Koha::Account/forgive_debit>. Gated by the trigger row's C<forgive_fine> rule
value in L</process_action_queue>; legacy C<WhenLostForgiveFine> is deprecated
and not consulted.

The audit-trail side effects (UNRETURNED → LOST status flip and zero-amount
accountline cleanup) are not part of this action — they fire from
L<Koha::Item/mark_lost>.

=cut

sub enact_forgive_fine {
    my ( $self, $overdue_item ) = @_;

    my $accountlines = Koha::Account::Lines->search(
        {
            borrowernumber  => $overdue_item->{borrowernumber},
            itemnumber      => $overdue_item->{itemnumber},
            issue_id        => $overdue_item->{issue_id},
            debit_type_code => 'OVERDUE',
            status          => 'UNRETURNED',
        }
    );

    my $account        = Koha::Account->new( { patron_id => $overdue_item->{borrowernumber} } );
    my $forgiven_count = 0;
    while ( my $accountline = $accountlines->next ) {
        my $credit = $account->forgive_debit( $accountline, { interface => 'cron' } );
        if ($credit) {
            $forgiven_count++;
        }
    }

    if ( $forgiven_count && C4::Context->preference('FinesLog') ) {
        Koha::Logger->get->info(
            "Overdue forgiven: borrower $overdue_item->{borrowernumber}, item $overdue_item->{itemnumber} ($forgiven_count line(s))"
        );
    }
}

=head3 enact_charge

Charge the patron the item's replacement fee.

Resolves the fee-context branch via LKoha::Checkout/branch_for_fee_context so the LOST accountline's library_id honours
LostChargesControl / HomeOrHoldingBranch. Records the accountline with interface 'cron'.

=cut

sub enact_charge {
    my ( $self, $overdue_item ) = @_;

    if ( !$overdue_item->{replacementfee} || $overdue_item->{replacementfee} == 0 ) {
        Koha::Logger->get->warn("No replacement fee set for itemnumber $overdue_item->{itemnumber} — skipping charge");
        return;
    }

    my $item   = Koha::Items->find( $overdue_item->{itemnumber} );
    my $patron = Koha::Patrons->find( $overdue_item->{borrowernumber} );
    my $issue  = Koha::Checkouts->search(
        {
            issue_id => $overdue_item->{issue_id},
        }
    )->next;

    my $rule_branch = Koha::Checkout->branch_for_fee_context(
        fee_type => 'LOST',
        patron   => $patron,
        item     => $item,
        issue    => $issue,
    );

    my $description = sprintf(
        "%s %s %s",
        $item->biblio ? ( $item->biblio->title // q{} ) : q{},
        $item->barcode        // q{},
        $item->itemcallnumber // q{},
    );

    Koha::Account->new( { patron_id => $overdue_item->{borrowernumber} } )->add_lost_replacement_fee(
        {
            item              => $item,
            issue             => $issue,
            library_id        => $rule_branch,
            interface         => 'cron',
            description       => $description,
            replacement_price => $overdue_item->{replacementfee},
        }
    );
}

=head3 enact_mark_returned

Mark the patron's checkout of this item as returned, honouring the patron's
privacy setting.

Important: MarkIssueReturned archives the issue to old_issues (reassigning
related accountlines to old_issue_id), clears items.onloan, records
last_returned_by, and may remove an OVERDUES debarment per
AutoRemoveOverduesRestrictions. Patron privacy=2 anonymises the archived
checkout.

=cut

sub enact_mark_returned {
    my ( $self, $overdue_item ) = @_;
    my $patron = Koha::Patrons->find( $overdue_item->{borrowernumber} );
    if ( !$patron ) {
        Koha::Logger->get->warn("enact_mark_returned: borrower $overdue_item->{borrowernumber} not found — skipping");
        return;
    }
    MarkIssueReturned(
        $overdue_item->{borrowernumber},
        $overdue_item->{itemnumber},
        undef,
        $patron->privacy,
    );
}

=head3 _resolve_rule_context_branchcode

  my $branchcode = $self->_resolve_rule_context_branchcode($overdue_item);

Resolves the branchcode used to key the effective rule-set lookup for an
overdue item, honoring the C<CircControl> and C<HomeOrHoldingBranch> sysprefs
(cf. the informative blurb in smart-rules.tt). In cron context (no userenv)
C<PickupLibrary> falls through to the item-side path, matching
C<C4::Circulation::_GetCircControlBranch>.

TODO: find this a better home. This is general circ-rule context resolution,
not overdue-specific. Candidate target: a public method on
C<Koha::CirculationRules> (or wherever C<_GetCircControlBranch> ends up
promoted to), taking scalars rather than objects so batch callers like the
overdues processor don't load Item + Patron per row.

=cut

sub _resolve_rule_context_branchcode {
    my ( $self, $overdue_item ) = @_;

    my $circ_control = C4::Context->preference('CircControl');
    if ( $circ_control eq 'PatronLibrary' ) {
        return $overdue_item->{patronhomebranch};
    }

    return ( C4::Context->preference('HomeOrHoldingBranch') eq 'homebranch' )
        ? $overdue_item->{itemhomebranch}
        : $overdue_item->{itemholdingbranch};
}

1;
