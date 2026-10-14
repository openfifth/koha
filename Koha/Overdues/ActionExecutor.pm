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
use Koha::DateUtils qw( dt_from_string );

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

Takes an optional C<trigger_date> L<DateTime>, defaulting to today.

=cut

sub new {
    my ( $class, $params ) = @_;
    my $self = {
        action_batch_queue => [],
        notice_queue       => {},
        verbose            => $params->{verbose}      // 0,
        dry_run            => $params->{dry_run}      // 0,
        trigger_date       => $params->{trigger_date} // dt_from_string(),
        summary            => {},
    };

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
