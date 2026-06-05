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
use Test::More tests => 4;

use Koha::CirculationRules;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Overdues::TriggerProcessor;
use Koha::Patron::Restriction;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'no overdue delay rules → early return' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar', 0 );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue%delay' } } )->delete;

    my $tp = Koha::Overdues::TriggerProcessor->new;
    is( $tp->ProcessOverdues, undef, 'returns early when no overdue delay rules exist' );

    $schema->storage->txn_rollback;
};

subtest 'ProcessOverdues simple path — lost + restrict end-to-end' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar',   0 );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );
    t::lib::Mocks::mock_preference( 'CircControl',               'PatronLibrary' );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $item = $builder->build_sample_item( { homebranch => $library->branchcode, replacementprice => 5 } );

    my $today = dt_from_string;
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $today->clone->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    # Trigger 1: at delay 7, set lost=1 and restrict=1 for the patron's library + cat + itype context.
    for my $row (
        [ 'overdue_1_delay',    7 ],
        [ 'overdue_1_lost',     1 ],
        [ 'overdue_1_restrict', 1 ],
        )
    {
        Koha::CirculationRules->set_rule(
            {
                branchcode   => $library->branchcode,
                categorycode => $patron->categorycode,
                itemtype     => $item->effective_itemtype,
                rule_name    => $row->[0],
                rule_value   => $row->[1],
            }
        );
    }

    Koha::Overdues::TriggerProcessor->new->ProcessOverdues;

    $item->discard_changes;
    is( $item->itemlost, 1, 'item marked lost via the trigger pipeline' );

    my $restrictions_first_pass = $patron->restrictions->search( { type => 'OVERDUES' } );
    is( $restrictions_first_pass->count,            1,          'one OVERDUES restriction added' );
    is( $restrictions_first_pass->next->type->code, 'OVERDUES', 'restriction type is OVERDUES' );

    # A second pass should not re-add a debarment (AddUniqueDebarment dedupes).
    Koha::Overdues::TriggerProcessor->new->ProcessOverdues;
    my $restrictions_second_pass = $patron->restrictions->search( { type => 'OVERDUES' } );
    is( $restrictions_second_pass->count, 1, 'one OVERDUES restriction added' );

    # is( $restrictions_second_pass->next->type->code, 'OVERDUES', 'second pass does not duplicate the OVERDUES debarment' );

    $schema->storage->txn_rollback;
};

subtest 'ProcessOverdues calendar-adjusted path — closure shifts target date' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar',   1 );
    t::lib::Mocks::mock_preference( 'useDaysMode',               'Calendar' );
    t::lib::Mocks::mock_preference( 'CircControl',               'PatronLibrary' );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    $builder->build(
        {
            source => 'BorrowerMessagePreference',
            value  => { borrowernumber => $patron->borrowernumber, wants_digest => 0 },
        }
    );

    # Mark the past 3 calendar days (today-1, today-2, today-3) as closed.
    # With a delay of 7 open days, the target date becomes today-10 calendar
    # days; with a simple DATEDIFF=7 path, only today-7 would match.
    my $today = dt_from_string;
    for my $back ( 1 .. 3 ) {
        my $closed = $today->clone->subtract( days => $back );
        $builder->build(
            {
                source => 'SpecialHoliday',
                value  => {
                    branchcode  => $library->branchcode,
                    day         => $closed->day,
                    month       => $closed->month,
                    year        => $closed->year,
                    title       => "closure $back days ago",
                    isexception => 0,
                },
            }
        );
    }

    my $item = $builder->build_sample_item( { homebranch => $library->branchcode, replacementprice => 5 } );

    # Due 10 calendar days ago = exactly 7 open days ago given the 3 closures.
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $today->clone->subtract( days => 10 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    for my $row (
        [ 'overdue_1_delay',    7 ],
        [ 'overdue_1_lost',     1 ],
        [ 'overdue_1_restrict', 1 ],
        )
    {
        Koha::CirculationRules->set_rule(
            {
                branchcode   => $library->branchcode,
                categorycode => $patron->categorycode,
                itemtype     => $item->effective_itemtype,
                rule_name    => $row->[0],
                rule_value   => $row->[1],
            }
        );
    }

    Koha::Overdues::TriggerProcessor->new->ProcessOverdues;

    $item->discard_changes;
    is( $item->itemlost, 1, 'calendar-adjusted path triggers on item due 10 calendar days ago (7 open days)' );

    my $restrictions_first_pass = $patron->restrictions->search( { type => 'OVERDUES' } );
    is( $restrictions_first_pass->count, 1, 'one OVERDUES restriction added via calendar-adjusted path' );

    # is( $restrictions_first_pass->next->type->code, 'OVERDUES', 'restriction type is OVERDUES' );

    $schema->storage->txn_rollback;
};
