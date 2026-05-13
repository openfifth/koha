#!/usr/bin/env perl

# Copyright 2025 PTFS Europe

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

use Koha::EdifactEans;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::EdifactEans->search->delete;

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

    # No accounts, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/edi_ean_accounts")->status_is(200)->json_is( [] );

    my $account = $builder->build_object( { class => 'Koha::EdifactEans' } );

    # One account created, should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/edi_ean_accounts")
        ->status_is(200)
        ->json_is( [ $account->to_api ] );

    my $another_account = $builder->build_object( { class => 'Koha::EdifactEans' } );

    # Two accounts, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/edi_ean_accounts")->status_is(200)->json_is(
        [
            $account->to_api,
            $another_account->to_api,
        ]
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/edi_ean_accounts")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $account   = $builder->build_object( { class => 'Koha::EdifactEans' } );
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

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/edi_ean_accounts/" . $account->id )
        ->status_is(200)
        ->json_is( $account->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/edi_ean_accounts/" . $account->id )->status_is(403);

    my $account_to_delete = $builder->build_object( { class => 'Koha::EdifactEans' } );
    my $non_existent_id   = $account_to_delete->id;
    $account_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/edi_ean_accounts/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Library EAN account not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 6;

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

    my $new_account = { ean => '1234567890123', id_code_qualifier => '14' };

    # Unauthorized attempt
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/edi_ean_accounts" => json => $new_account )
        ->status_is(403);

    # Authorized create
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/edi_ean_accounts" => json => $new_account )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^/api/v1/acquisitions/edi_ean_accounts/\d+|, 'REST3.4.1' )
        ->json_is( '/ean' => $new_account->{ean} );

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

    my $account    = $builder->build_object( { class => 'Koha::EdifactEans' } );
    my $account_id = $account->id;

    my $updated = { ean => '9876543210987', id_code_qualifier => '14' };

    # Unauthorized attempt
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/edi_ean_accounts/$account_id" => json => $updated )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/edi_ean_accounts/$account_id" => json => $updated )
        ->status_is(200)
        ->json_is( '/ean' => '9876543210987' );

    my $account_to_delete = $builder->build_object( { class => 'Koha::EdifactEans' } );
    my $non_existent_id   = $account_to_delete->id;
    $account_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/edi_ean_accounts/$non_existent_id" => json => $updated )
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

    my $account_id = $builder->build_object( { class => 'Koha::EdifactEans' } )->id;

    # Unauthorized attempt
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/edi_ean_accounts/$account_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/edi_ean_accounts/$account_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/edi_ean_accounts/$account_id")->status_is(404);

    $schema->storage->txn_rollback;
};
