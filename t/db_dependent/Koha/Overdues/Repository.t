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
use Test::More tests => 3;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Overdues::Repository;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'empty delay list returns nothing' => sub {
    plan tests => 1;

    is(
        Koha::Overdues::Repository->GetOverdueSummariesForKnownTriggerDelays( [] ),
        undef, 'no delays in → undef out'
    );
};

subtest 'GetOverdueSummariesForKnownTriggerDelays filters by date_due matching known delays' => sub {
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

    my $rs = Koha::Overdues::Repository->GetOverdueSummariesForKnownTriggerDelays( [ 7, 14 ] );
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
