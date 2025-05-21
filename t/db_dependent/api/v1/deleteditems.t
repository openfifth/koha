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

use Test::More tests => 1;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Old::Items;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );
my $t = Test::Mojo->new('Koha::REST::V1');

$schema->storage->txn_begin;

# Create a superlibrarian
my $librarian = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => { flags => 1 }  # superlibrarian
    }
);
my $password = 'thePassword123';
$librarian->set_password( { password => $password, skip_validation => 1 } );
my $userid = $librarian->userid;

subtest 'list() and get() tests' => sub {
    plan tests => 7;

    # Create a test item
    my $item = $builder->build_sample_item(
        {
            barcode => 'TEST123',
            homebranch => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    # Move to deleteditems and delete
    $item->move_to_deleted;
    my $itemnumber = $item->itemnumber;
    $item->delete;

    # Commit the transaction so the API can see the deleted item
    $schema->storage->txn_commit;
    $schema->storage->txn_begin;  # Start a new transaction for cleanup

    # Test list endpoint
    $t->get_ok("//$userid:$password@/api/v1/deleteditems")
        ->status_is(200)
        ->json_has('/0/item_id', 'Response contains item_id')
        ->json_has('/0/external_id', 'Response contains external_id');

    # Test get endpoint
    my $deleted_item = Koha::Old::Items->search({ itemnumber => $itemnumber })->single;
    $t->get_ok('/api/v1/deleteditems/' . $deleted_item->itemnumber)
        ->status_is(200)
        ->json_is('/external_id', 'TEST123')
        ->json_is('/home_library_id', 'CPL')
        ->json_is('/holding_library_id', 'CPL');
};

$schema->storage->txn_rollback;