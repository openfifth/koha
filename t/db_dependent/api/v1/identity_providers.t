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

my $valid_oidc_config =
    '{"key":"client_key","secret":"client_secret","well_known_url":"https://example.com/.well-known/openid-configuration"}';

subtest 'list() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    Koha::Auth::Identity::Providers->search->delete;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers")->status_is(403);

    # Empty list
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers")->status_is(200)->json_is( [] );

    # With a provider
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Providers',
            value => { protocol => 'OIDC', config => $valid_oidc_config }
        }
    );

    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers")
        ->status_is(200)
        ->json_has("/0/identity_provider_id");

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Providers',
            value => { protocol => 'OIDC', config => $valid_oidc_config }
        }
    );
    my $id = $provider->identity_provider_id;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$id")->status_is(403);

    # Not found
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/999999")->status_is(404);

    # Found
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$id")
        ->status_is(200)
        ->json_is( '/identity_provider_id', $id );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $new_provider = {
        code        => 'test_oidc',
        description => 'Test OIDC Provider',
        protocol    => 'OIDC',
        config      => {
            key            => 'client_key',
            secret         => 'client_secret',
            well_known_url => 'https://example.com/.well-known/openid-configuration',
        },
        enabled => JSON::true,
    };

    # Unauthorized
    $t->post_ok( "//$unauth_userid:$password@/api/v1/auth/identity_providers" => json => $new_provider )
        ->status_is(403);

    # Missing required field (no config)
    my $bad_provider = { code => 'bad', protocol => 'OIDC' };
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers" => json => $bad_provider )->status_is(400);

    # Invalid protocol (caught by OpenAPI validation)
    my $invalid_protocol_provider = { %$new_provider, protocol => 'INVALID', code => 'inv' };
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers" => json => $invalid_protocol_provider )
        ->status_is(400);

    # Valid creation
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers" => json => $new_provider )
        ->status_is(201)
        ->json_is( '/code',     'test_oidc' )
        ->json_is( '/protocol', 'OIDC' )
        ->json_has('/identity_provider_id')
        ->header_like( 'Location', qr|/api/v1/auth/identity_providers/\d+| );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Providers',
            value => {
                protocol => 'OIDC',
                config   => $valid_oidc_config,
            }
        }
    );
    my $id = $provider->identity_provider_id;

    my $update = {
        code        => $provider->code,
        description => 'Updated description',
        protocol    => 'OIDC',
        config      => {
            key            => 'k',
            secret         => 's',
            well_known_url => 'https://example.com/.well-known/openid-configuration',
        },
        enabled => JSON::true,
    };

    # Unauthorized
    $t->put_ok( "//$unauth_userid:$password@/api/v1/auth/identity_providers/$id" => json => $update )->status_is(403);

    # Not found
    $t->put_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/999999" => json => $update )->status_is(404);

    # Valid update
    $t->put_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$id" => json => $update )
        ->status_is(200)
        ->json_is( '/identity_provider_id', $id )
        ->json_is( '/description',          'Updated description' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Providers',
            value => { protocol => 'OIDC', config => $valid_oidc_config }
        }
    );
    my $id = $provider->identity_provider_id;

    # Unauthorized
    $t->delete_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$id")->status_is(403);

    # Not found
    $t->delete_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/999999")->status_is(404);

    # Valid deletion
    $t->delete_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$id")->status_is(204);

    $schema->storage->txn_rollback;
};
