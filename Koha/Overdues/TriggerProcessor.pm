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
$triggerProcessor = Koha::Overdues::TriggerProcessor->new( { verbose => 1, debug => 1 } );

Optional C<verbose> and C<debug> flags drive the queue-dump and rule-set-dump
output emitted by L</_dispatch_overdues> for the C<--verbose> / C<--debug>
modes of C<process_circulation_triggers.pl>.

=cut

sub new {
    my ( $class, $params ) = @_;
    my $self = {
        verbose => $params->{verbose} // 0,
        debug   => $params->{debug}   // 0,
    };
    return bless $self, $class;
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

    my $min_delay = $known_delay_values[0];
    my @branches  = Koha::Overdues::Repository->get_distinct_overdue_branches($min_delay);
    if ( !@branches ) {
        return;
    }

    my %effective_delay_by_raw_delay;    # branchcode => { raw_delay => effective_delay }
    for my $branch (@branches) {
        for my $delay (@known_delay_values) {
            $effective_delay_by_raw_delay{$branch}{$delay} = $delay;
        }
    }

    my $allOverduesForKnownDelays = Koha::Overdues::Repository->get_overdue_summaries_by_delays( \@known_delay_values );

    if ( !$allOverduesForKnownDelays ) {
        return;
    }

    return $self->_dispatch_overdues( $allOverduesForKnownDelays, \%effective_delay_by_raw_delay );
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
    my @branches  = Koha::Overdues::Repository->get_distinct_overdue_branches($min_delay);
    if ( !@branches ) {
        return;
    }

    my $today     = dt_from_string;
    my $days_mode = C4::Context->preference('useDaysMode');

    my %target_dates_by_branch;
    my %effective_delay_by_raw_delay;    # branchcode => { raw_delay => effective_delay }
    for my $branch (@branches) {
        my $calendar = Koha::Calendar->new( branchcode => $branch, days_mode => $days_mode );
        my @dates;
        for my $delay (@known_delay_values) {
            my $target_dt       = $calendar->days_backward( $today->clone, $delay );
            my $effective_delay = $today->delta_days($target_dt)->in_units('days');
            push @dates, $target_dt->strftime('%Y-%m-%d');
            $effective_delay_by_raw_delay{$branch}{$delay} = $effective_delay;
        }
        $target_dates_by_branch{$branch} = \@dates;
    }

    my $pair_count = @branches * @known_delay_values;

    my $overdues_resultset;
    if ( $pair_count > CALENDAR_PAIRS_INLINE_LIMIT ) {
        $overdues_resultset = $self->_fetch_per_branch( \%target_dates_by_branch );
    } else {
        my @pairs = map { { branchcode => $_, dates => $target_dates_by_branch{$_} } } @branches;
        $overdues_resultset = Koha::Overdues::Repository->get_overdue_summaries_by_branch_date_pairs( \@pairs );
    }

    if ( !$overdues_resultset ) {
        return;
    }

    return $self->_dispatch_overdues( $overdues_resultset, \%effective_delay_by_raw_delay );
}

# Alg 3 fallback: issue one query per branch and return a merged in-memory
# resultset-like iterator. The downstream code only needs ->next, so we wrap
# the per-branch resultsets in a minimal chained iterator.
sub _fetch_per_branch {
    my ( $self, $target_dates_by_branch ) = @_;

    my @resultsets;
    for my $branch ( keys %$target_dates_by_branch ) {
        my $rs = Koha::Overdues::Repository->get_overdue_summaries_by_branch_dates(
            $branch,
            $target_dates_by_branch->{$branch}
        );
        push @resultsets, $rs if $rs;
    }
    return unless @resultsets;

    return Koha::Overdues::_ChainedResultset->new( \@resultsets );
}

# Shared post-fetch flow: walk the resultset, collect dimensions, resolve
# rules, route through ActionExecutor. Identical for both simple and
# calendar-adjusted paths.
sub _dispatch_overdues {
    my ( $self, $overdues_resultset, $effective_delay_by_raw_delay ) = @_;

    my $today_date = dt_from_string->truncate( to => 'day' );

    my %seen_branches;
    my %seen_categories;
    my %seen_itemtypes;
    my @overdue_items;

    while ( my $row = $overdues_resultset->next ) {
        my $item         = $row->item;
        my $patron       = $row->patron;
        my $due_date     = dt_from_string( $row->date_due )->truncate( to => 'day' );
        my $days_overdue = $today_date->delta_days($due_date)->in_units('days');

        $seen_branches{ $row->branchcode }        = 1;
        $seen_categories{ $patron->categorycode } = 1;
        $seen_itemtypes{ $item->itype }           = 1;

        my $item_hashref = {
            issue_id          => $row->issue_id,
            borrowernumber    => $row->borrowernumber,
            itemnumber        => $row->itemnumber,
            branchcode        => $row->branchcode,
            date_due          => $row->date_due,
            categorycode      => $patron->categorycode,
            itemtype          => $item->itype,
            days_overdue      => $days_overdue,
            biblionumber      => $item->biblionumber,
            replacementfee    => $item->replacementprice,
            itemhomebranch    => $item->homebranch,
            itemholdingbranch => $item->holdingbranch,
            patronhomebranch  => $patron->branchcode,
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
        \@itemtype_list, $effective_delay_by_raw_delay
    );

    my $action_executor = Koha::Overdues::ActionExecutor->new();

    # separate notice route actions from standard route actions
    foreach my $overdue_item (@overdue_items) {
        $action_executor->route_item_actions_to_queue( $rule_resolver->{effective_overdue_rule_sets}, $overdue_item );
    }

    if ( $self->{debug} ) {
        require Data::Dumper;
        local $Data::Dumper::Sortkeys = 1;
        local $Data::Dumper::Indent   = 1;
        print STDERR Data::Dumper->Dump( [ \@overdue_items ], ['overdue_items'] );
        print STDERR Data::Dumper->Dump(
            [ $rule_resolver->{effective_overdue_rule_sets} ],
            ['effective_overdue_rule_sets']
        );
        print STDERR Data::Dumper->Dump( [ $action_executor->{action_batch_queue} ], ['action_batch_queue'] );
        print STDERR Data::Dumper->Dump( [ $action_executor->{notice_queue} ],       ['notice_queue'] );

    }

    if ( $self->{verbose} ) {
        $action_executor->print_queues;
    }

    $action_executor->process_action_queue;
    $action_executor->process_notice_queue;
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
