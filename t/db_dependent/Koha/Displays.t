#!/usr/bin/perl

# Copyright 2025-2026 Open Fifth Ltd
#
# This file is part of Koha
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 14;
use Test::MockModule;
use Test::Exception;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::ActionLogs;
use Koha::Display;
use Koha::Display::Item;
use Koha::Displays;

use t::lib::Mocks;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder        = t::lib::TestBuilder->new;
my $nb_of_displays = Koha::Displays->search->count;

# Create a library for testing display_home_branch
my $library = $builder->build( { source => 'Branch' } );

# Create item types for testing
my $itemtype1 = $builder->build( { source => 'Itemtype' } );
my $itemtype2 = $builder->build( { source => 'Itemtype' } );

# Get current date for testing
my $dt_now    = dt_from_string();
my $yesterday = $dt_now->clone->subtract( days => 1 );
my $tomorrow  = $dt_now->clone->add( days => 1 );

# Create displays for testing
my $new_display_1 = Koha::Display->new(
    {
        display_name           => 'my_display_name_for_test_1',
        display_days           => 14,
        display_return_over    => 'no',
        start_date             => $yesterday->ymd,
        end_date               => $tomorrow->ymd,
        enabled                => 1,
        display_location       => 'DISPLAY_LOC_1',
        display_code           => 'DISPLAY_CODE_1',
        display_home_branch    => $library->{branchcode},
        display_holding_branch => $library->{branchcode},
        display_itype          => $itemtype1->{itemtype},
    }
)->store->discard_changes;

my $new_display_2 = Koha::Display->new(
    {
        display_name        => 'my_display_name_for_test_2',
        display_days        => 28,
        start_date          => $yesterday->ymd,
        end_date            => $tomorrow->ymd,
        enabled             => 0,
        display_return_over => 'any',
        display_location    => 'DISPLAY_LOC_2',
        display_code        => 'DISPLAY_CODE_2',
        display_itype       => $itemtype2->{itemtype},
    }
)->store->discard_changes;
$new_display_2->set(
    {
        start_date => $dt_now->ymd,
        end_date   => undef,
    }
)->store->discard_changes;

# Test basic CRUD operations
like( $new_display_1->display_id, qr|^\d+$|, 'Adding a new display should have set the display_id' );
is( Koha::Displays->search->count, $nb_of_displays + 2, 'The 2 displays should have been added' );

my $retrieved_display_1 = Koha::Displays->find( $new_display_1->display_id );
is(
    $retrieved_display_1->display_name, $new_display_1->display_name,
    'Find a display by id should return the correct display'
);

# Test Koha::Display store procedure
subtest 'display store() tests' => sub {
    plan tests => 4;

    # display 1 should have manually set dates
    is( $new_display_1->start_date, $yesterday->ymd, 'Display 1 manually set start_date has stuck' );
    is( $new_display_1->end_date,   $tomorrow->ymd,  'Display 1 manually set end_date has stuck' );

    # display 2 should not have an end date before the start date
    is( $new_display_2->start_date, $dt_now->ymd, 'Display 2 manually set start_date has stuck' );
    is( $new_display_2->end_date,   "2106-02-07", 'Display 2 manually set end_date has changed to be 2106-02-07' );
};

# Test Koha::Display methods
subtest 'display_items method' => sub {
    plan tests => 2;

    my $display_items = $new_display_1->display_items;
    isa_ok( $display_items, 'Koha::Display::Items', 'display_items should return a Koha::Display::Items object' );

    is( $display_items->count, 0, 'New display should have no display items' );
};

subtest 'holding_library method' => sub {
    plan tests => 3;

    my $holding_library_obj = $new_display_1->holding_library;
    isa_ok( $holding_library_obj, 'Koha::Library', 'holding_library should return a Koha::Library object' );
    is( $holding_library_obj->branchcode, $library->{branchcode}, 'holding_library should return the correct library' );

    # Test display without holding_library
    is( $new_display_2->holding_library, undef, 'display without holding_library should return undef' );
};

subtest 'home_library method' => sub {
    plan tests => 3;

    my $home_library_obj = $new_display_1->home_library;
    isa_ok( $home_library_obj, 'Koha::Library', 'home_library should return a Koha::Library object' );
    is( $home_library_obj->branchcode, $library->{branchcode}, 'home_library should return the correct library' );

    # Test display without home_library
    is( $new_display_2->home_library, undef, 'display without home_library should return undef' );
};

# Test Koha::Displays methods
subtest 'enabled method' => sub {
    plan tests => 2;

    my $enabled_displays = Koha::Displays->enabled;
    isa_ok( $enabled_displays, 'Koha::Displays', 'enabled should return a Koha::Displays object' );

    my $found_enabled = 0;
    while ( my $display = $enabled_displays->next ) {
        $found_enabled = 1 if $display->display_id == $new_display_1->display_id;
    }
    ok( $found_enabled, 'enabled displays should include the enabled display' );
};

subtest 'for_branch method' => sub {
    plan tests => 2;

    my $branch_displays = Koha::Displays->for_branch( $library->{branchcode} );
    isa_ok( $branch_displays, 'Koha::Displays', 'for_branch should return a Koha::Displays object' );

    my $found_branch_display = 0;
    while ( my $display = $branch_displays->next ) {
        $found_branch_display = 1 if $display->display_id == $new_display_1->display_id;
    }
    ok( $found_branch_display, 'for_branch should include displays for the specified branch' );
};

subtest 'active method' => sub {
    plan tests => 3;

    my $active_displays = Koha::Displays->active;
    isa_ok( $active_displays, 'Koha::Displays', 'active should return a Koha::Displays object' );

    my $found_active = 0;
    while ( my $display = $active_displays->next ) {
        $found_active = 1 if $display->display_id == $new_display_1->display_id;
    }
    ok( $found_active, 'active displays should include the active display within date range' );

    # Create a display that's not active (dates in the past)
    my $past_end   = $dt_now->clone->subtract( days => 10 );
    my $past_start = $dt_now->clone->subtract( days => 20 );

    my $inactive_display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_name        => 'inactive_display',
                enabled             => 1,
                display_return_over => 'no',
                start_date          => $past_start->ymd,
                end_date            => $past_end->ymd,
            },
        }
    )->store->discard_changes;

    my $active_displays_2 = Koha::Displays->active;
    my $found_inactive    = 0;
    while ( my $display = $active_displays_2->next ) {
        $found_inactive = 1 if $display->display_id == $inactive_display->display_id;
    }
    ok( !$found_inactive, 'active displays should not include displays outside date range' );

    # Clean up the inactive display
    $inactive_display->delete;
};

subtest 'delete() is logged as DELETE' => sub {
    plan tests => 2;

    t::lib::Mocks::mock_preference( 'DisplayItemsLog', 1 );

    my $display = $builder->build_object( { class => 'Koha::Displays', value => { enabled => 1 } } );
    my $id      = $display->display_id;
    $display->delete;

    my $logs = Koha::ActionLogs->search( { module => 'DISPLAYS', object => $id } );
    is( $logs->search( { action => 'DELETE' } )->count,      1, 'Deleting a display logs DELETE' );
    is( $logs->search( { action => 'REMOVE_ITEM' } )->count, 0, 'It is not confused with removing an item' );
};

subtest 'action logging' => sub {
    plan tests => 12;

    my $actions = sub {
        my ( $object, $id ) = @_;
        return [ map { $_->action }
                Koha::ActionLogs->search( { module => 'DISPLAYS', object => $id }, { order_by => 'action_id' } )
                ->as_list ];
    };

    t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );
    t::lib::Mocks::mock_preference( 'DisplayItemsLog',  1 );

    my $display = Koha::Display->new(
        {
            display_name        => 'Logged',
            display_days        => 7,
            start_date          => $yesterday->ymd,
            display_return_over => 'no',
            enabled             => 1,
        }
    )->store;
    my $id = $display->display_id;
    is_deeply( $actions->( $display, $id ), ['CREATE'], 'Creating is logged' );

    $display->store;
    is_deeply( $actions->( $display, $id ), ['CREATE'], 'Saving without a change logs nothing' );

    $display->display_name('Renamed')->store;
    is_deeply( $actions->( $display, $id ), [ 'CREATE', 'MODIFY' ], 'Modifying is logged' );

    $display->enabled(0)->store;
    is_deeply(
        $actions->( $display, $id ), [ 'CREATE', 'MODIFY', 'DISABLED' ],
        'Disabling is logged as DISABLED only'
    );

    $display->enabled(1)->store;
    is_deeply(
        $actions->( $display, $id ), [ 'CREATE', 'MODIFY', 'DISABLED', 'ENABLED' ],
        'Enabling is logged as ENABLED only'
    );

    $display->enabled(0)->display_name('Both')->store;
    is_deeply(
        $actions->( $display, $id ), [ 'CREATE', 'MODIFY', 'DISABLED', 'ENABLED', 'DISABLED', 'MODIFY' ],
        'A change to both is logged as both'
    );

    # Display items
    my $item         = $builder->build_sample_item;
    my $display_item = Koha::Display::Item->new(
        {
            display_id   => $id,
            itemnumber   => $item->itemnumber,
            biblionumber => $item->biblionumber,
            date_added   => $yesterday->ymd,
            date_remove  => $tomorrow->ymd,
        }
    )->store;
    my $di_id = $display_item->display_item_id;
    $display_item->date_remove( $tomorrow->clone->add( days => 1 )->ymd )->store;
    $display_item->delete;
    is_deeply(
        $actions->( $display_item, $di_id ), [ 'ADD_ITEM', 'MODIFY_ITEM', 'REMOVE_ITEM' ],
        'Display item actions are logged'
    );

    # A delete that fails is not logged
    my $other = Koha::Display->new(
        {
            display_name => 'Unlogged', display_days => 7, start_date => $yesterday->ymd, display_return_over => 'no',
            enabled      => 1
        }
    )->store;
    my $other_id = $other->display_id;
    {
        my $mock = Test::MockModule->new('Koha::Object');
        $mock->mock( delete => sub { die "cannot delete\n" } );
        eval { $other->delete };
    }
    is_deeply( $actions->( $other, $other_id ), ['CREATE'], 'A failed delete is not logged' );

    # With the log disabled nothing is written
    t::lib::Mocks::mock_preference( 'DisplayItemsLog', 0 );
    my $quiet = Koha::Display->new(
        {
            display_name => 'Quiet', display_days => 7, start_date => $yesterday->ymd, display_return_over => 'no',
            enabled      => 1
        }
    )->store;
    $quiet->display_name('Still quiet')->store;
    $quiet->enabled(0)->store;
    my $quiet_id = $quiet->display_id;
    $quiet->delete;
    is_deeply( $actions->( $quiet, $quiet_id ), [], 'Nothing is logged with DisplayItemsLog off' );

    throws_ok { Koha::Display->new( { display_name => 'Incomplete' } )->store } 'Koha::Exceptions::BadParameter',
        'A display missing required attributes is refused';
    throws_ok {
        Koha::Display->new(
            { display_name => 'x', display_days => 1, start_date => $yesterday->ymd, display_return_over => 'no' } )
            ->store
    }
    'Koha::Exceptions::BadParameter', 'A display with no enabled flag is refused';
    is( Koha::Display::DISTANT_DATE, '2106-02-07', 'The no-end date is a named constant' );

    # Leave the shared counts as we found them
    $display->delete;
    $other->delete;
};

# Test delete
$retrieved_display_1->delete;
is( Koha::Displays->search->count, $nb_of_displays + 1, 'Delete should have deleted the display' );

$schema->storage->txn_rollback;
