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

use C4::Context;
use Koha::DateUtils qw( dt_from_string );
use Koha::Displays;
use Koha::Display::Items;
use Koha::Database;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder             = t::lib::TestBuilder->new;
my $nb_of_display_items = Koha::Display::Items->search->count;

# Get current date for testing
my $dt_now    = dt_from_string();
my $yesterday = $dt_now->clone->subtract( days => 1 );
my $tomorrow  = $dt_now->clone->add( days => 1 );

# Create test data
my $library = $builder->build( { source => 'Branch' } );
my $biblio  = $builder->build( { source => 'Biblio' } );
my $item1   = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );
my $item2   = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );

my $new_display_1 = Koha::Display->new(
    {
        display_name        => 'my_display_name_for_test_1',
        display_days        => 28,
        display_return_over => 'any',
        start_date          => $yesterday->ymd,
        end_date            => $tomorrow->ymd,
        enabled             => 1
    }
)->store->discard_changes;

# Create display items for testing
my $new_display_item_1 = Koha::Display::Item->new(
    {
        display_id   => $new_display_1->display_id,
        itemnumber   => $item1->{itemnumber},
        biblionumber => $biblio->{biblionumber},
        date_added   => $yesterday->ymd,
        date_remove  => $tomorrow->ymd,
    }
)->store->discard_changes;

my $new_display_item_2 = Koha::Display::Item->new(
    {
        display_id   => $new_display_1->display_id,
        itemnumber   => $item2->{itemnumber},
        biblionumber => $biblio->{biblionumber},
        date_added   => '2024-02-01',
        date_remove  => '2024-11-30',
    }
)->store->discard_changes;

# Test basic CRUD operations
like( $new_display_item_1->display_id, qr|^\d+$|, 'Adding a new display item should have set the display_id' );
is( Koha::Display::Items->search->count, $nb_of_display_items + 2, 'The 2 display items should have been added' );

my $retrieved_display_item_1 = Koha::Display::Items->find(
    {
        display_id => $new_display_item_1->display_id,
        itemnumber => $new_display_item_1->itemnumber
    }
);
is(
    $retrieved_display_item_1->biblionumber, $new_display_item_1->biblionumber,
    'Find a display item by composite key should return the correct display item'
);

# Test Koha::Display::Item methods
subtest 'active method' => sub {
    plan tests => 2;

    is( $new_display_item_1->active, 1,     'active should be true for display item #1' );
    is( $new_display_item_2->active, undef, 'active should be false for display item #2' );
};

subtest 'active_display method' => sub {
    plan tests => 2;
    my $new_active_display_1 = $new_display_item_1->active_display;

    isa_ok( $new_active_display_1, 'Koha::Display', 'active_display should be a display for display item #1' );
    is( $new_display_item_2->active_display, undef, 'active_display should be undef for display item #2' );
};

subtest 'display method' => sub {
    plan tests => 2;

    my $new_display_1_obj = $new_display_item_1->display;
    isa_ok( $new_display_1_obj, 'Koha::Display', 'display should return a Koha::Display object' );
    is( $new_display_1_obj->display_id, $new_display_1->display_id, 'display should return the correct display' );
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

# Test Koha::Display::Items methods
subtest 'for_display method' => sub {
    plan tests => 2;

    my $new_display_1_items = Koha::Display::Items->for_display( $new_display_1->display_id );
    isa_ok( $new_display_1_items, 'Koha::Display::Items', 'for_display should return a Koha::Display::Items object' );
    is( $new_display_1_items->count, 2, 'for_display should return the correct number of display items' );
};

subtest 'for_item method' => sub {
    plan tests => 2;

    my $new_display_1_items = Koha::Display::Items->for_item( $item1->{itemnumber} );
    isa_ok( $new_display_1_items, 'Koha::Display::Items', 'for_item should return a Koha::Display::Items object' );
    is( $new_display_1_items->count, 1, 'for_item should return the correct number of display items' );
};

subtest 'for_biblio method' => sub {
    plan tests => 2;

    my $new_display_1_items = Koha::Display::Items->for_biblio( $biblio->{biblionumber} );
    isa_ok( $new_display_1_items, 'Koha::Display::Items', 'for_biblio should return a Koha::Display::Items object' );
    is( $new_display_1_items->count, 2, 'for_biblio should return the correct number of display items' );
};

subtest 'due_for_removal method' => sub {
    plan tests => 3;

    # Create a display item that should be removed today
    my $dt_now         = dt_from_string();
    my $item_to_remove = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );

    my $new_display_1_item_due = $builder->build_object(
        {
            class => 'Koha::Display::Items',
            value => {
                display_id   => $new_display_1->display_id,
                itemnumber   => $item_to_remove->{itemnumber},
                biblionumber => $biblio->{biblionumber},
                date_added   => '2024-01-01',
                date_remove  => $dt_now->ymd,
            },
        }
    )->store->discard_changes;

    my $due_items = Koha::Display::Items->due_for_removal;
    isa_ok( $due_items, 'Koha::Display::Items', 'due_for_removal should return a Koha::Display::Items object' );

    my $found_due_item = 0;
    while ( my $item = $due_items->next ) {
        $found_due_item = 1 if $item->itemnumber == $item_to_remove->{itemnumber};
    }
    ok( $found_due_item, 'due_for_removal should include items due for removal today' );

    # Create a display item that should be removed in the future
    my $future_date = dt_from_string()->add( days => 30 )->ymd;
    my $item_future = $builder->build( { source => 'Item', value => { biblionumber => $biblio->{biblionumber} } } );

    my $new_display_1_item_future = $builder->build_object(
        {
            class => 'Koha::Display::Items',
            value => {
                display_id   => $new_display_1->display_id,
                itemnumber   => $item_future->{itemnumber},
                biblionumber => $biblio->{biblionumber},
                date_added   => '2024-01-01',
                date_remove  => $future_date,
            },
        }
    )->store->discard_changes;

    my $due_items_2       = Koha::Display::Items->due_for_removal;
    my $found_future_item = 0;
    while ( my $item = $due_items_2->next ) {
        $found_future_item = 1 if $item->itemnumber == $item_future->{itemnumber};
    }
    ok( !$found_future_item, 'due_for_removal should not include items due for removal in the future' );

    # Clean up the additional display items
    $new_display_1_item_due->delete;
    $new_display_1_item_future->delete;
};

# Test delete
$retrieved_display_item_1->delete;
is( Koha::Display::Items->search->count, $nb_of_display_items + 1, 'Delete should have deleted the display item' );

$schema->storage->txn_rollback;
