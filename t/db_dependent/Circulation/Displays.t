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

subtest 'display_return_over - yes - any library' => sub {
    plan tests => 5;

    # Create test data
    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode } } );
    my $item =
        $builder->build_sample_item( { homebranch => $library1->branchcode, holdingbranch => $library1->branchcode } );

    # Mock userenv
    t::lib::Mocks::mock_userenv( { branchcode => $library1->branchcode } );

    # Create a display with 'yes - any library' return_over setting
    my $display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_return_over => 'yes - any library',
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
            }
        }
    );

    # Verify item is in display
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

subtest 'display_return_over - yes - except at home library' => sub {
    plan tests => 9;

    # Create test data
    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode } } );

    # Mock userenv
    t::lib::Mocks::mock_userenv( { branchcode => $library1->branchcode } );

    # Test 1: Return at non-home library should remove from display
    my $item1 =
        $builder->build_sample_item( { homebranch => $library1->branchcode, holdingbranch => $library1->branchcode } );

    my $display1 = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_return_over => 'yes - except at home library',
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
            }
        }
    );

    my $active_display = $item1->active_display_item;
    ok( defined $active_display, 'Item should have an active display item' );

    AddIssue( $patron, $item1->barcode );
    my ( $doreturn, $messages, $issue, $borrower ) = AddReturn( $item1->barcode, $library2->branchcode );

    is( $doreturn, 1, 'Item should be returned successfully at non-home library' );
    ok(
        exists $messages->{RemovedFromDisplay},
        'RemovedFromDisplay message should be present when returned at non-home library'
    );

    $active_display = $item1->active_display_item;
    is( $active_display, undef, 'Item should be removed from display when returned at non-home library' );

    # Test 2: Return at home library should NOT remove from display
    my $item2 =
        $builder->build_sample_item( { homebranch => $library1->branchcode, holdingbranch => $library1->branchcode } );

    my $display2 = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_return_over => 'yes - except at home library',
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
            }
        }
    );

    $active_display = $item2->active_display_item;
    ok( defined $active_display, 'Item should have an active display item before return' );

    AddIssue( $patron, $item2->barcode );
    ( $doreturn, $messages, $issue, $borrower ) = AddReturn( $item2->barcode, $library1->branchcode );

    is( $doreturn, 1, 'Item should be returned successfully at home library' );
    ok(
        !exists $messages->{RemovedFromDisplay},
        'RemovedFromDisplay message should NOT be present when returned at home library'
    );

    $active_display = $item2->active_display_item;
    ok( defined $active_display, 'Item should still have an active display item when returned at home library' );
    is(
        $active_display->display_id, $display2->display_id,
        'Display item should still be linked to the correct display'
    );

    # Clean up
    $display_item2->delete;
};

$schema->storage->txn_rollback;
