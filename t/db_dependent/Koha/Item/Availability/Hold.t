#!/usr/bin/perl

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

use Test::NoWarnings;
use Test::More tests => 11;

use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Circulation qw( AddIssue );
use Koha::Database;

BEGIN { use_ok('Koha::Item::Availability::Hold'); }

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Available item' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',            0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems',       1 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnPatronsPossessions', 1 );
    t::lib::Mocks::mock_preference( 'UseRecalls',                     0 );
    t::lib::Mocks::mock_preference( 'maxreserves',                    0 );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( $result->available, 'Item is available for hold' );

    $schema->storage->txn_rollback;
};

subtest 'Damaged item blocked' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode, damaged => 1 } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( !$result->available,          'Damaged item not available' );
    ok( $result->blockers->{damaged}, 'Blocker is damaged' );

    $schema->storage->txn_rollback;
};

subtest 'Age restriction' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        { class => 'Koha::Patrons', value => { branchcode => $library->branchcode, dateofbirth => '2016-01-01' } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );
    $item->biblio->biblioitem->agerestriction('FSK 16')->store;

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 1 );
    t::lib::Mocks::mock_preference( 'AgeRestrictionMarker',     'FSK|PEGI' );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( !$result->available,                 'Minor blocked by age restriction' );
    ok( $result->blockers->{age_restricted}, 'Blocker is age_restricted' );

    $schema->storage->txn_rollback;
};

subtest 'Item already on hold by patron' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 1 );

    $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                itemnumber   => $item->itemnumber, borrowernumber => $patron->borrowernumber,
                biblionumber => $item->biblionumber
            }
        }
    );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( !$result->available,                       'Not available when patron already has hold' );
    ok( $result->blockers->{item_already_on_hold}, 'Blocker is item_already_on_hold' );

    $schema->storage->txn_rollback;
};

subtest 'Patron has item checked out' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',            0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems',       1 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnPatronsPossessions', 0 );
    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

    AddIssue( $patron, $item->barcode );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( !$result->available,                     'Not available when patron has item checked out' );
    ok( $result->blockers->{already_possession}, 'Blocker is already_possession' );

    $schema->storage->txn_rollback;
};

subtest 'Hold policy not_allowed' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 1 );
    t::lib::Mocks::mock_preference( 'ReservesControlBranch',    'ItemHomeLibrary' );

    Koha::CirculationRules->set_rule(
        {
            branchcode => $library->branchcode,
            itemtype   => $item->effective_itemtype,
            rule_name  => 'holdallowed',
            rule_value => 'not_allowed',
        }
    );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( !$result->available,                 'Not available when holdallowed is not_allowed' );
    ok( $result->blockers->{not_reservable}, 'Blocker is not_reservable' );

    $schema->storage->txn_rollback;
};

subtest 'Hold policy from_home_library' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $home_library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $patron_library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $home_library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 1 );
    t::lib::Mocks::mock_preference( 'ReservesControlBranch',    'ItemHomeLibrary' );

    Koha::CirculationRules->set_rule(
        {
            branchcode => $home_library->branchcode,
            itemtype   => $item->effective_itemtype,
            rule_name  => 'holdallowed',
            rule_value => 'from_home_library',
        }
    );

    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron, skip_patron_checks => 1 } );
    ok( !$result->available,                                     'Not available when patron not from home library' );
    ok( $result->blockers->{cannot_reserve_from_other_branches}, 'Blocker is cannot_reserve_from_other_branches' );

    $schema->storage->txn_rollback;
};

subtest 'Pickup library not valid' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 0 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 1 );

    my $result = Koha::Item::Availability::Hold->check(
        { item => $item, patron => $patron, pickup_library => $library, skip_patron_checks => 1 } );
    ok( !$result->available, 'Not available when pickup library is not a pickup location' );
    ok( $result->blockers->{library_not_pickup_location}, 'Blocker is library_not_pickup_location' );

    $schema->storage->txn_rollback;
};

subtest 'Chaining: patron blockers appear in item-level result' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        { class => 'Koha::Patrons', value => { branchcode => $library->branchcode, gonenoaddress => 1 } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'IndependentBranches',      0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 1 );

    # Don't skip patron checks — should chain
    my $result = Koha::Item::Availability::Hold->check( { item => $item, patron => $patron } );
    ok( !$result->available,              'Not available due to patron blocker' );
    ok( $result->blockers->{bad_address}, 'Patron blocker bad_address appears in item-level result' );

    $schema->storage->txn_rollback;
};
