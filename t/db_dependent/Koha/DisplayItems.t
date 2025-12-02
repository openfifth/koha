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

use C4::Context;
use Koha::DateUtils qw( dt_from_string );
use Koha::DisplayItems;
use Koha::Database;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder             = t::lib::TestBuilder->new;
my $nb_of_display_items = Koha::DisplayItems->search->count;

# Create test data
my $library = $builder->build( { source => 'Branch' } );
my $biblio  = $builder->build( { source => 'Biblio' } );
my $item1   = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );
my $item2   = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );

my $display = $builder->build( { source => 'Display', value => { display_home_branch => $library->{branchcode} } } );

# Create display items for testing
my $new_display_item_1 = Koha::DisplayItem->new(
    {
        display_id   => $display->{display_id},
        itemnumber   => $item1->{itemnumber},
        biblionumber => $biblio->{biblionumber},
        date_added   => '2024-01-01',
        date_remove  => '2024-12-31',
    }
)->store->discard_changes;

my $new_display_item_2 = Koha::DisplayItem->new(
    {
        display_id   => $display->{display_id},
        itemnumber   => $item2->{itemnumber},
        biblionumber => $biblio->{biblionumber},
        date_added   => '2024-02-01',
        date_remove  => '2024-11-30',
    }
)->store->discard_changes;

# Test basic CRUD operations
like( $new_display_item_1->display_id, qr|^\d+$|, 'Adding a new display item should have set the display_id' );
is( Koha::DisplayItems->search->count, $nb_of_display_items + 2, 'The 2 display items should have been added' );

my $retrieved_display_item_1 = Koha::DisplayItems->find(
    {
        display_id => $new_display_item_1->display_id,
        itemnumber => $new_display_item_1->itemnumber
    }
);
is(
    $retrieved_display_item_1->biblionumber, $new_display_item_1->biblionumber,
    'Find a display item by composite key should return the correct display item'
);

# Test Koha::DisplayItem methods
subtest 'display method' => sub {
    plan tests => 2;

    my $display_obj = $new_display_item_1->display;
    isa_ok( $display_obj, 'Koha::Display', 'display should return a Koha::Display object' );
    is( $display_obj->display_id, $display->{display_id}, 'display should return the correct display' );
};

subtest 'item method' => sub {
    plan tests => 2;

    my $item_obj = $new_display_item_1->item;
    isa_ok( $item_obj, 'Koha::Item', 'item should return a Koha::Item object' );
    is( $item_obj->itemnumber, $item1->{itemnumber}, 'item should return the correct item' );
};

subtest 'biblio method' => sub {
    plan tests => 2;

    my $biblio_obj = $new_display_item_1->biblio;
    isa_ok( $biblio_obj, 'Koha::Biblio', 'biblio should return a Koha::Biblio object' );
    is( $biblio_obj->biblionumber, $biblio->{biblionumber}, 'biblio should return the correct biblio' );
};

# Test Koha::DisplayItems methods
subtest 'for_display method' => sub {
    plan tests => 2;

    my $display_items = Koha::DisplayItems->for_display( $display->{display_id} );
    isa_ok( $display_items, 'Koha::DisplayItems', 'for_display should return a Koha::DisplayItems object' );
    is( $display_items->count, 2, 'for_display should return the correct number of display items' );
};

subtest 'for_item method' => sub {
    plan tests => 2;

    my $display_items = Koha::DisplayItems->for_item( $item1->{itemnumber} );
    isa_ok( $display_items, 'Koha::DisplayItems', 'for_item should return a Koha::DisplayItems object' );
    is( $display_items->count, 1, 'for_item should return the correct number of display items' );
};

subtest 'for_biblio method' => sub {
    plan tests => 2;

    my $display_items = Koha::DisplayItems->for_biblio( $biblio->{biblionumber} );
    isa_ok( $display_items, 'Koha::DisplayItems', 'for_biblio should return a Koha::DisplayItems object' );
    is( $display_items->count, 2, 'for_biblio should return the correct number of display items' );
};

subtest 'due_for_removal method' => sub {
    plan tests => 3;

    # Create a display item that should be removed today
    my $dt_now         = dt_from_string();
    my $item_to_remove = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );

    my $display_item_due = $builder->build_object(
        {
            class => 'Koha::DisplayItems',
            value => {
                display_id   => $display->{display_id},
                itemnumber   => $item_to_remove->{itemnumber},
                biblionumber => $biblio->{biblionumber},
                date_added   => '2024-01-01',
                date_remove  => $dt_now->ymd,
            },
        }
    )->store->discard_changes;

    my $due_items = Koha::DisplayItems->due_for_removal;
    isa_ok( $due_items, 'Koha::DisplayItems', 'due_for_removal should return a Koha::DisplayItems object' );

    my $found_due_item = 0;
    while ( my $item = $due_items->next ) {
        $found_due_item = 1 if $item->itemnumber == $item_to_remove->{itemnumber};
    }
    ok( $found_due_item, 'due_for_removal should include items due for removal today' );

    # Create a display item that should be removed in the future
    my $future_date = dt_from_string()->add( days => 30 )->ymd;
    my $item_future = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );

    my $display_item_future = $builder->build_object(
        {
            class => 'Koha::DisplayItems',
            value => {
                display_id   => $display->{display_id},
                itemnumber   => $item_future->{itemnumber},
                biblionumber => $biblio->{biblionumber},
                date_added   => '2024-01-01',
                date_remove  => $future_date,
            },
        }
    )->store->discard_changes;

    my $due_items_2       = Koha::DisplayItems->due_for_removal;
    my $found_future_item = 0;
    while ( my $item = $due_items_2->next ) {
        $found_future_item = 1 if $item->itemnumber == $item_future->{itemnumber};
    }
    ok( !$found_future_item, 'due_for_removal should not include items due for removal in the future' );

    # Clean up the additional display items
    $display_item_due->delete;
    $display_item_future->delete;
};

# Test delete
$retrieved_display_item_1->delete;
is( Koha::DisplayItems->search->count, $nb_of_display_items + 1, 'Delete should have deleted the display item' );

$schema->storage->txn_rollback;
