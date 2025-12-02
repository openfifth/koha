#!/usr/bin/env perl

# Copyright 2025-2026 Open Fifth Ltd
#
# This file is part of Koha
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
use Test::More tests => 7;
use Test::Mojo;
use JSON;

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Auth qw( haspermission );

use Koha::Auth::Permissions;
use Koha::Displays;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'config() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**33 }    # displays flag = 33
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $userflags   = haspermission($userid);
    my $permissions = Koha::Auth::Permissions->get_authz_from_flags( { flags => $userflags } );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );

    ## Authorized user tests
    # No displays, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/displays/config")->status_is(200)->json_is(
        {
            settings => {
                permissions => $permissions,
                enabled     => 1,
            },
        }
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/displays/config")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'list() tests' => sub {

    plan tests => 23;

    $schema->storage->txn_begin;

    Koha::Displays->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**33 }    # displays flag = 33
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

    ## Authorized user tests
    # No displays, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/displays")->status_is(200)->json_is( [] );

    my $display = $builder->build_object( { class => 'Koha::Displays' } )->store->discard_changes;

    # One display created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/displays")->status_is(200)->json_is( [ $display->to_api ] );

    my $another_display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => { display_home_branch => $display->display_home_branch },
        }
    )->store->discard_changes;

    my $display_with_another_branch = $builder->build_object( { class => 'Koha::Displays' } )->store->discard_changes;

    # Three displays created, they should all be returned
    $t->get_ok("//$userid:$password@/api/v1/displays")->status_is(200)->json_is(
        [
            $display->to_api,
            $another_display->to_api,
            $display_with_another_branch->to_api
        ]
    );

    # Filtering works, two displays sharing display_home_branch
    $t->get_ok( "//$userid:$password@/api/v1/displays?display_home_branch=" . $display->display_home_branch )
        ->status_is(200)
        ->json_is(
        [
            $display->to_api,
            $another_display->to_api
        ],
        );

    $t->get_ok(
        "//$userid:$password@/api/v1/displays?display_holding_branch=" . $another_display->display_holding_branch )
        ->status_is(200)
        ->json_is( [ $another_display->to_api ] );

    $t->get_ok( "//$userid:$password@/api/v1/displays?display_name=" . $display->display_name )
        ->status_is(200)
        ->json_is( [ $display->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/displays?display_blah=blah")
        ->status_is(400)
        ->json_is( [ { path => '/query/display_blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/displays")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $display   = $builder->build_object( { class => 'Koha::Displays' } )->store->discard_changes;
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**33 }    # displays flag = 33
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

    $t->get_ok( "//$userid:$password@/api/v1/displays/" . $display->display_id )
        ->status_is(200)
        ->json_is( $display->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/displays/" . $display->display_id )->status_is(403);

    my $display_to_delete = $builder->build_object( { class => 'Koha::Displays' } );
    my $non_existent_id   = $display_to_delete->display_id;
    $display_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/displays/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Display not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 18;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**33 }    # displays flag = 33
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

    my $itemtype = $builder->build_object( { class => 'Koha::ItemTypes' } );

    my $display = {
        display_name        => "Test Display",
        enabled             => JSON::true,
        display_return_over => "no",
        start_date          => "2024-01-01",
        end_date            => "2024-12-31",
        display_location    => "DISPLAY",
        display_code        => "TEST",
        display_home_branch => "CPL",
        display_itype       => $itemtype->itemtype
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/displays" => json => $display )->status_is(403);

    # Authorized attempt to write invalid data
    my $display_with_invalid_field = {
        blah                => "Display Blah",
        display_name        => "Test Display",
        enabled             => JSON::true,
        display_return_over => "no"
    };

    $t->post_ok( "//$userid:$password@/api/v1/displays" => json => $display_with_invalid_field )
        ->status_is(400)
        ->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
        );

    # Authorized attempt to write
    my $display_id =
        $t->post_ok( "//$userid:$password@/api/v1/displays" => json => $display )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like(
        Location => qr|^\/api\/v1\/displays/\d*|,
        'REST3.4.1'
        )
        ->json_is( '/display_name'        => $display->{display_name} )
        ->json_is( '/enabled'             => $display->{enabled} )
        ->json_is( '/display_return_over' => $display->{display_return_over} )
        ->json_is( '/start_date'          => $display->{start_date} )
        ->tx->res->json->{display_id};

    # Authorized attempt to create with null id
    $display->{display_id} = undef;
    $t->post_ok( "//$userid:$password@/api/v1/displays" => json => $display )->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $display->{display_id} = $display_id;
    $t->post_ok( "//$userid:$password@/api/v1/displays" => json => $display )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/display_id"
            }
        ]
    );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**33 }    # displays flag = 33
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

    my $itemtype = $builder->build_object( { class => 'Koha::ItemTypes' } );

    my $display_id = $builder->build_object( { class => 'Koha::Displays' } )->display_id;

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/displays/$display_id" => json =>
            { display_name => 'New unauthorized name change' } )->status_is(403);

    # Attempt partial update on a PUT
    my $display_with_missing_field = {
        display_name => 'Updated Display',
        enabled      => JSON::false
    };

    $t->put_ok( "//$userid:$password@/api/v1/displays/$display_id" => json => $display_with_missing_field )
        ->status_is(400)
        ->json_is( "/errors" => [ { message => "Missing property.", path => "/body/display_return_over" } ] );

    # Full object update on PUT
    my $display_with_updated_field = {
        display_name        => "Updated Display Name",
        enabled             => JSON::false,
        display_return_over => "any",
        start_date          => "2024-02-01",
        end_date            => "2024-11-30",
        display_location    => "NEWDISPLAY",
        display_code        => "UPDATED",
        display_home_branch => "CPL",
        display_itype       => $itemtype->itemtype
    };

    $t->put_ok( "//$userid:$password@/api/v1/displays/$display_id" => json => $display_with_updated_field )
        ->status_is(200)
        ->json_is( '/display_name' => 'Updated Display Name' );

    # Authorized attempt to write invalid data
    my $display_with_invalid_field = {
        blah                => "Display Blah",
        display_name        => "Test Display",
        enabled             => JSON::true,
        display_return_over => "no"
    };

    $t->put_ok( "//$userid:$password@/api/v1/displays/$display_id" => json => $display_with_invalid_field )
        ->status_is(400)
        ->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
        );

    my $display_to_delete = $builder->build_object( { class => 'Koha::Displays' } );
    my $non_existent_id   = $display_to_delete->display_id;
    $display_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/displays/$non_existent_id" => json => $display_with_updated_field )
        ->status_is(404);

    # Wrong method (POST)
    $display_with_updated_field->{display_id} = 2;

    $t->post_ok( "//$userid:$password@/api/v1/displays/$display_id" => json => $display_with_updated_field )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**33 }    # displays flag = 33
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

    my $display_id = $builder->build_object( { class => 'Koha::Displays' } )->display_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/displays/$display_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/displays/$display_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/displays/$display_id")->status_is(404);

    $schema->storage->txn_rollback;
};
