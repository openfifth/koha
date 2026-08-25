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

use Koha::Biblio::Availability::Hold;
use Koha::CirculationRules;
use Koha::Database;
use Koha::Patron::Debarments qw( AddDebarment );

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
# the condition that it is actually about. holds_per_record defaults to 1, which
# would otherwise block a patron before the item loop runs.

sub allow_holds {

    t::lib::Mocks::mock_preference( 'maxreserves',    0 );
    t::lib::Mocks::mock_preference( 'maxoutstanding', 0 );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => {
                reservesallowed  => 100,
                holds_per_record => 100,
            }
        }
    );

    return;
}

subtest 'A record with a holdable item' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    # Two damaged, one good
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );
    my $good = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 0, library => $library->branchcode } );
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available'                    => Mojo::JSON->true )
        ->json_is( '/needs_confirmation'           => Mojo::JSON->false )
        ->json_is( '/blockers'                     => [] )
        ->json_is( '/items/total'                  => 3 )
        ->json_is( '/items/holdable'               => 1 )
        ->json_is( '/items/first_holdable_item_id' => $good->itemnumber )
        ->json_is( '/hold_fee'                     => 0 )
        ->json_is( '/prospective_priority'         => 1 );

    $schema->storage->txn_rollback;
};

subtest 'A record whose items are all blocked' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available'      => Mojo::JSON->false )
        ->json_is( '/blockers'       => [ { code => 'no_item_available', overridable => Mojo::JSON->false } ] )
        ->json_is( '/items/holdable' => 0 )
        ->json_is( '/items/first_holdable_item_id' => undef )
        ->json_is( '/hold_fee'                     => undef );

    $schema->storage->txn_rollback;
};

subtest 'A record with no items' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid = build_staff_user();
    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $biblio = $builder->build_sample_biblio;

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available'   => Mojo::JSON->false )
        ->json_is( '/blockers'    => [ { code => 'no_items', overridable => Mojo::JSON->false } ] )
        ->json_is( '/items/total' => 0 );

    $schema->storage->txn_rollback;
};

subtest 'A patron-level blocker still reports the item counts' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );
    $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    AddDebarment( { borrowernumber => $patron_id, type => 'MANUAL' } );

    # The endpoint asks for every blocker, so a patron-level blocker does not
    # stop the item loop. The record's items are still reported, which lets a
    # screen say "this patron cannot place holds, but the record has 2 holdable
    # items" rather than showing nothing.
    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->json_is( '/available'      => Mojo::JSON->false )
        ->json_is( '/blockers'       => [ { code => 'restricted', overridable => Mojo::JSON->true } ] )
        ->json_is( '/items/total'    => 2 )
        ->json_is( '/items/holdable' => 2 );

    $t->get_ok( "//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id" =>
            { 'x-koha-override' => 'restricted' } )->json_is( '/available' => Mojo::JSON->true );

    $schema->storage->txn_rollback;
};

subtest 'item_type_id limits the item check' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    my $wanted    = $builder->build_object( { class => 'Koha::ItemTypes' } );
    my $unwanted  = $builder->build_object( { class => 'Koha::ItemTypes' } );
    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, itype => $wanted->itemtype } );
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, itype => $unwanted->itemtype } );
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, itype => $unwanted->itemtype } );

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->json_is( '/items/total' => 3, 'Every item without the filter' );

    $t->get_ok( "//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id&item_type_id="
            . $wanted->itemtype )
        ->status_is(200)
        ->json_is( '/items/total'    => 1, 'Only the wanted item type' )
        ->json_is( '/items/holdable' => 1 )
        ->json_is( '/available'      => Mojo::JSON->true );

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
    my $biblio = $builder->build_sample_biblio;

    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    my $response =
        $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->tx->res->json;

    my $expected = Koha::Biblio::Availability::Hold->check(
        {
            biblio           => $biblio,
            patron           => $patron,
            no_short_circuit => 1,
            summarise_items  => 1,
        }
    )->to_api;

    delete $response->{items};
    delete $response->{hold_fee};
    delete $response->{prospective_priority};

    is_deeply(
        $response, $expected,
        'The endpoint returns what the availability class reports, plus the item counts, the fee and the queue position'
    );

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
    my $biblio = $builder->build_sample_biblio;
    $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    # Unknown record
    my $deleted_biblio    = $builder->build_sample_biblio;
    my $deleted_biblio_id = $deleted_biblio->biblionumber;
    $deleted_biblio->delete;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$deleted_biblio_id/holdability?patron_id=$patron_id")
        ->status_is( 404, 'An unknown record gives a 404' );

    # Unknown patron
    my $deleted_patron    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $deleted_patron_id = $deleted_patron->borrowernumber;
    $deleted_patron->delete;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$deleted_patron_id")
        ->status_is( 400, 'An unknown patron gives a 400' )
        ->json_is( '/error_code' => 'patron_not_found' );

    # Unknown pickup library
    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id&pickup_library_id=nope")
        ->json_is( '/error_code' => 'library_not_found' );

    # A user without the reserveforothers > place_holds permission
    my $unauthorised = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $unauthorised->set_password( { password => $password, skip_validation => 1 } );
    my $unauthorised_userid = $unauthorised->userid;

    $t->get_ok("//$unauthorised_userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is( 403, 'A user without place_holds gives a 403' );

    $schema->storage->txn_rollback;
};
