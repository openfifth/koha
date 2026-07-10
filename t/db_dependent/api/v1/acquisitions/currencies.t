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
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::Currencies;
use Koha::Database;
use Mojo::JSON qw(encode_json);

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 9;

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

    my $currency = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'TST' }
        }
    );

    # One currency created, should be returned when filtered by code
    my $query = { currency => 'TST' };
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/currencies?q=" . encode_json($query) )
        ->status_is(200)
        ->json_is( '/0/currency' => 'TST' );

    my $another_currency = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'TS2' }
        }
    );

    # Two currencies, both appear when filtered by their codes
    $query = { currency => { '-in' => [ 'TST', 'TS2' ] } };
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/currencies?q=" . encode_json($query) )
        ->status_is(200)
        ->json_has('/0/currency')
        ->json_has('/1/currency');

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/currencies")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $currency = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'TST' }
        }
    );
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

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/currencies/" . $currency->currency )
        ->status_is(200)
        ->json_is( $currency->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/currencies/" . $currency->currency )->status_is(403);

    my $currency_to_delete = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'DEL' }
        }
    );
    my $non_existent_id = $currency_to_delete->currency;
    $currency_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/currencies/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Currency not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 12;

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

    my $new_currency = {
        currency => 'TST',
        symbol   => 'T',
        rate     => 1.0,
    };

    # Unauthorized attempt
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/currencies" => json => $new_currency )
        ->status_is(403);

    # Authorized create
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/currencies" => json => $new_currency )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^/api/v1/acquisitions/currencies/\w+|, 'REST3.4.1' )
        ->json_is( '/currency' => $new_currency->{currency} )
        ->json_is( '/symbol'   => $new_currency->{symbol} )
        ->json_is( '/rate'     => $new_currency->{rate} );

    # Adding a currency with an existing code must not overwrite it silently
    warnings_like {
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/currencies" => json => $new_currency )
            ->status_is( 409, 'Duplicate currency code returns Conflict' )
            ->json_is( '/error_code' => 'duplicate_id' );
    }
    qr{DBD::mysql::st execute failed: Duplicate entry};

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

    my $currency = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'TST', symbol => 'T', rate => 1.5 }
        }
    );
    my $currency_id = $currency->currency;

    my $updated = { symbol => 'U', rate => 2.0 };

    # Unauthorized attempt
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/currencies/$currency_id" => json => $updated )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/currencies/$currency_id" => json => $updated )
        ->status_is(200)
        ->json_is( '/symbol' => 'U' );

    my $currency_to_delete = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'DEL' }
        }
    );
    my $non_existent_id = $currency_to_delete->currency;
    $currency_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/currencies/$non_existent_id" => json => $updated )
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

    my $currency_id = $builder->build_object(
        {
            class => 'Koha::Acquisition::Currencies',
            value => { currency => 'TST' }
        }
    )->currency;

    # Unauthorized attempt
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/currencies/$currency_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/currencies/$currency_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/currencies/$currency_id")->status_is(404);

    $schema->storage->txn_rollback;
};
