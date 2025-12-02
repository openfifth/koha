#!/usr/bin/perl

# Copyright 2025-2026 Open Fifth Ltd
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 3;
use Test::NoWarnings;

use C4::Circulation qw( AddIssue AddReturn );
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );

subtest 'display_return_over - any' => sub {
    plan tests => 6;

    # Create test data
    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode } } );
    my $item =
        $builder->build_sample_item( { homebranch => $library1->branchcode, holdingbranch => $library2->branchcode } );

    # Mock userenv
    t::lib::Mocks::mock_userenv( { branchcode => $library1->branchcode } );

    # Create a display with 'any' return_over setting
    my $display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_return_over => 'any',
                enabled             => 1,
                start_date          => undef,
                end_date            => undef,
            }
        }
    );

    # Add item to display
    my $display_item = $builder->build_object(
        {
            class => 'Koha::DisplayItems',
            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $item->biblionumber,
                date_added   => undef,
                date_remove  => undef,
            }
        }
    );

    # Verify item is in display and is active
    ok( $display_item->active, 'Display item should be active' );
    my $active_display = $item->active_display_item;
    ok( defined $active_display, 'Item should have an active display item' );
    is( $active_display->display_id, $display->display_id, 'Display item should be linked to the correct display' );

    # Issue the item
    AddIssue( $patron, $item->barcode );

    # Return the item at the home library
    my ( $doreturn, $messages, $issue, $borrower ) = AddReturn( $item->barcode, $library1->branchcode );
    is( $doreturn, 1, 'Item should be returned successfully' );
    ok( exists $messages->{RemovedFromDisplay}, 'RemovedFromDisplay message should be present' );

    # Verify item was removed from display
    $active_display = $item->active_display_item;
    is( $active_display, undef, 'Item should no longer have an active display item after return' );
};

subtest 'display_return_over - any_except_homebranch' => sub {
    plan tests => 11;

    # Create test data
    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library3 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode } } );

    # Mock userenv
    t::lib::Mocks::mock_userenv( { branchcode => $library1->branchcode } );

    # Test 1: Return at non-home library should remove from display
    my $item1 =
        $builder->build_sample_item( { homebranch => $library1->branchcode, holdingbranch => $library2->branchcode } );

    my $display1 = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_return_over => 'any_except_homebranch',
                enabled             => 1,
                start_date          => undef,
                end_date            => undef,
            }
        }
    );

    my $display_item1 = $builder->build_object(
        {
            class => 'Koha::DisplayItems',
            value => {
                display_id   => $display1->display_id,
                itemnumber   => $item1->itemnumber,
                biblionumber => $item1->biblionumber,
                date_added   => undef,
                date_remove  => undef,
            }
        }
    );

    ok( $display_item1->active, 'Display item should be active' );
    my $active_display1 = $item1->active_display_item;
    ok( defined $active_display1, 'Item should have an active display item' );

    AddIssue( $patron, $item1->barcode );
    my ( $doreturn, $messages, $issue, $borrower ) = AddReturn( $item1->barcode, $library3->branchcode );

    is( $doreturn, 1, 'Item should be returned successfully at non-home library' );
    ok(
        exists $messages->{RemovedFromDisplay},
        'RemovedFromDisplay message should be present when returned at non-home library'
    );

    $active_display1 = $item1->active_display_item;
    is( $active_display1, undef, 'Item should be removed from display when returned at non-home library' );

    # Test 2: Return at home library should NOT remove from display
    my $item2 =
        $builder->build_sample_item( { homebranch => $library1->branchcode, holdingbranch => $library2->branchcode } );

    my $display2 = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_return_over => 'any_except_homebranch',
                enabled             => 1,
                start_date          => undef,
                end_date            => undef,
            }
        }
    );

    my $display_item2 = $builder->build_object(
        {
            class => 'Koha::DisplayItems',
            value => {
                display_id   => $display2->display_id,
                itemnumber   => $item2->itemnumber,
                biblionumber => $item2->biblionumber,
                date_added   => undef,
                date_remove  => undef,
            }
        }
    );

    ok( $display_item2->active, 'Display item should be active' );
    my $active_display2 = $item2->active_display_item;
    ok( defined $active_display2, 'Item should have an active display item before return' );

    AddIssue( $patron, $item2->barcode );
    ( $doreturn, $messages, $issue, $borrower ) = AddReturn( $item2->barcode, $library1->branchcode );

    is( $doreturn, 1, 'Item should be returned successfully at home library' );
    ok(
        !exists $messages->{RemovedFromDisplay},
        'RemovedFromDisplay message should NOT be present when returned at home library'
    );

    $active_display2 = $item2->active_display_item;
    ok( defined $active_display2, 'Item should still have an active display item when returned at home library' );
    is(
        $active_display2->display_id, $display2->display_id,
        'Display item should still be linked to the correct display'
    );

    # Clean up
    $display_item2->delete;
};

$schema->storage->txn_rollback;
