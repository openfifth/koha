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
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Logger;

=head1 NAME

Koha::Overdues::Repository - Data access layer for the overdues trigger system.

=head1 API

=head2 Class Methods

=head3 get_overdue_summaries_by_delays

my $overdues = Koha::Overdues::Repository->get_overdue_summaries_by_delays( \@known_delay_values )

Fetches overdue checkouts whose date_due matches one of the known trigger delay dates.
Returns a Koha::Checkouts resultset.

=cut

sub get_overdue_summaries_by_delays {
    my ( $self, $known_delay_values ) = @_;

    if ( !@$known_delay_values ) {
        return;
    }

    my $today = dt_from_string;
    my $where =
        { -or => [ map { $self->_date_range_clause( $today->clone->subtract( days => $_ ) ) } @$known_delay_values ] };

    try {
        return Koha::Checkouts->search( $where, { overdue_summaries_query_attributes() } );
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

=head3 get_distinct_overdue_branches

  my @branches = Koha::Overdues::Repository->get_distinct_overdue_branches($min_delay);

Cheap pre-query for the calendar-adjusted trigger path: returns the distinct
rule-context branchcodes that have at least one checkout overdue by C<$min_delay>
or more days. The column used depends on
L</rule_context_branch_column>. Accounts for the relevant branch being determined by
patron.homebranch OR item.homebranch OR item.holding branch based on 
rule_context_branch_column.

=cut

sub get_distinct_overdue_branches {
    my ( $self, $min_delay ) = @_;

    if ( !defined $min_delay ) {
        return;
    }

    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $cutoff_exclusive =
        dt_from_string->subtract( days => $min_delay )->truncate( to => 'day' )->add( days => 1 );

    my $col = $self->rule_context_branch_column;
    my ($relationship_name) = split /\./, $col;

    try {
        my $rs = Koha::Checkouts->search(
            { date_due => { '<' => $dtf->format_datetime($cutoff_exclusive) } },
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

=head3 get_overdue_summaries_by_branch_date_pairs

  my $rs = Koha::Overdues::Repository->get_overdue_summaries_by_branch_date_pairs(
      [ { branchcode => 'CPL', dates => [ '2026-05-27', '2026-05-20' ] },
        { branchcode => 'MPL', dates => [ '2026-05-28' ] }, ... ] );

Algorithm 2: single SQL with one OR-clause per branch, each clause matching
that branch's pre-computed exact target dates. The branch comparison uses
L</rule_context_branch_column>. Returns a L<Koha::Checkouts> resultset.

=cut

sub get_overdue_summaries_by_branch_date_pairs {
    my ( $self, $pairs ) = @_;
    if ( !$pairs || !@$pairs ) {
        return;
    }

    my @or_clauses;
    for my $pair (@$pairs) {
        if ( !$pair->{dates} || !@{ $pair->{dates} } ) {
            next;
        }
        push @or_clauses, $self->_branch_dates_clause( $pair->{branchcode}, $pair->{dates} );
    }

    if ( !@or_clauses ) {
        return;
    }

    my $where = { -or => \@or_clauses };

    try {
        return Koha::Checkouts->search( $where, { overdue_summaries_query_attributes() } );
    } catch {
        Koha::Logger->get->error("Failed to fetch overdues by branch/date pairs: $_");
        return;
    };
}

=head3 get_overdue_summaries_by_branch_dates

  my $rs = Koha::Overdues::Repository->get_overdue_summaries_by_branch_dates(
      'CPL', [ '2026-05-27', '2026-05-20' ] );

Algorithm 3: per-branch fallback for cases where the single OR-clause would
grow too large (large fleets with many branches). Same shape as
L</get_overdue_summaries_by_branch_date_pairs> but scoped to one branch.

=cut

sub get_overdue_summaries_by_branch_dates {
    my ( $self, $branchcode, $dates ) = @_;
    return unless defined $branchcode && $dates && @$dates;

    my $where = $self->_branch_dates_clause( $branchcode, $dates );

    try {
        return Koha::Checkouts->search( $where, { overdue_summaries_query_attributes() } );
    } catch {
        Koha::Logger->get->error("Failed to fetch overdues by branch+dates for $branchcode: $_");
        return;
    };
}

=head3 _branch_dates_clause

  my $clause = $self->_branch_dates_clause( $branchcode, \@dates );

Builds the SQL::Abstract clause matching rows whose rule-context branch equals
C<$branchcode> and whose C<date_due> falls on any of the given calendar dates,
used by L</get_overdue_summaries_by_branch_date_pairs> and
L</get_overdue_summaries_by_branch_dates>. The branch column comes from
L</rule_context_branch_column>.

=cut

sub _branch_dates_clause {
    my ( $self, $branchcode, $dates ) = @_;

    my $col = $self->rule_context_branch_column;

    return {
        $col => $branchcode,
        -or  => [ map { $self->_date_range_clause( dt_from_string($_) ) } @$dates ],
    };
}

=head3 _date_range_clause

  my $clause = $self->_date_range_clause( $date );

Returns a SQL::Abstract clause matching rows whose C<date_due> falls on the
calendar day of C<$date> (a DateTime), expressed as a half-open datetime range
C<< [start_of_day, next_day) >>. Avoids C<DATE()> wraps so any index on
C<date_due> stays usable.

=cut

sub _date_range_clause {
    my ( $self, $date ) = @_;

    my $dtf   = Koha::Database->new->schema->storage->datetime_parser;
    my $start = $date->clone->truncate( to => 'day' );
    my $end   = $start->clone->add( days => 1 );

    return {
        date_due => {
            '>=' => $dtf->format_datetime($start),
            '<'  => $dtf->format_datetime($end),
        },
    };
}

=head3 overdue_summaries_query_attributes

Returns the DBIx::Class search attributes shared by the three overdue-summary
fetch methods: prefetch C<item> and C<patron> so the dispatch loop can read
joined fields via Koha::Object accessors.

=cut

sub overdue_summaries_query_attributes {
    return (
        prefetch => [ 'item',        'patron' ],
        order_by => [ 'me.date_due', 'me.borrowernumber' ],
    );
}

1;
