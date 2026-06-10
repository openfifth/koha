#!/usr/bin/perl

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

use Test::NoWarnings;
use Test::More tests => 6;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Overdues::Repository;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'empty delay list returns nothing' => sub {
    plan tests => 1;

    is(
        Koha::Overdues::Repository->get_overdue_summaries_by_delays( [] ),
        undef, 'no delays in → undef out'
    );
};

subtest 'get_overdue_summaries_by_delays filters by date_due matching known delays' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron_a = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_b = $builder->build_object( { class => 'Koha::Patrons' } );

    # patron_a has BorrowerMessagePreference, patron_b does not
    # we want to ensure overdues are included regardless
    $builder->build(
        {
            source => 'BorrowerMessagePreference',
            value  => {
                borrowernumber => $patron_a->borrowernumber,
                wants_digest   => 0,
            },
        }
    );

    # Three checkouts: 7 days overdue, 14 days overdue, and 3 days overdue (not a known delay, expecting exclusion).
    my $today = dt_from_string;

    my $item_7  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue_7 = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_a->borrowernumber,
                itemnumber     => $item_7->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $today->clone->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    my $item_14_a  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue_14_a = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_a->borrowernumber,
                itemnumber     => $item_14_a->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $today->clone->subtract( days => 14 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    my $item_14_b  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue_14_b = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_b->borrowernumber,
                itemnumber     => $item_14_b->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $today->clone->subtract( days => 14 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    my $item_3  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue_3 = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_a->borrowernumber,
                itemnumber     => $item_3->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $today->clone->subtract( days => 3 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    my $rs = Koha::Overdues::Repository->get_overdue_summaries_by_delays( [ 7, 14 ] );
    isa_ok( $rs, 'Koha::Checkouts', 'returns a Koha::Checkouts resultset' );

    my %seen;
    while ( my $row = $rs->next ) {
        $seen{ $row->itemnumber } = 1;
    }

    ok( $seen{ $item_7->itemnumber },    '7-day overdue checkout returned' );
    ok( $seen{ $item_14_a->itemnumber }, '14-day overdue returned when patron has prefs' );
    ok( $seen{ $item_14_b->itemnumber }, '14-day overdue returned when patron has no prefs' );
    ok( !$seen{ $item_3->itemnumber },   '3-day overdue checkout excluded (not a known delay)' );

    $schema->storage->txn_rollback;
};

subtest 'rule_context_branch_column honours CircControl + HomeOrHoldingBranch' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );
    is(
        Koha::Overdues::Repository->rule_context_branch_column,
        'patron.branchcode', 'PatronLibrary → patron.branchcode'
    );

    t::lib::Mocks::mock_preference( 'CircControl',         'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'homebranch' );
    is(
        Koha::Overdues::Repository->rule_context_branch_column,
        'item.homebranch', 'ItemHomeLibrary + homebranch → item.homebranch'
    );

    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'holdingbranch' );
    is(
        Koha::Overdues::Repository->rule_context_branch_column,
        'item.holdingbranch', 'ItemHomeLibrary + holdingbranch → item.holdingbranch'
    );

    t::lib::Mocks::mock_preference( 'CircControl',         'PickupLibrary' );
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'homebranch' );
    is(
        Koha::Overdues::Repository->rule_context_branch_column,
        'item.homebranch', 'PickupLibrary falls through to item-side path (matches _GetCircControlBranch)'
    );
};

subtest 'get_distinct_overdue_branches' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library_a = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_b = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_c = $builder->build_object( { class => 'Koha::Libraries' } );    # no overdues

    my $patron_a =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_a->branchcode } } );
    my $patron_b =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_b->branchcode } } );

    my $item_a = $builder->build_sample_item( { homebranch => $library_a->branchcode } );
    my $item_b = $builder->build_sample_item( { homebranch => $library_b->branchcode } );

    my $today = dt_from_string;
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_a->borrowernumber,
                itemnumber     => $item_a->itemnumber,
                branchcode     => $library_a->branchcode,
                date_due       => $today->clone->subtract( days => 10 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_b->borrowernumber,
                itemnumber     => $item_b->itemnumber,
                branchcode     => $library_b->branchcode,
                date_due       => $today->clone->subtract( days => 2 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    # Filter results to the branches we created — the kohadev DB may carry
    # unrelated committed checkouts (manual_test seeds etc.) that get_distinct_overdue_branches
    # legitimately reports but the test isn't interested in.
    my %ours = map { $_->branchcode => 1 } ( $library_a, $library_b, $library_c );

    # min_delay = 5: library_a's patron is 10 days overdue (in), library_b's is 2 days overdue (out).
    my @branches = sort grep { $ours{$_} } Koha::Overdues::Repository->get_distinct_overdue_branches(5);
    is( scalar @branches, 1,                      'min_delay=5: only one of our branches' );
    is( $branches[0],     $library_a->branchcode, 'returns the patron branch with sufficiently-overdue items' );

    # min_delay = 1: both branches qualify.
    @branches = sort grep { $ours{$_} } Koha::Overdues::Repository->get_distinct_overdue_branches(1);
    is( scalar @branches, 2, 'min_delay=1: both of our overdue branches' );

    # library_c (no overdues) never appears.
    ok(
        !grep( { $_ eq $library_c->branchcode } @branches ),
        'branch without overdues not returned'
    );

    $schema->storage->txn_rollback;
};

subtest 'get_overdue_summaries_by_branch_date_pairs + get_overdue_summaries_by_branch_dates' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library_a = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_b = $builder->build_object( { class => 'Koha::Libraries' } );

    my $patron_a =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_a->branchcode } } );
    my $patron_b =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_b->branchcode } } );

    $builder->build(
        {
            source => 'BorrowerMessagePreference',
            value  => { borrowernumber => $patron_a->borrowernumber, wants_digest => 0 },
        }
    );
    $builder->build(
        {
            source => 'BorrowerMessagePreference',
            value  => { borrowernumber => $patron_b->borrowernumber, wants_digest => 0 },
        }
    );

    my $item_a = $builder->build_sample_item( { homebranch => $library_a->branchcode } );
    my $item_b = $builder->build_sample_item( { homebranch => $library_b->branchcode } );

    my $today  = dt_from_string;
    my $date_a = $today->clone->subtract( days => 7 )->strftime('%Y-%m-%d');
    my $date_b = $today->clone->subtract( days => 14 )->strftime('%Y-%m-%d');

    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_a->borrowernumber,
                itemnumber     => $item_a->itemnumber,
                branchcode     => $library_a->branchcode,
                date_due       => "$date_a 23:59:00",
            },
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron_b->borrowernumber,
                itemnumber     => $item_b->itemnumber,
                branchcode     => $library_b->branchcode,
                date_due       => "$date_b 23:59:00",
            },
        }
    );

    # Alg 2: pairs hit each branch's exact date.
    my $rs = Koha::Overdues::Repository->get_overdue_summaries_by_branch_date_pairs(
        [
            { branchcode => $library_a->branchcode, dates => [$date_a] },
            { branchcode => $library_b->branchcode, dates => [$date_b] },
        ]
    );
    my %seen;
    while ( my $row = $rs->next ) { $seen{ $row->itemnumber } = 1 }
    ok( $seen{ $item_a->itemnumber }, 'pair (A, date_a) matches item A' );
    ok( $seen{ $item_b->itemnumber }, 'pair (B, date_b) matches item B' );

    # Cross-pair must NOT match — branch A on date B shouldn't return item B.
    $rs = Koha::Overdues::Repository->get_overdue_summaries_by_branch_date_pairs(
        [
            { branchcode => $library_a->branchcode, dates => [$date_b] },
        ]
    );
    %seen = ();
    while ( my $row = $rs->next ) { $seen{ $row->itemnumber } = 1 }
    ok( !$seen{ $item_b->itemnumber }, 'pair (A, date_b) does not return item B (branch mismatch)' );

    # Alg 3: single-branch variant.
    $rs   = Koha::Overdues::Repository->get_overdue_summaries_by_branch_dates( $library_a->branchcode, [$date_a] );
    %seen = ();
    while ( my $row = $rs->next ) { $seen{ $row->itemnumber } = 1 }
    ok( $seen{ $item_a->itemnumber },  'per-branch variant returns item A' );
    ok( !$seen{ $item_b->itemnumber }, 'per-branch variant scoped to A excludes B' );

    # Empty pair list short-circuits.
    is(
        Koha::Overdues::Repository->get_overdue_summaries_by_branch_date_pairs( [] ),
        undef, 'empty pair list returns undef'
    );

    $schema->storage->txn_rollback;
};
