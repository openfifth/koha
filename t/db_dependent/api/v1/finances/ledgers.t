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

use Test::NoWarnings;
use Test::More tests => 6;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::Finances::Ledgers;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::Finances::Ledgers->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # No ledgers, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is( [] );

    my $ledger = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );

    # One ledger created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is( [ $ledger->to_api ] );

    my $another_ledger = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );

    # Two ledgers, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is(
        [
            $ledger->to_api,
            $another_ledger->to_api
        ]
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/ledgers")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $ledger    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/" . $ledger->ledger_id )
        ->status_is(200)
        ->json_is( $ledger->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers/" . $ledger->ledger_id )->status_is(403);

    my $ledger_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $non_existent_id  = $ledger_to_delete->ledger_id;
    $ledger_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Ledger not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $ledger = {
        name          => 'Test Ledger',
        currency      => 'GBP',
        ledger_amount => 10000,
        status        => Mojo::JSON->true,
        locked        => Mojo::JSON->false,
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers" => json => $ledger )->status_is(403);

    # Authorized attempt to write
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers" => json => $ledger )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/ledgers\/\d+|, 'REST3.4.1' )
        ->json_is( '/name'          => $ledger->{name} )
        ->json_is( '/currency'      => $ledger->{currency} )
        ->json_is( '/ledger_amount' => $ledger->{ledger_amount} );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $ledger    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $ledger_id = $ledger->ledger_id;

    my $updated_ledger = {
        name          => 'Updated Ledger',
        currency      => 'EUR',
        ledger_amount => 20000,
        status        => Mojo::JSON->true,
        locked        => Mojo::JSON->false,
    };

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $updated_ledger )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $updated_ledger )
        ->status_is(200)
        ->json_is( '/name' => 'Updated Ledger' );

    my $ledger_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $non_existent_id  = $ledger_to_delete->ledger_id;
    $ledger_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$non_existent_id" => json => $updated_ledger )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $ledger_id = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } )->ledger_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")->status_is(404);

    $schema->storage->txn_rollback;
};
