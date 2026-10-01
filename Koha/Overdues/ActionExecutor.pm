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
use Koha::CirculationRules;
use Koha::Logger;
use Koha::Items;
use Koha::Patron::Debarments qw( AddUniqueDebarment );
use C4::Context;
use C4::Letters;
use Koha::Account::Lines;
use Koha::Libraries;
use Koha::Number::Price;
use Koha::Notice::Messages;
use Koha::Notice::Templates;
use Koha::Patrons;
use Koha::Checkouts;
use Koha::Checkout;
use Koha::DateUtils qw( dt_from_string output_pref );

# Columns rendered into <<items.content>>, one tab-separated line per item.
# Matches the default of overdue_notices.pl's --itemscontent flag, which the
# trigger script does not carry.
use constant ITEM_CONTENT_FIELDS => qw( date_due title barcode author itemnumber );

=head1 NAME

Koha::Overdues::ActionExecutor - Koha Overdue ActionExecutor object set class.

=head2 Class Methods

=cut

=head3 new

Instantiate the class.

Takes an optional C<verbose> flag. When set, each action and each enqueued
letter reports itself at the point it happens.

Takes an optional C<dry_run> flag. C<process_circulation_triggers.pl> isolates a
dry run in a transaction it rolls back, but a couple of the effects reached from
L<Koha::Item/store> - the search index update and the holds queue job - publish
to a message broker and so escape that rollback. Setting this suppresses them,
which is what makes a dry run genuinely free of side effects.

Takes an optional C<trigger_date> L<DateTime>, defaulting to today. It bounds
the once-per-day guard in L</_notice_exists>, so that a run replaying a missed
date is deduped against that date rather than against today.

=cut

sub new {
    my ( $class, $params ) = @_;
    my $self = {
        action_batch_queue        => [],
        notice_queue              => {},
        patrons_marked_returned   => {},
        notices_queued_before_run => {},
        notices_enqueued_this_run => {},
        verbose                   => $params->{verbose}      // 0,
        dry_run                   => $params->{dry_run}      // 0,
        trigger_date              => $params->{trigger_date} // dt_from_string(),
    };
    return bless $self, $class;
}

=head3 route_item_actions_to_queue

Separate action sets into notice and standard action sets, and calls the relevant enqueing subroutine.

=cut

sub route_item_actions_to_queue {
    my ( $self, $effective_rule_sets, $overdue_item ) = @_;

    my $branchcode = Koha::CirculationRules->resolve_rule_context_branchcode(
        {
            patron_branchcode  => $overdue_item->{patronhomebranch},
            item_homebranch    => $overdue_item->{itemhomebranch},
            item_holdingbranch => $overdue_item->{itemholdingbranch},
        }
    );
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

    return;
}

=head3 _item_store_params

Parameters for any L<Koha::Item/store> reached from an enactment.

Under C<dry_run> this suppresses the search index update and the holds queue
job. Both publish to a message broker from inside C<store>, so unlike every
other effect here they are not undone when the script rolls its transaction
back. Outside a dry run this is empty and the stores behave normally.

=cut

sub _item_store_params {
    my ($self) = @_;

    if ( !$self->{dry_run} ) {
        return {};
    }

    return { skip_record_index => 1, skip_holds_queue => 1 };
}

=head3 _report_action

Report one enacted action under C<verbose>. Called immediately after the
enactment it describes, so the sequence printed is the sequence that ran.

=cut

sub _report_action {
    my ( $self, $batch, $type ) = @_;

    if ( !$self->{verbose} ) {
        return;
    }

    printf "    type=%s value=%s borrower=%s item=%s days_overdue=%s\n",
        $type,
        $batch->{actions}->{$type},
        $batch->{item}->{borrowernumber},
        $batch->{item}->{itemnumber},
        $batch->{delay};
}

=head3 process_action_queue

Process the standard queue.

Under C<verbose>, each action reports itself as it is enacted, so the output is
a record of what the run did rather than a prediction of it.

=cut

sub process_action_queue {
    my ($self) = @_;

    if ( $self->{verbose} ) {
        printf "ACTION ENACTED: \n";
    }

    foreach my $batch ( @{ $self->{action_batch_queue} } ) {
        my $overdue_item = $batch->{item};
        my $actions      = $batch->{actions};

        if ( $actions->{restrict} ) {
            $self->enact_restrict($overdue_item);
            $self->_report_action( $batch, 'restrict' );
        }

        if ( $actions->{forgive_fine} ) {
            $self->enact_forgive_fine($overdue_item);
            $self->_report_action( $batch, 'forgive_fine' );
        }

        if ( $actions->{lost} ) {
            $self->enact_lost( $overdue_item, $actions->{lost} );
            $self->_report_action( $batch, 'lost' );
        }

        if ( $actions->{charge} ) {
            $self->enact_charge($overdue_item);
            $self->_report_action( $batch, 'charge' );
        }

        if ( $actions->{mark_returned} ) {
            $self->enact_mark_returned($overdue_item);
            $self->_report_action( $batch, 'mark_returned' );
        }
    }

    # Lifting an OVERDUES restriction reconciles against the patron's remaining
    # overdues, so running it per archived checkout would reach the same answer
    # by re-evaluating it once per item. Doing it once per patron here avoids
    # repeating has_restricting_overdues.
    if ( C4::Context->preference('AutoRemoveOverduesRestrictions') eq 'no' ) {
        return;
    }

    foreach my $borrowernumber ( keys %{ $self->{patrons_marked_returned} } ) {
        my $patron = Koha::Patrons->find($borrowernumber);
        if ($patron) {
            $patron->lift_overdue_restrictions;
        }
    }

    return;
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

Letters render against B<pre-action> state — this runs before
L</process_action_queue>. Templates therefore see the checkout still open, the
overdue fine still outstanding, and the item not yet lost. That is what a letter
on an action-carrying trigger wants to state: the fine being forgiven, the
replacement price about to be charged. Nothing that only exists after enactment
is available.

One letter is enqueued per C<(borrower, letter_code, effective transport,
delay)>. A patron holding items at two delays that resolve the same letter code
therefore receives one letter per delay, on each configured transport — what
C<overdue_notices.pl> sent, where each trigger level prepared its own letter and
C<$print_sent> collapsed duplicates only within a level.

L</_effective_transport> decides what a bucket is actually sent as, and
L</_notice_already_queued> decides whether it still needs sending. Transports are
processed in reliability order — C<print>, then C<sms>, then C<email> — so an
explicitly configured print claims its delay first and renders from its own
template, leaving degraded buckets to collapse into it.

=cut

sub process_notice_queue {
    my ($self) = @_;

    if ( $self->{verbose} ) {
        printf "NOTICES ENQUEUED: \n";
    }

    for my $mtt (qw( print sms email )) {
        for my $borrowernumber ( sort keys %{ $self->{notice_queue} } ) {
            my $by_notice_code = $self->{notice_queue}{$borrowernumber};
            for my $notice_code ( sort keys %$by_notice_code ) {
                my $by_mtt = $by_notice_code->{$notice_code};
                if ( !$by_mtt->{$mtt} ) {
                    next;
                }

                for my $delay ( sort { $a <=> $b } keys %{ $by_mtt->{$mtt} } ) {
                    my $entries = $by_mtt->{$mtt}{$delay};
                    if ( !$entries || !@$entries ) {
                        next;
                    }

                    my ( $effective_mtt, $origin_mtt ) = $self->_effective_transport( $borrowernumber, $mtt );
                    if ( !$effective_mtt ) {
                        next;
                    }

                    if ( $self->_notice_already_queued( $borrowernumber, $notice_code, $effective_mtt, $delay ) ) {
                        next;
                    }

                    if ( $self->_enqueue_letter_for_bucket( $entries, $effective_mtt, $origin_mtt ) ) {
                        $self->_record_notice_enqueued( $borrowernumber, $notice_code, $effective_mtt, $delay );
                    }
                }
            }
        }
    }

    return;
}

=head3 _effective_transport

  my ( $effective_mtt, $origin_mtt ) = $self->_effective_transport( $borrowernumber, $mtt );

The transport a bucket configured for C<$mtt> is actually sent as. An C<sms>
bucket for a patron with no C<smsalertnumber>, or an C<email> bucket for a patron
with no C<notice_email_address>, degrades to C<print>; C<$origin_mtt> then names
the transport it was configured for, so the letter can still render from that
template where C<print> has none of its own.

Returns the empty list when the borrower cannot be found.

=cut

sub _effective_transport {
    my ( $self, $borrowernumber, $mtt ) = @_;

    if ( $mtt eq 'print' ) {
        return ( 'print', undef );
    }

    my $patron = Koha::Patrons->find($borrowernumber);
    if ( !$patron ) {
        Koha::Logger->get->warn("process_notice_queue: borrower $borrowernumber not found — skipping");
        return;
    }

    my $viable = $mtt eq 'sms' ? $patron->smsalertnumber : $patron->notice_email_address;
    if ($viable) {
        return ( $mtt, undef );
    }

    return ( 'print', $mtt );
}

=head3 _notice_already_queued

  next if $self->_notice_already_queued( $borrowernumber, $notice_code, $mtt, $delay );

Whether this bucket's letter has already been accounted for, by either of two
guards.

A row predating this run — L</_notice_exists> asked once per C<(borrower,
letter_code, transport)> and cached, so that a letter enqueued by this run never
answers for the next delay. That is what makes a re-run idempotent, including one
landing after C<SendQueuedMessages> has flipped rows to C<sent>, without a
patron's delay 7 letter suppressing their delay 14 one.

A letter this run already enqueued for the same C<(borrower, letter_code,
transport, delay)>. The transport is the effective one, so an sms bucket and an
email bucket that both degrade to print at the same delay produce one sheet —
C<overdue_notices.pl>'s C<$print_sent>, which was likewise scoped within a level.

=cut

sub _notice_already_queued {
    my ( $self, $borrowernumber, $notice_code, $mtt, $delay ) = @_;

    my $transport_key = join( "|", $borrowernumber, $notice_code, $mtt );

    if ( !exists $self->{notices_queued_before_run}{$transport_key} ) {
        $self->{notices_queued_before_run}{$transport_key} =
            $self->_notice_exists( $borrowernumber, $notice_code, $mtt, [ 'pending', 'sent' ] );
    }

    if ( $self->{notices_queued_before_run}{$transport_key} ) {
        return 1;
    }

    return $self->{notices_enqueued_this_run}{"$transport_key|$delay"} ? 1 : 0;
}

=head3 _record_notice_enqueued

Record that this run has enqueued a letter for C<(borrower, letter_code,
effective transport, delay)>. Called only once a letter was actually stored, so a
bucket that resolved no template leaves the delay open for another bucket
degrading to the same transport.

=cut

sub _record_notice_enqueued {
    my ( $self, $borrowernumber, $notice_code, $mtt, $delay ) = @_;

    $self->{notices_enqueued_this_run}{ join( "|", $borrowernumber, $notice_code, $mtt, $delay ) } = 1;

    return;
}

=head3 _notice_exists

Returns true if a message_queue row for this (borrowernumber, letter_code,
message_transport_type) was queued on or after the trigger date and still holds
one of the given statuses.

L</process_notice_queue> calls this once per transport key and caches the answer,
so it reports the state the key was in before this run enqueued anything. It
carries no notion of delay — message_queue has no column for one — which is why
the per-delay dedup is held in memory alongside it rather than read back from the
database. It also matches rows this run did not create, so a notice of the same
code sent by staff earlier the same day suppresses the overdue one.

=cut

sub _notice_exists {
    my ( $self, $borrowernumber, $code, $type, $status ) = @_;
    my $from = $self->{trigger_date}->clone->truncate( to => 'day' )->strftime('%Y-%m-%d %H:%M:%S');

    return Koha::Notice::Messages->search(
        {
            borrowernumber         => $borrowernumber,
            letter_code            => $code,
            message_transport_type => $type,
            status                 => $status,
            time_queued            => { '>=' => $from },
        }
    )->count > 0;
}

=head3 _enqueue_letter_for_bucket

Renders the bucket's items into a single prepared letter and hands it to
L<C4::Letters/EnqueueLetter>, which stores it as a pending
L<Koha::Notice::Message> row addressed from the rule-context library.
C<$effective_mtt> is the transport the message is
queued under. C<$origin_mtt> is passed only when this is a print fallback for an
undeliverable sms/email bucket, and names the transport that bucket was
configured for; it supplies the template when the queued transport has none of
its own.

Returns true when a row was enqueued. A bucket that resolves no patron, no items
or no letter returns false, leaving the delay unclaimed so another bucket
degrading to the same transport can still try — as C<overdue_notices.pl> did,
where a missing template moved on to the next transport without setting
C<$print_sent>.

=cut

sub _enqueue_letter_for_bucket {
    my ( $self, $entries, $effective_mtt, $origin_mtt ) = @_;

    my $head           = $entries->[0];
    my $borrowernumber = $head->{item}->{borrowernumber};
    my $notice_code    = $head->{action}->{notice_code};
    my $branchcode     = Koha::CirculationRules->resolve_rule_context_branchcode(
        {
            patron_branchcode  => $head->{item}->{patronhomebranch},
            item_homebranch    => $head->{item}->{itemhomebranch},
            item_holdingbranch => $head->{item}->{itemholdingbranch},
        }
    );

    my $patron = Koha::Patrons->find($borrowernumber);
    if ( !$patron ) {
        Koha::Logger->get->warn("process_notice_queue: borrower $borrowernumber not found — skipping");
        return;
    }

    my $library = Koha::Libraries->find($branchcode);

    my @item_rows;
    my $titles = q{};
    for my $entry (@$entries) {
        my $item = Koha::Items->find( $entry->{item}->{itemnumber} );
        if ( !$item ) {
            Koha::Logger->get->warn(
                "process_notice_queue: itemnumber $entry->{item}->{itemnumber} not found — skipping");
            next;
        }

        my $biblio      = $item->biblio;
        my $item_fields = { %{ $item->unblessed } };
        if ($biblio) {
            $item_fields = { %{ $biblio->unblessed }, %$item_fields };
        }
        $item_fields->{date_due} = $entry->{item}->{date_due};

        my $fine = Koha::Account::Lines->search(
            {
                borrowernumber    => $borrowernumber,
                itemnumber        => $item->itemnumber,
                debit_type_code   => 'OVERDUE',
                amountoutstanding => { '>' => 0 },
            }
        )->total_outstanding;
        $item_fields->{fine} = Koha::Number::Price->new( $fine // 0 )->format;

        $titles .= C4::Letters::get_item_content(
            {
                item                => $item_fields,
                item_content_fields => [ ITEM_CONTENT_FIELDS() ],
                dateonly            => 1,
            }
        );

        push @item_rows,
            {
            biblio      => $item->biblionumber,
            biblioitems => $item->biblionumber,
            items       => $item_fields,
            issues      => $item->itemnumber,
            };
    }

    if ( !@item_rows ) {
        return;
    }

    my $item_count = scalar @item_rows;
    my $max_lines  = C4::Context->preference('PrintNoticesMaxLines');
    my $truncated  = 0;
    if ( $effective_mtt eq 'print' && $max_lines && $item_count > $max_lines ) {
        splice @item_rows, $max_lines;
        $truncated = 1;
    }

    # A bucket degraded to print still needs content: where the queued transport has
    # no template of its own, render from the originating transport's.
    my $template_mtt = $effective_mtt;
    if ($origin_mtt) {
        my $template = Koha::Notice::Templates->find_effective_template(
            {
                module                 => 'circulation',
                code                   => $notice_code,
                message_transport_type => $effective_mtt,
                branchcode             => $branchcode,
                lang                   => $patron->lang,
            }
        );
        if ( !$template ) {
            $template_mtt = $origin_mtt;
        }
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
        substitute => {
            count           => $item_count,
            bib             => $library->branchname,
            'items.content' => $titles,
        },
        repeat => { item     => \@item_rows },
        loops  => { overdues => [ map { $_->{items}->{itemnumber} } @item_rows ] }
        ,    # for compatibility with templates expecting data that can be parsed like [% FOREACH overdue IN overdues %]
        message_transport_type => $template_mtt,
    );

    if ( !$letter ) {
        Koha::Logger->get->warn(
            "process_notice_queue: no letter for borrower=$borrowernumber code=$notice_code mtt=$template_mtt — skipping"
        );
        return;
    }

    if ($truncated) {
        $letter->{content} .=
            "List too long for form; please check your account online for a complete list of your overdue items.";
    }

    C4::Letters::EnqueueLetter(
        {
            letter                 => $letter,
            borrowernumber         => $borrowernumber,
            message_transport_type => $effective_mtt,
            from_address           => $library->from_email_address,
            to_address             => $patron->notice_email_address,
            reply_address          => $library->inbound_email_address,
        }
    );

    if ( $self->{verbose} ) {
        printf "    letter_code=%s mtt=%s borrower=%s days_overdue=%s items=%s\n",
            $notice_code, $effective_mtt, $borrowernumber, $head->{delay}, scalar @item_rows;
    }

    return 1;
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
    $item->mark_lost( $lost_value, $self->_item_store_params );
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

    return;
}

=head3 enact_charge

Charge the patron the item's replacement fee.

Resolves the fee-context branch via LKoha::Checkout/branch_for_fee_context so the LOST accountline's library_id honours
LostChargesControl / HomeOrHoldingBranch. Records the accountline with interface 'cron'.

=cut

sub enact_charge {
    my ( $self, $overdue_item ) = @_;

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
            issue_id          => $overdue_item->{issue_id},
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

Important: mark_returned archives the issue to old_issues (reassigning
related accountlines to old_issue_id), clears items.onloan, and records
last_returned_by. Patron privacy=2 anonymises the archived checkout.

Any OVERDUES debarment is lifted once per patron at the end of
L</process_action_queue>, not here.

=cut

sub enact_mark_returned {
    my ( $self, $overdue_item ) = @_;
    my $patron = Koha::Patrons->find( $overdue_item->{borrowernumber} );
    if ( !$patron ) {
        Koha::Logger->get->warn("enact_mark_returned: borrower $overdue_item->{borrowernumber} not found — skipping");
        return;
    }
    my $checkout = Koha::Checkouts->find( $overdue_item->{issue_id} );
    if ( !$checkout ) {
        Koha::Logger->get->warn("enact_mark_returned: issue $overdue_item->{issue_id} not found — skipping");
        return;
    }
    $checkout->mark_returned(
        {
            borrowernumber => $overdue_item->{borrowernumber},
            privacy        => $patron->privacy,
            %{ $self->_item_store_params },
        }
    );
    $self->{patrons_marked_returned}->{ $overdue_item->{borrowernumber} } = 1;
}

1;
