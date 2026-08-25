#!/usr/bin/env perl

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

use Test::More tests => 8;
use Test::NoWarnings;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::CirculationRules;
use Koha::Database;
use Koha::Item::Availability::Hold;
use Koha::Libraries;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $password = 'thePassword123';

# build_staff_user
#
#     my $userid = build_staff_user();
#
# Builds a staff user that holds the reserveforothers > place_holds permission,
# which is the permission that this endpoint needs.

sub build_staff_user {

    my $staff = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $staff->borrowernumber,
                module_bit     => 6,
                code           => 'place_holds',
            },
        }
    );

    $staff->set_password( { password => $password, skip_validation => 1 } );

    return $staff->userid;
}

# allow_holds
#
#     allow_holds();
#
# Sets a permissive default circulation rule, so that a test only has to set up
# the condition that it is actually about.

sub allow_holds {

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => {
                reservesallowed  => 10,
                holds_per_record => 10,
            }
        }
    );

    return;
}

subtest 'A holdable item' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available'          => Mojo::JSON->true )
        ->json_is( '/needs_confirmation' => Mojo::JSON->false )
        ->json_is( '/blockers'           => [] )
        ->json_hasnt( '/pickup_locations', 'No pickup locations without include_pickup_locations' );

    $schema->storage->txn_rollback;
};

subtest 'A damaged item, and the damaged override' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode, damaged => 1 } );

    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available' => Mojo::JSON->false )
        ->json_is( '/blockers'  => [ { code => 'damaged', overridable => Mojo::JSON->true } ] );

    $t->get_ok( "//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id" =>
            { 'x-koha-override' => 'damaged' } )->json_is( '/available' => Mojo::JSON->true );

    $schema->storage->txn_rollback;
};

subtest 'An item the patron already has on hold' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                itemnumber     => $item->itemnumber,
                borrowernumber => $patron->borrowernumber,
                biblionumber   => $item->biblionumber,
            }
        }
    );

    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available' => Mojo::JSON->false )
        ->json_is( '/blockers'  => [ { code => 'item_already_on_hold', overridable => Mojo::JSON->false } ] );

    $schema->storage->txn_rollback;
};

subtest 'A pickup library with a transfer limit' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'UseBranchTransferLimits',  1 );
    t::lib::Mocks::mock_preference( 'BranchTransferLimitsType', 'itemtype' );

    my $userid    = build_staff_user();
    my $library   = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $pickup    = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $no_hold   = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 0 } } );
    my $patron    = $builder->build_object( { class => 'Koha::Patrons',   value => { branchcode => $library->id } } );
    my $item      = $builder->build_sample_item( { library => $library->branchcode } );
    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    # No limit yet, so the pickup library is fine
    $t->get_ok(
        "//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id&pickup_library_id=" . $pickup->id )
        ->status_is(200)
        ->json_is( '/available' => Mojo::JSON->true );

    $builder->build_object(
        {
            class => 'Koha::Item::Transfer::Limits',
            value => {
                toBranch   => $pickup->branchcode,
                fromBranch => $item->holdingbranch,
                itemtype   => $item->effective_itemtype,
                ccode      => undef,
            }
        }
    );

    $t->get_ok(
        "//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id&pickup_library_id=" . $pickup->id )
        ->json_is( '/blockers' => [ { code => 'cannot_be_transferred', overridable => Mojo::JSON->false } ] );

    # A library that is not flagged as a pickup location at all
    $t->get_ok( "//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id&pickup_library_id="
            . $no_hold->id )
        ->json_is( '/blockers' => [ { code => 'library_not_pickup_location', overridable => Mojo::JSON->false } ] );

    $schema->storage->txn_rollback;
};

subtest 'include_pickup_locations' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldPolicyOverride', 0 );

    my $userid = build_staff_user();

    # Ease the assertion below by leaving exactly one pickup location
    Koha::Libraries->search->update( { pickup_location => 0 } );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id&include_pickup_locations=1")
        ->status_is(200)
        ->json_is( '/available'                         => Mojo::JSON->true )
        ->json_is( '/pickup_locations/0/library_id'     => $library->branchcode )
        ->json_is( '/pickup_locations/0/needs_override' => Mojo::JSON->false );

    $schema->storage->txn_rollback;
};

subtest 'The verdict matches the availability class' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode, damaged => 1 } );

    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    my $response =
        $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->tx->res->json;

    my $expected = Koha::Item::Availability::Hold->check(
        {
            item             => $item,
            patron           => $patron,
            no_short_circuit => 1,
        }
    )->to_api;

    is_deeply( $response, $expected, 'The endpoint returns exactly what the availability class reports' );

    $schema->storage->txn_rollback;
};

subtest 'Error cases' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    my $item_id   = $item->itemnumber;
    my $patron_id = $patron->borrowernumber;

    # Unknown item
    my $deleted_item    = $builder->build_sample_item( { library => $library->branchcode } );
    my $deleted_item_id = $deleted_item->itemnumber;
    $deleted_item->delete;

    $t->get_ok("//$userid:$password@/api/v1/items/$deleted_item_id/holdability?patron_id=$patron_id")
        ->status_is( 404, 'An unknown item gives a 404' );

    # Unknown patron
    my $deleted_patron    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $deleted_patron_id = $deleted_patron->borrowernumber;
    $deleted_patron->delete;

    $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$deleted_patron_id")
        ->status_is( 400, 'An unknown patron gives a 400' )
        ->json_is( '/error_code' => 'patron_not_found' );

    # Unknown pickup library
    $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id&pickup_library_id=nope")
        ->json_is( '/error_code' => 'library_not_found' );

    # A user without the reserveforothers > place_holds permission
    my $unauthorised = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $unauthorised->set_password( { password => $password, skip_validation => 1 } );
    my $unauthorised_userid = $unauthorised->userid;

    $t->get_ok("//$unauthorised_userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id")
        ->status_is( 403, 'A user without place_holds gives a 403' );

    $schema->storage->txn_rollback;
};
