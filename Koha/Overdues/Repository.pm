package Koha::Overdues::Repository;

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
use Try::Tiny;
use C4::Context;
use Koha::Checkouts;
use Koha::DateUtils qw( dt_from_string );
use Koha::Logger;

=head1 NAME

Koha::Overdues::Repository - Data access layer for the overdues trigger system.

=head1 API

=head2 Class Methods

=head3 GetOverdueSummariesForKnownTriggerDelays

my $overdues = Koha::Overdues::Repository->GetOverdueSummariesForKnownTriggerDelays( \@known_delay_values )

Fetches overdue checkouts whose date_due matches one of the known trigger delay dates.
Returns a Koha::Checkouts resultset.

=cut

sub GetOverdueSummariesForKnownTriggerDelays {
    my ( $class, $known_delay_values ) = @_;

    if ( !@$known_delay_values ) {
        return;
    }

    my %attributes = overdue_summaries_query_attributes();
    $attributes{order_by} = \'me.date_due, me.borrowernumber';

    my @dates = map { dt_from_string()->subtract( days => $_ )->strftime('%Y-%m-%d') } @$known_delay_values;

    my $where = \[
        'DATE(me.date_due) IN (' . join( ',', ('?') x @dates ) . ')',
        @dates
    ];

    try {
        return Koha::Checkouts->search( $where, \%attributes );
    } catch {
        Koha::Logger->get->error("Failed to fetch overdues for known trigger delays: $_");
        return;
    };
}

=head3 rule_context_branch_column

  my $col = Koha::Overdues::Repository->rule_context_branch_column;

Returns the fully-qualified column expression that holds the branchcode used
to key the effective rule-set lookup, honoring C<CircControl> and
C<HomeOrHoldingBranch>. Mirrors the resolution in
L<Koha::Overdues::ActionExecutor/_resolve_rule_context_branchcode>: in cron
context (no userenv) C<PickupLibrary> falls through to the item-side path,
matching C<C4::Circulation::_GetCircControlBranch>.

=cut

sub rule_context_branch_column {
    my $circ_control = C4::Context->preference('CircControl') // '';

    if ( $circ_control eq 'PatronLibrary' ) {
        return 'patron.branchcode';
    }

    my $use_item_holdingbranch = ( C4::Context->preference('HomeOrHoldingBranch') // '' ) eq 'holdingbranch';
    return $use_item_holdingbranch ? 'item.holdingbranch' : 'item.homebranch';
}

=head3 GetDistinctOverdueBranches

  my @branches = Koha::Overdues::Repository->GetDistinctOverdueBranches($min_delay);

Cheap pre-query for the calendar-adjusted trigger path: returns the distinct
rule-context branchcodes that have at least one checkout overdue by C<$min_delay>
or more days. The column used depends on
L</rule_context_branch_column>. Accounts for the relevant branch being determined by
patron.homebranch OR item.homebranch OR item.holding branch based on 
rule_context_branch_column.

=cut

sub GetDistinctOverdueBranches {
    my ( $class, $min_delay ) = @_;

    if ( !defined $min_delay ) {
        return;
    }

    my $iso_cutoff_date     = dt_from_string()->subtract( days => $min_delay )->strftime('%Y-%m-%d');
    my $col                 = $class->rule_context_branch_column;
    my ($relationship_name) = split /\./, $col;

    try {
        my $rs = Koha::Checkouts->search(
            \[ 'DATE(me.date_due) <= ?', $iso_cutoff_date ],
            {
                join     => $relationship_name,
                select   => [$col],
                as       => ['rule_branch'],
                group_by => [$col],
            }
        );
        return $rs->get_column('rule_branch');
    } catch {
        Koha::Logger->get->error("Failed to fetch distinct overdue branches: $_");
        return;
    };
}

=head3 GetOverdueSummariesByBranchDatePairs

  my $rs = Koha::Overdues::Repository->GetOverdueSummariesByBranchDatePairs(
      [ { branchcode => 'CPL', dates => [ '2026-05-27', '2026-05-20' ] },
        { branchcode => 'MPL', dates => [ '2026-05-28' ] }, ... ] );

Algorithm 2: single SQL with one OR-clause per branch, each clause matching
that branch's pre-computed exact target dates. The branch comparison uses
L</rule_context_branch_column>. Returns a L<Koha::Checkouts> resultset.

=cut

sub GetOverdueSummariesByBranchDatePairs {
    my ( $self, $pairs ) = @_;
    if ( !$pairs || !@$pairs ) {
        return;
    }

    my @or_clauses;
    my @binds;
    for my $pair (@$pairs) {
        if ( !$pair->{dates} || !@{ $pair->{dates} } ) {
            next;
        }
        my ( $clause, $clause_binds ) =
            $self->_branch_dates_clause( $pair->{branchcode}, $pair->{dates} );
        push @or_clauses, $clause;
        push @binds,      @$clause_binds;
    }

    if ( !@or_clauses ) {
        return;
    }

    my %attributes = overdue_summaries_query_attributes();
    $attributes{order_by} = \'me.date_due, me.borrowernumber';

    my $where = \[ '(' . join( ' OR ', @or_clauses ) . ')', @binds ];

    try {
        return Koha::Checkouts->search( $where, \%attributes );
    } catch {
        Koha::Logger->get->error("Failed to fetch overdues by branch/date pairs: $_");
        return;
    };
}

=head3 GetOverdueSummariesByBranchDates

  my $rs = Koha::Overdues::Repository->GetOverdueSummariesByBranchDates(
      'CPL', [ '2026-05-27', '2026-05-20' ] );

Algorithm 3: per-branch fallback for cases where the single OR-clause would
grow too large (large fleets with many branches). Same shape as
L</GetOverdueSummariesByBranchDatePairs> but scoped to one branch.

=cut

sub GetOverdueSummariesByBranchDates {
    my ( $class, $branchcode, $dates ) = @_;
    return unless defined $branchcode && $dates && @$dates;

    my %attributes = overdue_summaries_query_attributes();
    $attributes{order_by} = \'me.date_due, me.borrowernumber';

    my ( $clause, $clause_binds ) = $class->_branch_dates_clause( $branchcode, $dates );
    my $where = \[ $clause, @$clause_binds ];

    try {
        return Koha::Checkouts->search( $where, \%attributes );
    } catch {
        Koha::Logger->get->error("Failed to fetch overdues by branch+dates for $branchcode: $_");
        return;
    };
}

=head3 _branch_dates_clause

  my ( $clause, $binds ) = $class->_branch_dates_clause( $branchcode, \@dates );

Builds the C<(branch_col = ? AND DATE(me.date_due) IN (?, ?, ...))> SQL
fragment used by L</GetOverdueSummariesByBranchDatePairs> and
L</GetOverdueSummariesByBranchDates>. The branch column comes from
L</rule_context_branch_column>. Returns the SQL string and an arrayref of
bind values in the order C<($branchcode, @dates)>.

=cut

sub _branch_dates_clause {
    my ( $class, $branchcode, $dates ) = @_;

    my $col          = $class->rule_context_branch_column;
    my $placeholders = join( ',', ('?') x @$dates );
    my $clause       = "($col = ? AND DATE(me.date_due) IN ($placeholders))";

    return ( $clause, [ $branchcode, @$dates ] );
}

=head3 overdue_summaries_query_attributes

Returns the DBIx::Class search attributes required to fetch overdue summaries
for the circulation triggers script.

=cut

sub overdue_summaries_query_attributes {
    return (
        join => [
            'item',
            { 'patron' => 'borrower_message_preferences' },
        ],
        '+select' => [
            'item.biblionumber',
            'item.itype',
            'item.replacementprice',
            'item.homebranch',
            'item.holdingbranch',
            'patron.categorycode',
            'patron.branchcode',
            \["DATEDIFF(CURDATE(), DATE(me.date_due))"],
            'borrower_message_preferences.wants_digest',
        ],
        '+as' => [
            'biblionumber',
            'itemtype',
            'replacementfee',
            'itemhomebranch',
            'itemholdingbranch',
            'categorycode',
            'patronhomebranch',
            'days_overdue',
            'notice_preferences',
        ],
        group_by => [
            'me.borrowernumber',
            'me.issue_id',
            'me.issuer_id',
            'me.itemnumber',
            'me.booking_id',
            'me.date_due',
            'me.branchcode',
            'me.returndate',
            'me.checkin_library',
            'me.lastreneweddate',
            'me.renewals_count',
            'me.unseen_renewals',
            'me.auto_renew',
            'me.auto_renew_error',
            'me.timestamp',
            'me.issuedate',
            'me.onsite_checkout',
            'me.note',
            'me.notedate',
            'me.noteseen',
            'item.biblionumber',
            'item.itype',
            'item.replacementprice',
            'item.homebranch',
            'item.holdingbranch',
            'patron.categorycode',
            'patron.branchcode',
            \["DATEDIFF(CURDATE(), DATE(me.date_due))"],
            'borrower_message_preferences.wants_digest',
        ],
    );
}

1;
