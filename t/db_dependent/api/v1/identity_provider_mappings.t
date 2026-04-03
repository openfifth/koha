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

use JSON;

use Koha::Auth::Identity::Providers;
use Koha::Auth::Identity::Provider::Mappings;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';

sub authorized_patron {
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron->borrowernumber,
                module_bit     => 3,
                code           => 'manage_identity_providers',
            },
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    return $patron;
}

sub unauthorized_patron {
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    return $patron;
}

subtest 'list() tests' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings")->status_is(403);

    # Non-existent provider
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/999999/mappings")->status_is(404);

    # Empty list
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings")->status_is(200)->json_is( [] );

    # With a mapping
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Mappings',
            value => {
                identity_provider_id => $pid,
                koha_field           => 'email',
                provider_field       => 'mail',
            }
        }
    );

    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings")
        ->status_is(200)
        ->json_has("/0/mapping_id");

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $mapping = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Mappings',
            value => {
                identity_provider_id => $pid,
                koha_field           => 'email',
                provider_field       => 'mail',
            }
        }
    );
    my $mid = $mapping->mapping_id;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/$mid")->status_is(403);

    # Non-existent provider
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/999999/mappings/$mid")->status_is(404);

    # Non-existent mapping
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/999999")->status_is(404);

    # Found
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/$mid")
        ->status_is(200)
        ->json_is( '/mapping_id', $mid )
        ->json_is( '/koha_field', 'email' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $new_mapping = {
        koha_field     => 'email',
        provider_field => 'mail',
    };

    # Unauthorized
    $t->post_ok( "//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings" => json => $new_mapping )
        ->status_is(403);

    # Non-existent provider
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/999999/mappings" => json => $new_mapping )
        ->status_is(404);

    # Missing required field
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings" => json =>
            { provider_field => 'mail' } )->status_is(400);

    # Valid creation
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings" => json => $new_mapping )
        ->status_is(201)
        ->json_is( '/koha_field',           'email' )
        ->json_is( '/identity_provider_id', $pid )
        ->json_has('/mapping_id')
        ->header_like( 'Location', qr|/api/v1/auth/identity_providers/$pid/mappings/\d+| );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $mapping = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Mappings',
            value => {
                identity_provider_id => $pid,
                koha_field           => 'email',
                provider_field       => 'mail',
            }
        }
    );
    my $mid = $mapping->mapping_id;

    my $update = {
        koha_field     => 'surname',
        provider_field => 'family_name',
    };

    # Unauthorized
    $t->put_ok( "//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/$mid" => json => $update )
        ->status_is(403);

    # Not found
    $t->put_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/999999" => json => $update )
        ->status_is(404);

    # Valid update
    $t->put_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/$mid" => json => $update )
        ->status_is(200)
        ->json_is( '/mapping_id',     $mid )
        ->json_is( '/koha_field',     'surname' )
        ->json_is( '/provider_field', 'family_name' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $mapping = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Mappings',
            value => {
                identity_provider_id => $pid,
                koha_field           => 'email',
                provider_field       => 'mail',
            }
        }
    );
    my $mid = $mapping->mapping_id;

    # Unauthorized
    $t->delete_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/$mid")->status_is(403);

    # Not found
    $t->delete_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/999999")->status_is(404);

    # Valid deletion
    $t->delete_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/mappings/$mid")->status_is(204);

    $schema->storage->txn_rollback;
};
