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

use Test::More tests => 5;
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

# Get current date for testing
my $dt_now    = dt_from_string();
my $yesterday = $dt_now->clone->subtract( days => 1 );
my $tomorrow  = $dt_now->clone->add( days => 1 );

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
                display_name        => 'my_display_name_for_test_1',
                display_days        => 30,
                display_return_over => 'any',
                start_date          => $yesterday->ymd,
                end_date            => $tomorrow->ymd,
                enabled             => 1,
            }
        }
    );

    # Add item to display
    my $display_item = $builder->build_object(
        {
            class => 'Koha::Display::Items',
            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $item->biblionumber,
                date_added   => $yesterday->ymd,
                date_remove  => $tomorrow->ymd,
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
                display_name        => 'my_display_name_for_test_1',
                display_days        => 30,
                display_return_over => 'any_except_homebranch',
                start_date          => $yesterday->ymd,
                end_date            => $tomorrow->ymd,
                enabled             => 1,
            }
        }
    );

    my $display_item1 = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display1->display_id,
                itemnumber   => $item1->itemnumber,
                biblionumber => $item1->biblionumber,
                date_added   => $yesterday->ymd,
                date_remove  => $tomorrow->ymd,
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
                display_name        => 'my_display_name_for_test_2',
                display_days        => 30,
                display_return_over => 'any_except_homebranch',
                start_date          => $yesterday->ymd,
                end_date            => $tomorrow->ymd,
                enabled             => 1,
            }
        }
    );

    my $display_item2 = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display2->display_id,
                itemnumber   => $item2->itemnumber,
                biblionumber => $item2->biblionumber,
                date_added   => $yesterday->ymd,
                date_remove  => $tomorrow->ymd,
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

subtest 'removal from a display only happens when the check-in is accepted' => sub {
    plan tests => 9;

    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library1->branchcode } } );
    t::lib::Mocks::mock_userenv( { branchcode => $library1->branchcode } );

    my $make = sub {
        my ( $return_over, %display_values ) = @_;
        my $item = $builder->build_sample_item(
            { homebranch => $library1->branchcode, holdingbranch => $library1->branchcode } );
        my $display = $builder->build_object(
            {
                class => 'Koha::Displays',
                value => {
                    display_days        => 30,
                    display_return_over => $return_over,
                    start_date          => $yesterday->ymd,
                    end_date            => $tomorrow->ymd,
                    enabled             => 1,
                    %display_values,
                }
            }
        );
        $builder->build_object(
            {
                class => 'Koha::Display::Items',
                value => {
                    display_id   => $display->display_id,
                    itemnumber   => $item->itemnumber,
                    biblionumber => $item->biblionumber,
                    date_added   => $yesterday->ymd,
                    date_remove  => $tomorrow->ymd,
                }
            }
        );
        return ( $item, $display );
    };

    # A scan of an item that is not checked out is refused: it stays on its display
    my ($not_issued) = $make->('any');
    my ( $doreturn, $messages ) = AddReturn( $not_issued->barcode, $library1->branchcode );
    is( $doreturn, 0, 'The check-in of an item that is not checked out is refused' );
    ok( $not_issued->active_display_item,        'A refused check-in leaves the item on its display' );
    ok( !exists $messages->{RemovedFromDisplay}, 'And does not say it was removed' );

    # 'no' never removes it
    my ($stays) = $make->('no');
    AddIssue( $patron, $stays->barcode );
    ( $doreturn, $messages ) = AddReturn( $stays->barcode, $library1->branchcode );
    is( $doreturn, 1, 'The item is checked in' );
    ok( $stays->active_display_item && !exists $messages->{RemovedFromDisplay}, "'no' leaves the item on its display" );

    # With the module off the display is ignored altogether
    my ($ignored) = $make->('any');
    t::lib::Mocks::mock_preference( 'UseDisplayModule', 0 );
    AddIssue( $patron, $ignored->barcode );
    ( $doreturn, $messages ) = AddReturn( $ignored->barcode, $library1->branchcode );
    t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );
    is( $doreturn, 1, 'The item is checked in' );
    ok( !exists $messages->{RemovedFromDisplay}, 'With the module off nothing is removed from a display' );
    ok( $ignored->active_display_item,           '...and the item is still on its display' );
    is( $ignored->get_from_storage->homebranch, $library1->branchcode, 'The item is unchanged' );
};

subtest 'an item leaving its display goes to its real home library' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranchReturn', 'homebranch' );

    my $home         = $builder->build_object( { class => 'Koha::Libraries' } );
    my $display_home = $builder->build_object( { class => 'Koha::Libraries' } );
    my $elsewhere    = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $elsewhere->branchcode } } );
    t::lib::Mocks::mock_userenv( { branchcode => $elsewhere->branchcode } );

    my $item = $builder->build_sample_item( { homebranch => $home->branchcode, holdingbranch => $home->branchcode } );
    my $display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                display_days        => 30,
                display_return_over => 'any',
                display_home_branch => $display_home->branchcode,
                start_date          => $yesterday->ymd,
                end_date            => $tomorrow->ymd,
                enabled             => 1,
            }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Display::Items',
            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $item->biblionumber,
                date_added   => $yesterday->ymd,
                date_remove  => $tomorrow->ymd,
            }
        }
    );
    is(
        $item->effective_homebranch, $display_home->branchcode,
        'While on display the effective home library is the display\'s'
    );

    AddIssue( $patron, $item->barcode );
    my ( $doreturn, $messages ) = AddReturn( $item->barcode, $elsewhere->branchcode );
    is( $doreturn, 1, 'Checked in' );
    ok( exists $messages->{RemovedFromDisplay}, 'It left its display' );
    my $transfer = $item->get_from_storage->get_transfer;
    is(
        $transfer ? $transfer->tobranch : undef, $home->branchcode,
        'and is sent to its real home library, not the display\'s'
    );
};

$schema->storage->txn_rollback;
