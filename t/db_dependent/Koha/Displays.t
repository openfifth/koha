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
use Test::More tests => 12;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Displays;

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
my $itemtype3 = $builder->build( { source => 'Itemtype' } );
my $itemtype4 = $builder->build( { source => 'Itemtype' } );

# Get current date for testing
my $dt_now    = dt_from_string();
my $yesterday = $dt_now->clone->subtract( days => 1 );
my $tomorrow  = $dt_now->clone->add( days => 1 );

# Create displays for testing
my $new_display_1 = Koha::Display->new(
    {
        display_name           => 'my_display_name_for_test_1',
        enabled                => 1,
        display_return_over    => 'no',
        start_date             => $yesterday->ymd,
        end_date               => $tomorrow->ymd,
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
        enabled             => 0,
        display_return_over => 'any',
        display_location    => 'DISPLAY_LOC_2',
        display_code        => 'DISPLAY_CODE_2',
        display_itype       => $itemtype2->{itemtype},
    }
)->store->discard_changes;

my $new_display_3 = Koha::Display->new(
    {
        display_name        => 'my_display_name_for_test_3',
        enabled             => 1,
        display_return_over => 'any',
        display_days        => 28,
        display_location    => 'DISPLAY_LOC_3',
        display_code        => 'DISPLAY_CODE_3',
        display_itype       => $itemtype3->{itemtype},
    }
)->store->discard_changes;

my $new_display_4 = Koha::Display->new(
    {
        display_name        => 'my_display_name_for_test_4',
        enabled             => 1,
        display_return_over => 'any',
        display_location    => 'DISPLAY_LOC_4',
        display_code        => 'DISPLAY_CODE_4',
        display_itype       => $itemtype4->{itemtype},
    }
)->store->discard_changes;
$new_display_4->set(
    {
        start_date   => undef,
        end_date     => undef,
        display_days => undef,
    }
)->store->discard_changes;

# Test basic CRUD operations
like( $new_display_1->display_id, qr|^\d+$|, 'Adding a new display should have set the display_id' );
is( Koha::Displays->search->count, $nb_of_displays + 4, 'The 4 displays should have been added' );

my $retrieved_display_1 = Koha::Displays->find( $new_display_1->display_id );
is(
    $retrieved_display_1->display_name, $new_display_1->display_name,
    'Find a display by id should return the correct display'
);

# Test Koha::Display store procedure
subtest 'display store() tests' => sub {
    plan tests => 9;

    # display 1 should have manually set dates
    is( $new_display_1->start_date, $yesterday->ymd, 'Display 1 manually set start_date has stuck' );
    is( $new_display_1->end_date,   $tomorrow->ymd,  'Display 1 manually set end_date has stuck' );

    my $dt_now_plus_14 = $dt_now->clone->add( days => 14 );

    # display 2 should not autocalculate dates when in_storage
    is( $new_display_2->start_date, $dt_now->ymd,         'Display 2 has no start_date defined' );
    is( $new_display_2->end_date,   $dt_now_plus_14->ymd, 'Display 2 has no end_date defined' );

    my $dt_now_plus_28 = $dt_now->clone->add( days => 28 );

    # display 3 should have correct autocalculated dates based on display_days
    is( $new_display_3->start_date, $dt_now->ymd,         'Display 3 has autocalculated start_date to today' );
    is( $new_display_3->end_date,   $dt_now_plus_28->ymd, 'Display 3 has autocalculated end_date to today plus 28' );

    # display 4 should have kept unset dates and display days
    is( $new_display_4->start_date,   undef, 'Display 4 has kept undef start_date' );
    is( $new_display_4->end_date,     undef, 'Display 4 has kept undef start_date' );
    is( $new_display_4->display_days, undef, 'Display 4 has kept undef start_date' );
};

# Test Koha::Display methods
subtest 'display_items method' => sub {
    plan tests => 2;

    my $display_items = $new_display_1->display_items;
    isa_ok( $display_items, 'Koha::DisplayItems', 'display_items should return a Koha::DisplayItems object' );
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

# Test delete
$retrieved_display_1->delete;
is( Koha::Displays->search->count, $nb_of_displays + 3, 'Delete should have deleted the display' );

$schema->storage->txn_rollback;
