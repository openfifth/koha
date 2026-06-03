package Koha::Overdues::TriggerProcessor;

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
use C4::Context;
use Koha::Overdues::RuleResolver;
use Koha::Overdues::ActionExecutor;
use Koha::Overdues::Repository;
use Koha::Calendar;
use Koha::Checkouts;
use Koha::DateUtils qw( dt_from_string );

# Above this many (branch, delay) pairs, the calendar-adjusted path issues one
# SQL per branch instead of a single OR-clause query — keeps the OR list and
# the bind-parameter count within sensible bounds for large fleets.
use constant CALENDAR_PAIRS_INLINE_LIMIT => 150;

=head1 NAME

Koha::Overdues::TriggerProcessor - Koha Overdue TriggerProcessor object set class

=head2 API

=head3 new

$triggerProcessor = Koha::Overdues::TriggerProcessor->new();

=cut

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

=head3 ProcessOverdues

  $triggerProcessor->ProcessOverdues;

Entry point used by C<process_circulation_triggers.pl>. Dispatches to the
calendar-adjusted path when C<OverdueTriggersCalendar> is enabled, otherwise
to the simple DATEDIFF-based path.

=cut

sub ProcessOverdues {
    my ($self) = @_;

    return C4::Context->preference('OverdueTriggersCalendar')
        ? $self->_process_calendar_adjusted
        : $self->_process_simple_calculation;
}

=head3 _process_simple_calculation

Simple Calculation (No Closed Days). Matches items whose C<date_due> falls
exactly on one of the trigger-delay dates measured backward from today using
calendar-day arithmetic.

=cut

sub _process_simple_calculation {
    my ($self) = @_;
    my @known_delay_values = Koha::CirculationRules->get_known_overdue_delay_values();

    if ( !@known_delay_values ) {

        # this should not happen as it would imply the process_circulation_triggers.pl script is running despite no circulation rules being set
        return;
    }

    my $allOverduesForKnownDelays =
        Koha::Overdues::Repository->GetOverdueSummariesForKnownTriggerDelays( \@known_delay_values );

    if ( !$allOverduesForKnownDelays ) {
        return;
    }

    return $self->_dispatch_overdues( $allOverduesForKnownDelays, \@known_delay_values );
}

=head3 _process_calendar_adjusted

Calendar-adjusted path. For each unique branch holding overdue items, builds a
L<Koha::Calendar> and computes the exact calendar date corresponding to each
trigger delay measured in B<open days> using
L<Koha::Calendar/days_backward>. Then fetches the matching checkouts via one
SQL with OR-clauses (or one SQL per branch above
L</CALENDAR_PAIRS_INLINE_LIMIT>) and feeds them through the same rule
resolution + action enactment as the simple path.

Deliberately does B<not> use C<prev_open_days> — that routes through
C<get_push_amt> which jumps 7 days at a time in DayWeek mode (Bug 42608
class). C<days_backward> walks one calendar day at a time, decrementing only
on open days.

=cut

sub _process_calendar_adjusted {
    my ($self) = @_;

    my @known_delay_values = Koha::CirculationRules->get_known_overdue_delay_values();    # sorted in ascending order
    if ( !@known_delay_values ) {
        return;
    }

    my $min_delay = $known_delay_values[0];
    my @branches  = Koha::Overdues::Repository->GetDistinctOverdueBranches($min_delay);
    if ( !@branches ) {
        return;
    }

    my $today     = dt_from_string;
    my $days_mode = C4::Context->preference('useDaysMode');

    my %target_dates_by_branch;
    for my $branch (@branches) {
        my $calendar = Koha::Calendar->new( branchcode => $branch, days_mode => $days_mode );
        my @dates;
        for my $delay (@known_delay_values) {
            push @dates,
                $calendar->days_backward( $today->clone, $delay )->strftime('%Y-%m-%d');
        }
        $target_dates_by_branch{$branch} = \@dates;
    }

    my $pair_count = @branches * @known_delay_values;

    my $overdues_resultset;
    if ( $pair_count > CALENDAR_PAIRS_INLINE_LIMIT ) {
        $overdues_resultset = $self->_fetch_per_branch( \%target_dates_by_branch );
    } else {
        my @pairs = map { { branchcode => $_, dates => $target_dates_by_branch{$_} } } @branches;
        $overdues_resultset = Koha::Overdues::Repository->GetOverdueSummariesByBranchDatePairs( \@pairs );
    }

    if ( !$overdues_resultset ) {
        return;
    }

    return $self->_dispatch_overdues( $overdues_resultset, \@known_delay_values );
}

# Alg 3 fallback: issue one query per branch and return a merged in-memory
# resultset-like iterator. The downstream code only needs ->next, so we wrap
# the per-branch resultsets in a minimal chained iterator.
sub _fetch_per_branch {
    my ( $self, $target_dates_by_branch ) = @_;

    my @resultsets;
    for my $branch ( keys %$target_dates_by_branch ) {
        my $rs =
            Koha::Overdues::Repository->GetOverdueSummariesByBranchDates( $branch, $target_dates_by_branch->{$branch} );
        push @resultsets, $rs if $rs;
    }
    return unless @resultsets;

    return Koha::Overdues::_ChainedResultset->new( \@resultsets );
}

# Shared post-fetch flow: walk the resultset, collect dimensions, resolve
# rules, route through ActionExecutor. Identical for both simple and
# calendar-adjusted paths.
sub _dispatch_overdues {
    my ( $self, $overdues_resultset, $known_delay_values ) = @_;

    my %seen_branches;
    my %seen_categories;
    my %seen_itemtypes;
    my @overdue_items;

    while ( my $row = $overdues_resultset->next ) {
        $seen_branches{ $row->get_column('branchcode') }     = 1;
        $seen_categories{ $row->get_column('categorycode') } = 1;
        $seen_itemtypes{ $row->get_column('itemtype') }      = 1;

        my $item_hashref = {
            issue_id           => $row->issue_id,
            borrowernumber     => $row->borrowernumber,
            itemnumber         => $row->itemnumber,
            branchcode         => $row->branchcode,
            date_due           => $row->date_due,
            categorycode       => $row->get_column('categorycode'),
            itemtype           => $row->get_column('itemtype'),
            days_overdue       => $row->get_column('days_overdue'),
            biblionumber       => $row->get_column('biblionumber'),
            notice_preferences => $row->get_column('notice_preferences'),
            replacementfee     => $row->get_column('replacementfee'),
            itemhomebranch     => $row->get_column('itemhomebranch'),
            itemholdingbranch  => $row->get_column('itemholdingbranch'),
            patronhomebranch   => $row->get_column('patronhomebranch'),
        };

        push @overdue_items, $item_hashref;
    }

    my @branch_list   = keys %seen_branches;
    my @category_list = keys %seen_categories;
    my @itemtype_list = keys %seen_itemtypes;

    #  fetch from the database
    my $rule_resolver = Koha::Overdues::RuleResolver->new;
    $rule_resolver->set_raw_overdue_rule_sets(
        \@branch_list, \@category_list,
        \@itemtype_list
    );

    # generate exhaustive effective set for relevant contexts
    $rule_resolver->set_effective_overdue_rule_sets(
        \@branch_list,   \@category_list,
        \@itemtype_list, $known_delay_values
    );

    my $action_executor = Koha::Overdues::ActionExecutor->new();

    # separate notice route actions from standard route actions
    foreach my $overdue_item (@overdue_items) {
        $action_executor->route_item_actions_to_queue( $rule_resolver->{effective_overdue_rule_sets}, $overdue_item );
    }

    $action_executor->process_action_queue;
}

# Minimal iterator that chains a list of DBIx::Class resultsets so the
# dispatch code can keep using ->next. Used only by the per-branch fallback.
package Koha::Overdues::_ChainedResultset;

sub new {
    my ( $class, $resultsets ) = @_;
    return bless { resultsets => $resultsets, current => 0 }, $class;
}

sub next {
    my ($self) = @_;
    while ( $self->{current} < @{ $self->{resultsets} } ) {
        my $row = $self->{resultsets}->[ $self->{current} ]->next;
        return $row if $row;
        $self->{current}++;
    }
    return;
}

1;
