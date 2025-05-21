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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Items;
use Koha::Biblios;
use C4::Context;
use Koha::Old::Items;
use C4::Biblio qw( DelBiblio );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

# Create a library once for all tests
my $branchcode = 'TST' . int(rand(100000));
my $library = $builder->build_object(
    {
        class => 'Koha::Libraries',
        value => { branchcode => $branchcode }
    }
);

plan tests => 4;  # 3 subtests + 1 NoWarnings test

subtest 'get() tests' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    # Create a patron with catalogue permissions
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                flags => 4,  # catalogue permissions
                branchcode => 'CPL'
            }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    $patron->discard_changes;
    my $userid = $patron->userid;

    # Set up userenv
    t::lib::Mocks::mock_userenv({
        branchcode => 'CPL',
        flags => 4,  # catalogue permissions
        id => $patron->borrowernumber
    });

    # Create a bibliographic record
    my $biblio = $builder->build_sample_biblio(
        {
            title  => 'Test title for deleted item',
            author => 'Test author'
        }
    );

    # Create an item
    my $item = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            barcode      => 'TEST_BC_123',
            homebranch   => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    # Delete the item
    my $itemnumber = $item->itemnumber;
    my $barcode = $item->barcode;
    $item->safe_delete();

    # Test with proper permissions
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items/$itemnumber" )
      ->status_is(200)
      ->json_has('/itemnumber')
      ->json_has('/biblionumber')
      ->json_has('/biblioitemnumber')
      ->json_has('/barcode');

    $schema->storage->txn_rollback;
};

subtest 'list() tests' => sub {
    plan tests => 15;

    $schema->storage->txn_begin;

    # Create a patron with catalogue permissions
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                flags => 4,  # catalogue permissions
                branchcode => 'CPL'
            }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    $patron->discard_changes;
    my $userid = $patron->userid;

    # Set up userenv
    t::lib::Mocks::mock_userenv({
        branchcode => 'CPL',
        flags => 4,  # catalogue permissions
        id => $patron->borrowernumber
    });

    # Create bibliographic records
    my $biblio1 = $builder->build_sample_biblio(
        {
            title  => 'First test title',
            author => 'Test author'
        }
    );

    my $biblio2 = $builder->build_sample_biblio(
        {
            title  => 'Second test title',
            author => 'Test author'
        }
    );

    # Create items
    my $item1 = $builder->build_sample_item(
        {
            biblionumber => $biblio1->biblionumber,
            barcode      => 'TEST_BC_1',
            itype        => 'BK',
            location     => 'CART',
            homebranch   => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    my $item2 = $builder->build_sample_item(
        {
            biblionumber => $biblio1->biblionumber,
            barcode      => 'TEST_BC_2',
            itype        => 'DVD',
            location     => 'PROC',
            homebranch   => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    my $item3 = $builder->build_sample_item(
        {
            biblionumber => $biblio2->biblionumber,
            barcode      => 'TEST_BC_3',
            itype        => 'BK',
            location     => 'GEN',
            homebranch   => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    # Delete items
    $item1->safe_delete();
    $item2->safe_delete();
    $item3->safe_delete();

    # Test listing all deleted items
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items" )
      ->status_is(200)
      ->json_has('/0')
      ->json_has('/1')
      ->json_has('/2')
      ->json_hasnt('/3');

    # Test filtering by biblionumber
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items?biblionumber=" . $biblio1->biblionumber )
      ->status_is(200)
      ->json_has('/0')
      ->json_has('/1')
      ->json_hasnt('/2');

    # Test filtering by barcode
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items?barcode=TEST_BC_1" )
      ->status_is(200)
      ->json_has('/0')
      ->json_hasnt('/1');

    $schema->storage->txn_rollback;
};

subtest 'embed tests' => sub {
    plan tests => 15;

    $schema->storage->txn_begin;

    # Create a patron with catalogue permissions
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                flags => 4,  # catalogue permissions
                branchcode => 'CPL'
            }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    $patron->discard_changes;
    my $userid = $patron->userid;

    # Set up userenv
    t::lib::Mocks::mock_userenv({
        branchcode => 'CPL',
        flags => 4,  # catalogue permissions
        id => $patron->borrowernumber
    });

    # Create a bibliographic record
    my $biblio = $builder->build_sample_biblio(
        {
            title  => 'Test title for embedding',
            author => 'Test author'
        }
    );

    # Create an item
    my $item = $builder->build_sample_item(
        {
            biblionumber => $biblio->biblionumber,
            barcode      => 'TEST_BC_EMBED',
            homebranch   => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    # Delete the item
    my $itemnumber = $item->itemnumber;
    $item->safe_delete();

    # Test embedding biblio for a single item
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items/$itemnumber" => { 'x-koha-embed' => 'biblio' } )
      ->status_is(200)
      ->json_has('/biblio')
      ->json_is('/biblio/title', 'Test title for embedding')
      ->json_is('/biblio/author', 'Test author');

    # Test embedding biblio in list endpoint
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items" => { 'x-koha-embed' => 'biblio' } )
      ->status_is(200)
      ->json_has('/0/biblio')
      ->json_is('/0/biblio/title', 'Test title for embedding')
      ->json_is('/0/biblio/author', 'Test author');

    # Now delete the biblio and test embedding again
    DelBiblio($biblio->biblionumber);

    # Test embedding deleted biblio for a single item
    $t->get_ok( "//$userid:$password@/api/v1/deleted/items/$itemnumber" => { 'x-koha-embed' => 'biblio' } )
      ->status_is(200)
      ->json_has('/biblio')
      ->json_is('/biblio/title', 'Test title for embedding')
      ->json_is('/biblio/author', 'Test author');

    $schema->storage->txn_rollback;
};