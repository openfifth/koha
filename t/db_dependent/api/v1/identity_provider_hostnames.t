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
use Test::More tests => 9;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use JSON;

use Koha::Auth::Hostname;
use Koha::Auth::Hostnames;
use Koha::Auth::Identity::Provider::Hostnames;
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

subtest 'list() tests for /auth/hostnames' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    Koha::Auth::Hostnames->search->delete;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/hostnames")->status_is(403);

    # Empty list
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/hostnames")->status_is(200)->json_is( [] );

    # With a hostname
    $builder->build_object(
        {
            class => 'Koha::Auth::Hostnames',
            value => { hostname => 'library.example.com' }
        }
    );

    $t->get_ok("//$auth_userid:$password@/api/v1/auth/hostnames")->status_is(200)->json_has("/0/hostname_id");

    $schema->storage->txn_rollback;
};

subtest 'get() tests for /auth/hostnames/{hostname_id}' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $hostname = $builder->build_object(
        {
            class => 'Koha::Auth::Hostnames',
            value => { hostname => 'lib.example.org' }
        }
    );
    my $hid = $hostname->hostname_id;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/hostnames/$hid")->status_is(403);

    # Not found
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/hostnames/999999")->status_is(404);

    # Found
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/hostnames/$hid")
        ->status_is(200)
        ->json_is( '/hostname_id', $hid )
        ->json_is( '/hostname',    'lib.example.org' );

    $schema->storage->txn_rollback;
};

subtest 'list() tests for /auth/identity_providers/{id}/hostnames' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames")->status_is(403);

    # Non-existent provider
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/999999/hostnames")->status_is(404);

    # Empty list
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames")
        ->status_is(200)
        ->json_is( [] );

    # With a hostname association
    my $hostname =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'provider.example.com' } } );
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $pid,
                hostname_id          => $hostname->hostname_id,
                is_enabled           => 1,
                is_exclusive         => 0,
            }
        }
    );

    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames")
        ->status_is(200)
        ->json_has("/0/identity_provider_hostname_id");

    $schema->storage->txn_rollback;
};

subtest 'get() tests for /auth/identity_providers/{id}/hostnames/{hid}' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $hostname =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'get.example.com' } } );

    my $ph = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $pid,
                hostname_id          => $hostname->hostname_id,
                is_enabled           => 1,
                is_exclusive         => 0,
            }
        }
    );
    my $phid = $ph->identity_provider_hostname_id;

    # Unauthorized
    $t->get_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/$phid")->status_is(403);

    # Non-existent provider
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/999999/hostnames/$phid")->status_is(404);

    # Non-existent hostname association
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/999999")->status_is(404);

    # Found
    $t->get_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/$phid")
        ->status_is(200)
        ->json_is( '/identity_provider_hostname_id', $phid )
        ->json_is( '/hostname',                      'get.example.com' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests - hostname string' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $new_hostname = {
        hostname     => 'add.example.com',
        is_enabled   => JSON::true,
        is_exclusive => JSON::false,
        matchpoint   => 'userid',
    };

    # Unauthorized
    $t->post_ok( "//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames" => json => $new_hostname )
        ->status_is(403);

    # Non-existent provider
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/999999/hostnames" => json => $new_hostname )
        ->status_is(404);

    # Valid creation using hostname string (find-or-create)
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames" => json => $new_hostname )
        ->status_is(201)
        ->json_is( '/hostname',             'add.example.com' )
        ->json_is( '/identity_provider_id', $pid )
        ->json_is( '/matchpoint',           'userid' )
        ->json_has('/identity_provider_hostname_id')
        ->header_like( 'Location', qr|/api/v1/auth/identity_providers/$pid/hostnames/\d+| );

    # Duplicate should return 409 (suppress the expected Koha::Object DuplicateID warn)
    {
        local $SIG{__WARN__} = sub { };
        $t->post_ok(
            "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames" => json => $new_hostname )
            ->status_is(409);
    }

    $schema->storage->txn_rollback;
};

subtest 'add() tests - hostname_id' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $auth_patron = authorized_patron();
    my $auth_userid = $auth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $hostname =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'byid.example.com' } } );

    my $new_hostname = {
        hostname_id  => $hostname->hostname_id,
        is_enabled   => JSON::true,
        is_exclusive => JSON::false,
    };

    # Valid creation using hostname_id
    $t->post_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames" => json => $new_hostname )
        ->status_is(201)
        ->json_is( '/hostname',             'byid.example.com' )
        ->json_is( '/hostname_id',          $hostname->hostname_id )
        ->json_is( '/identity_provider_id', $pid )
        ->json_has('/identity_provider_hostname_id');

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $auth_patron   = authorized_patron();
    my $unauth_patron = unauthorized_patron();

    my $auth_userid   = $auth_patron->userid;
    my $unauth_userid = $unauth_patron->userid;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $pid      = $provider->identity_provider_id;

    my $hostname =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'update.example.com' } } );

    my $ph = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $pid,
                hostname_id          => $hostname->hostname_id,
                is_enabled           => 1,
                is_exclusive         => 0,
            }
        }
    );
    my $phid = $ph->identity_provider_hostname_id;

    my $update = {
        hostname_id  => $hostname->hostname_id,
        is_enabled   => JSON::false,
        is_exclusive => JSON::true,
        matchpoint   => 'userid',
    };

    # Unauthorized
    $t->put_ok( "//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/$phid" => json => $update )
        ->status_is(403);

    # Not found
    $t->put_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/999999" => json => $update )
        ->status_is(404);

    # Valid update
    $t->put_ok( "//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/$phid" => json => $update )
        ->status_is(200)
        ->json_is( '/identity_provider_hostname_id', $phid )
        ->json_is( '/is_enabled',                    JSON::false )
        ->json_is( '/is_exclusive',                  JSON::true )
        ->json_is( '/matchpoint',                    'userid' );

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

    my $hostname =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'delete.example.com' } } );

    my $ph = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $pid,
                hostname_id          => $hostname->hostname_id,
                is_enabled           => 1,
                is_exclusive         => 0,
            }
        }
    );
    my $phid = $ph->identity_provider_hostname_id;

    # Unauthorized
    $t->delete_ok("//$unauth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/$phid")->status_is(403);

    # Not found
    $t->delete_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/999999")->status_is(404);

    # Valid deletion
    $t->delete_ok("//$auth_userid:$password@/api/v1/auth/identity_providers/$pid/hostnames/$phid")->status_is(204);

    $schema->storage->txn_rollback;
};
