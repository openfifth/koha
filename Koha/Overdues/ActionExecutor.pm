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
    my $categorycode = $overdue_item->{categorycode};
    my $itemtype     = $overdue_item->{itemtype};
    my $days_overdue = $overdue_item->{days_overdue};

    my $actions_hashes = $effective_rule_sets->{"$branchcode|$categorycode|$itemtype|$days_overdue"}->{actions};

    if ( !$actions_hashes || !@$actions_hashes ) {
        return;
    }

    my %actions = map { $_->{type} => $_ } @$actions_hashes;

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

=head3 add_to_action_batch_queue

Adds an action item to the standard queue.

=cut

sub add_to_action_batch_queue {
    my ( $self, $action_item_batch ) = @_;
    push @{ $self->{action_batch_queue} }, $action_item_batch;
}

1;
