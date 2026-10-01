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
use Test::MockModule;
use Test::More tests => 9;

use Koha::Notice::Messages;

use Koha::CirculationRules;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Library::Calendar;
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

subtest 'ProcessOverdues resolves rules by the correct branch as defined by CircControl' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar',   0 );
    t::lib::Mocks::mock_preference( 'CircControl',               'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch',       'homebranch' );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;

    my $rule_library    = $builder->build_object( { class => 'Koha::Libraries' } );
    my $issuing_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron_library  = $builder->build_object( { class => 'Koha::Libraries' } );

    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $patron_library->branchcode } } );
    my $item = $builder->build_sample_item( { homebranch => $rule_library->branchcode, replacementprice => 5 } );

    my $today = dt_from_string;
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $issuing_library->branchcode,
                date_due       => $today->clone->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    # The trigger is defined only for the item's home library.
    for my $row (
        [ 'overdue_1_delay', 7 ],
        [ 'overdue_1_lost',  1 ],
        )
    {
        Koha::CirculationRules->set_rule(
            {
                branchcode   => $rule_library->branchcode,
                categorycode => $patron->categorycode,
                itemtype     => $item->effective_itemtype,
                rule_name    => $row->[0],
                rule_value   => $row->[1],
            }
        );
    }

    Koha::Overdues::TriggerProcessor->new->ProcessOverdues();

    $item->discard_changes;
    is(
        $item->itemlost, 1,
        'rule defined on the item home library applies to a checkout made at another library'
    );

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
    my $today    = dt_from_string;
    my $calendar = Koha::Library::Calendar->new( branchcode => $library->branchcode );
    for my $back ( 1 .. 3 ) {
        my $closed = $today->clone->subtract( days => $back );
        $calendar->add_single_closure(
            {
                date        => $closed->ymd,
                title       => "closure $back days ago",
                description => '',
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

subtest 'ProcessOverdues notice path — email rule degrades to print for patron with no email' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar', 0 );
    t::lib::Mocks::mock_preference( 'CircControl',             'PatronLibrary' );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode => $library->branchcode,
                email      => q{},
                emailpro   => q{},
                B_email    => q{},
            }
        }
    );

    my $item = $builder->build_sample_item( { homebranch => $library->branchcode } );

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

    for my $row (
        [ 'overdue_1_delay',  7 ],
        [ 'overdue_1_notice', 'OD1' ],
        [ 'overdue_1_mtt',    'email' ],
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

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD1',
                branchcode             => q{},
                message_transport_type => 'print',
                name                   => 'OD1 print',
                title                  => 'OD1',
                content                => 'print body',
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    Koha::Overdues::TriggerProcessor->new->ProcessOverdues;

    my $messages =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } );
    is( $messages->count, 1, 'one Koha::Notice::Message row for the overdue patron' );
    is(
        $messages->next->message_transport_type, 'print',
        'email rule degraded to print via the no-email patron path'
    );

    $schema->storage->txn_rollback;
};

subtest 'ProcessOverdues backdated run — trigger_date replays the day a run was missed' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar',   0 );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );
    t::lib::Mocks::mock_preference( 'CircControl',               'PatronLibrary' );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $item = $builder->build_sample_item( { homebranch => $library->branchcode, replacementprice => 5 } );

    # Due 10 days ago, with a delay of 7: the run that should have caught this
    # item was the one due to happen 3 days ago, and it never ran.
    my $missed_run_date = dt_from_string->subtract( days => 3 );
    $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library->branchcode,
                date_due       => $missed_run_date->clone->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S'),
            },
        }
    );

    for my $row (
        [ 'overdue_1_delay', 7 ],
        [ 'overdue_1_lost',  1 ],
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

    # Today's run cannot reach it: the item is 10 days overdue, and actions fire
    # only on the exact day a delay comes due.
    Koha::Overdues::TriggerProcessor->new->ProcessOverdues;

    $item->discard_changes;
    is( $item->itemlost, 0, 'a run anchored on today passes over the day that was missed' );

    Koha::Overdues::TriggerProcessor->new( { trigger_date => $missed_run_date } )->ProcessOverdues;

    $item->discard_changes;
    is( $item->itemlost, 1, 'backdating trigger_date to the missed day fires the delay 7 trigger' );

    $schema->storage->txn_rollback;
};

subtest 'ProcessOverdues calendar-adjusted path — a branch closed on the run date is skipped' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar',   1 );
    t::lib::Mocks::mock_preference( 'useDaysMode',               'Calendar' );
    t::lib::Mocks::mock_preference( 'CircControl',               'PatronLibrary' );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );

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

    # The run date itself is a closure for this branch.
    Koha::Library::Calendar->new( branchcode => $library->branchcode )->add_single_closure(
        {
            date        => $today->ymd,
            title       => 'closed on the run date',
            description => '',
        }
    );

    for my $row ( [ 'overdue_1_delay', 7 ], [ 'overdue_1_lost', 1 ] ) {
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
    is( $item->itemlost, 0, 'nothing enacted for a branch whose run date is a holiday' );

    $schema->storage->txn_rollback;
};

subtest 'ProcessOverdues calendar-adjusted path — one branch\'s unusable calendar does not stop the others' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar',   1 );
    t::lib::Mocks::mock_preference( 'useDaysMode',               'Calendar' );
    t::lib::Mocks::mock_preference( 'CircControl',               'PatronLibrary' );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;

    my $today = dt_from_string;
    my %item;
    my %library;

    for my $which (qw( broken healthy )) {
        $library{$which} = $builder->build_object( { class => 'Koha::Libraries' } );
        my $patron = $builder->build_object(
            { class => 'Koha::Patrons', value => { branchcode => $library{$which}->branchcode } } );
        $item{$which} =
            $builder->build_sample_item( { homebranch => $library{$which}->branchcode, replacementprice => 5 } );

        $builder->build_object(
            {
                class => 'Koha::Checkouts',
                value => {
                    borrowernumber => $patron->borrowernumber,
                    itemnumber     => $item{$which}->itemnumber,
                    branchcode     => $library{$which}->branchcode,
                    date_due       => $today->clone->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S'),
                },
            }
        );
    }

    # One global rule set, so both branches resolve the same trigger.
    for my $row ( [ 'overdue_1_delay', 7 ], [ 'overdue_1_lost', 1 ] ) {
        Koha::CirculationRules->set_rule(
            {
                branchcode   => undef,
                categorycode => undef,
                itemtype     => undef,
                rule_name    => $row->[0],
                rule_value   => $row->[1],
            }
        );
    }

    my $broken_branchcode = $library{broken}->branchcode;
    my $calendar_mock     = Test::MockModule->new('Koha::Library::Calendar');
    $calendar_mock->mock(
        'days_backward',
        sub {
            my ( $self, @args ) = @_;
            if ( $self->{branchcode} eq $broken_branchcode ) {
                Koha::Exceptions::Calendar::NoOpenDays->throw('no open day found');
            }
            return $calendar_mock->original('days_backward')->( $self, @args );
        }
    );

    Koha::Overdues::TriggerProcessor->new->ProcessOverdues;

    $item{broken}->discard_changes;
    $item{healthy}->discard_changes;
    is( $item{broken}->itemlost,  0, 'the branch whose calendar throws enacts nothing' );
    is( $item{healthy}->itemlost, 1, 'and every other branch is still processed' );

    $schema->storage->txn_rollback;
};
