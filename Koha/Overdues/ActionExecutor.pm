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
use C4::Context;
use C4::Letters;
use Koha::Account::Lines;
use Koha::Libraries;
use Koha::Number::Price;
use Koha::Notice::Messages;
use Koha::Notice::Templates;
use Koha::Patrons;
use Koha::DateUtils qw( dt_from_string );

# Columns rendered into <<items.content>>, one tab-separated line per item.
# Matches the default of overdue_notices.pl's --itemscontent flag, which the
# trigger script does not carry.
use constant ITEM_CONTENT_FIELDS => qw( date_due title barcode author itemnumber );

# Transports the notice queue is drained in, most reliable first, and the
# allowlist of what it will send at all: a bucket whose transport is absent here
# is never drained.
my %TRANSPORT_ORDER = ( print => 0, sms => 1, email => 2 );

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
        notices_queued_before_run => {},
        notices_enqueued_this_run => {},
        verbose                   => $params->{verbose}      // 0,
        dry_run                   => $params->{dry_run}      // 0,
        trigger_date              => $params->{trigger_date} // dt_from_string(),
        summary                   => {
            notices_queued     => 0,
            notices_suppressed => 0,
        },
    };

    # A backdated run's notices belong to the date being replayed. EnqueueLetter
    # stamps time_queued with the moment of insert and takes no parameter for it,
    # so L</_enqueue_letter_for_bucket> restamps them - see L</_stamp_trigger_date>.
    $self->{replaying} = $self->{trigger_date}->ymd ne dt_from_string()->ymd;

    return bless $self, $class;
}

=head3 summary

  my $summary = $action_executor->summary;

Counts of what the run did, for the end-of-run summary
C<process_circulation_triggers.pl> prints.

=cut

sub summary {
    my ($self) = @_;
    return $self->{summary};
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
    # non-notice action decides how a notice on a loan under an open return
    # claim is treated (see the notice block below).
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

        # While a return claim on the loan is open, a notice is only sent if its
        # trigger also carries a non-notice action. overdue_notices.pl sent no
        # notice at all for a lost item (items.itemlost = 0), which silenced
        # return claims since they set the item lost. The new trigger system
        # allows for actions to be taken on items marked as lost -> narrow
        # the gate to specifically target open return claims instead of just
        # any lost items.
        my $bare_reminder_on_claimed = $overdue_item->{open_return_claim} && !%action_batch;

        if ( !$bare_reminder_on_claimed ) {
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

=head3 process_notice_queue

Drain the notice queue, generating a prepared letter and inserting a pending
L<Koha::Notice::Message> row for each bucket
C<< $self->{notice_queue}{$borrowernumber}{$notice_code}{$mtt}{$delay} >>.
Every item routed to the same bucket in L</route_item_actions_to_queue>
renders into one letter via the template's repeat block.

When an C<sms> or C<email> entry can't be delivered (patron has no
C<smsalertnumber> / no C<notice_email_address>), a C<print> entry is
synthesised instead.

One letter is enqueued per C<(borrower, letter_code, effective transport,
delay)>. A patron holding items at two delays that resolve the same letter code
therefore receives one letter per delay, on each configured transport — what
C<overdue_notices.pl> sent, where each trigger level prepared its own letter and
C<$print_sent> collapsed duplicates only within a level.

A letter code's transports are drained in C<%TRANSPORT_ORDER> — C<print>, then
C<sms>, then C<email> — so an explicitly configured print claims its delay before
any sms or email bucket can degrade into it, and renders from its own template
rather than by fallback. That ordering only has to hold within one C<(borrower,
letter_code)>, which is what both dedup keys are scoped to, so transports are
walked inside the letter code rather than outside the whole queue.

L</_effective_transport> decides what each bucket is actually sent as, and
L</_notice_already_queued> decides whether it still needs sending.

=cut

sub process_notice_queue {
    my ($self) = @_;

    if ( $self->{verbose} ) {
        printf "NOTICES ENQUEUED: \n";
    }

    for my $borrowernumber ( sort { $a <=> $b } keys %{ $self->{notice_queue} } ) {
        my $patron = Koha::Patrons->find($borrowernumber);
        if ( !$patron ) {
            Koha::Logger->get->warn("process_notice_queue: borrower $borrowernumber not found — skipping");
            next;
        }

        my $by_notice_code = $self->{notice_queue}{$borrowernumber};
        for my $notice_code ( sort keys %$by_notice_code ) {
            my $by_mtt = $by_notice_code->{$notice_code};

            for my $mtt ( $self->_sendable_transports($by_mtt) ) {
                my ( $effective_mtt, $origin_mtt ) = $self->_effective_transport( $patron, $mtt );

                for my $delay ( sort { $a <=> $b } keys %{ $by_mtt->{$mtt} } ) {
                    my $entries = $by_mtt->{$mtt}{$delay};

                    if ( $self->_notice_already_queued( $borrowernumber, $notice_code, $effective_mtt, $delay ) ) {
                        $self->{summary}->{notices_suppressed}++;
                        next;
                    }

                    if ( $self->_enqueue_letter_for_bucket( $patron, $entries, $effective_mtt, $origin_mtt ) ) {
                        $self->_record_notice_enqueued( $borrowernumber, $notice_code, $effective_mtt, $delay );
                    }
                }
            }
        }
    }

    return;
}

=head3 _sendable_transports

  for my $mtt ( $self->_sendable_transports($by_mtt) ) { ... }

The transports queued under one letter code that this pipeline will send,
in the order they are drained — C<print>, then C<sms>, then C<email>.

C<%TRANSPORT_ORDER> is the allowlist as well as the order, so a transport queued
but absent from it is dropped here rather than needing a skip of its own.
C<overdue_notices.pl> named C<itiva> to skip it; anything non-sendable added
later is inert by default.

=cut

sub _sendable_transports {
    my ( $self, $by_mtt ) = @_;

    my @transports = sort { $TRANSPORT_ORDER{$a} <=> $TRANSPORT_ORDER{$b} }
        grep { exists $TRANSPORT_ORDER{$_} } keys %$by_mtt;
    return @transports;
}

=head3 _effective_transport

  my ( $effective_mtt, $origin_mtt ) = $self->_effective_transport( $patron, $mtt );

The transport a bucket configured for C<$mtt> is actually sent as. An C<sms>
bucket for a patron with no C<smsalertnumber>, or an C<email> bucket for a patron
with no C<notice_email_address>, degrades to C<print>; C<$origin_mtt> then names
the transport it was configured for, so the letter can still render from that
template where C<print> has none of its own.

=cut

sub _effective_transport {
    my ( $self, $patron, $mtt ) = @_;

    if ( $mtt eq 'print' ) {
        return ( 'print', undef );
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

A row already on the trigger date before this run — L</_notice_exists> asked once
per C<(borrower, letter_code, transport)> and cached, so that a letter enqueued by
this run never answers for the next delay. That is what makes a re-run idempotent, including one
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
            $self->_notice_exists( $borrowernumber, $notice_code, $mtt );
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
    $self->{summary}->{notices_queued}++;

    return;
}

=head3 _notice_exists

Returns true if a message_queue row for this (borrowernumber, letter_code,
message_transport_type) was queued on the trigger date and is either still
waiting for C<SendQueuedMessages> or has already gone out.

The window is that one day, not everything since it. An open-ended C<< >= >>
would leave C<--date> unable to do the job it exists for: a missed day is
replayed precisely because days have passed, and any notice of the same code
queued in between would suppress the replay entirely.

C<failed> and C<deleted> rows deliberately do not count: a notice that never
reached the patron should not stop a later run from queueing it again.

L</_notice_already_queued> calls this once per transport key and caches the
answer, so it reports the state the key was in before this run enqueued anything.
It carries no notion of delay — message_queue has no column for one — which is
why the per-delay dedup is held in memory alongside it rather than read back from
the database. It also matches rows this run did not create, so a notice of the
same code sent by staff earlier the same day suppresses the overdue one.

=cut

sub _notice_exists {
    my ( $self, $borrowernumber, $notice_code, $mtt ) = @_;

    my $day_start = $self->{trigger_date}->clone->truncate( to => 'day' );
    my $day_end   = $day_start->clone->add( days => 1 );

    return Koha::Notice::Messages->search(
        {
            borrowernumber         => $borrowernumber,
            letter_code            => $notice_code,
            message_transport_type => $mtt,
            status                 => [ 'pending', 'sent' ],
            time_queued            => {
                '>=' => $day_start->strftime('%Y-%m-%d %H:%M:%S'),
                '<'  => $day_end->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    )->count > 0;
}

=head3 _stamp_trigger_date

  $self->_stamp_trigger_date($message_id);

Sets C<time_queued> on a just-enqueued message to the trigger date, on a
backdated run only.

The write-side counterpart to L</_notice_exists>. C<EnqueueLetter> records when
the row was inserted, which on a replay is the day the operator noticed rather
than the day the notice is for, while L</_notice_exists> asks what was queued for
the trigger date. Without this the two never meet: a second replay of the same
date would find nothing from the first and queue the patron a duplicate.

Sending is unaffected: C<SendQueuedMessages> selects on C<status> alone and never
reads C<time_queued>. Three things do read it. C<cleanup_database.pl> purges
C<message_queue> on it, so a replayed notice ages out that many days early;
L<Koha::Notice::Messages/get_failed_notices> windows on it, so a replay older
than that window would not be reported if its notice then failed to send; and the
staff notices tab and the OPAC message feed display it, showing the date the
notice is for rather than the day it was generated.

=cut

sub _stamp_trigger_date {
    my ( $self, $message_id ) = @_;

    if ( !$self->{replaying} || !$message_id ) {
        return;
    }

    my $message = Koha::Notice::Messages->find($message_id);
    if ($message) {
        $message->time_queued( $self->{trigger_date} )->store;
    }

    return;
}

=head3 _enqueue_letter_for_bucket

Renders the bucket's items into a single letter and hands it to
L<C4::Letters/EnqueueLetter>, which stores it as a pending
L<Koha::Notice::Message> row addressed from the rule-context library.

C<$effective_mtt> is the transport the message is queued under. C<$origin_mtt> is
passed only when this is a print fallback for an undeliverable sms/email bucket,
and names the transport that bucket was configured for; L</_template_transport>
uses it where the queued transport has no template of its own.

Returns true when a row was enqueued. A bucket that resolves no items or no
letter returns false, leaving the delay unclaimed so another bucket degrading to
the same transport can still try — as C<overdue_notices.pl> did, where a missing
template moved on to the next transport without setting C<$print_sent>.

=cut

sub _enqueue_letter_for_bucket {
    my ( $self, $patron, $entries, $effective_mtt, $origin_mtt ) = @_;

    my $head           = $entries->[0];
    my $borrowernumber = $patron->borrowernumber;
    my $notice_code    = $head->{action}->{notice_code};
    my $branchcode     = Koha::CirculationRules->resolve_rule_context_branchcode(
        {
            patron_branchcode  => $head->{item}->{patronhomebranch},
            item_homebranch    => $head->{item}->{itemhomebranch},
            item_holdingbranch => $head->{item}->{itemholdingbranch},
        }
    );
    my $library = Koha::Libraries->find($branchcode);

    my $payload = $self->_letter_payload( $patron, $entries );
    if ( !@{ $payload->{item_rows} } ) {
        return;
    }

    # Taken before truncation: count is what the letter is about, and the footer
    # below says the printed list was cut.
    my $item_count = scalar @{ $payload->{item_rows} };

    my ( $item_rows, $truncated ) = $self->_truncate_for_print( $payload->{item_rows}, $effective_mtt );
    my $template_mtt = $self->_template_transport( $patron, $notice_code, $branchcode, $effective_mtt, $origin_mtt );

    # count is the whole bucket, not @$item_rows, which a print bucket may have
    # had truncated. loops carries the itemnumbers so that templates written as
    # [% FOREACH overdue IN overdues %] resolve alongside the repeat block.
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
            'items.content' => $payload->{titles},
        },
        repeat                 => { item     => $item_rows },
        loops                  => { overdues => [ map { $_->{items}->{itemnumber} } @$item_rows ] },
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

    my $message_id = C4::Letters::EnqueueLetter(
        {
            letter                 => $letter,
            borrowernumber         => $borrowernumber,
            message_transport_type => $effective_mtt,
            from_address           => $library->from_email_address,
            to_address             => $patron->notice_email_address,
            reply_address          => $library->inbound_email_address,
        }
    );

    $self->_stamp_trigger_date($message_id);

    if ( $self->{verbose} ) {
        printf "    letter_code=%s mtt=%s borrower=%s days_overdue=%s items=%s\n",
            $notice_code, $effective_mtt, $borrowernumber, $head->{delay}, scalar @$item_rows;
    }

    return 1;
}

=head3 _letter_payload

  my $payload = $self->_letter_payload( $patron, $entries );

The bucket's items in the two forms a letter needs them: C<item_rows> for the
template's C<repeat> block, and C<titles> for the C<< <<items.content>> >>
substitution, which C<C4::Letters::get_item_content> renders one tab-separated
line per item.

Items that no longer resolve are warned about and dropped, so the caller must
treat an empty C<item_rows> as nothing to send.

=cut

sub _letter_payload {
    my ( $self, $patron, $entries ) = @_;

    my @item_rows;
    my $titles = q{};

    for my $entry (@$entries) {
        my $item_fields = $self->_letter_item_fields( $patron->borrowernumber, $entry );
        if ( !$item_fields ) {
            next;
        }

        $titles .= C4::Letters::get_item_content(
            {
                item                => $item_fields,
                item_content_fields => [ ITEM_CONTENT_FIELDS() ],
                dateonly            => 1,
            }
        );

        push @item_rows,
            {
            biblio      => $item_fields->{biblionumber},
            biblioitems => $item_fields->{biblionumber},
            items       => $item_fields,
            issues      => $item_fields->{itemnumber},
            };
    }

    return { item_rows => \@item_rows, titles => $titles };
}

=head3 _letter_item_fields

  my $item_fields = $self->_letter_item_fields( $borrowernumber, $entry );

One queued item as a template sees it: the item's own columns with the biblio's
merged underneath, so an item column wins where both tables carry the name.

Two fields are not columns. C<date_due> comes from the queue entry rather than
the item, and C<fine> is the patron's outstanding OVERDUE total for this item,
formatted through L<Koha::Number::Price> so it reads as C<| $Price> renders it
elsewhere.

Warns and returns nothing when the item no longer resolves.

=cut

sub _letter_item_fields {
    my ( $self, $borrowernumber, $entry ) = @_;

    my $item = Koha::Items->find( $entry->{item}->{itemnumber} );
    if ( !$item ) {
        Koha::Logger->get->warn("process_notice_queue: itemnumber $entry->{item}->{itemnumber} not found — skipping");
        return;
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

    return $item_fields;
}

=head3 _truncate_for_print

  my ( $item_rows, $truncated ) = $self->_truncate_for_print( $item_rows, $effective_mtt );

Caps a print bucket's rows at C<PrintNoticesMaxLines>, returning the rows to
render and whether anything was dropped. Any other transport passes through
untouched.

=cut

sub _truncate_for_print {
    my ( $self, $item_rows, $effective_mtt ) = @_;

    if ( $effective_mtt ne 'print' ) {
        return ( $item_rows, 0 );
    }

    my $max_lines = C4::Context->preference('PrintNoticesMaxLines');
    if ( !$max_lines || @$item_rows <= $max_lines ) {
        return ( $item_rows, 0 );
    }

    return ( [ @{$item_rows}[ 0 .. $max_lines - 1 ] ], 1 );
}

=head3 _template_transport

  my $template_mtt = $self->_template_transport( $patron, $notice_code, $branchcode, $effective_mtt, $origin_mtt );

The transport whose template the letter is rendered from, which is the transport
it is queued under except where a degraded bucket has nowhere else to go: a
bucket configured for sms or email and queued as print still needs content, so
where C<print> has no template of its own it renders from the originating
transport's.

Only consulted for a degraded bucket. A bucket sent as configured always renders
from its own template.

=cut

sub _template_transport {
    my ( $self, $patron, $notice_code, $branchcode, $effective_mtt, $origin_mtt ) = @_;

    if ( !$origin_mtt ) {
        return $effective_mtt;
    }

    my $template = Koha::Notice::Templates->find_effective_template(
        {
            module                 => 'circulation',
            code                   => $notice_code,
            message_transport_type => $effective_mtt,
            branchcode             => $branchcode,
            lang                   => $patron->lang,
        }
    );

    return $template ? $effective_mtt : $origin_mtt;
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

1;
