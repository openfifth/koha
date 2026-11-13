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
use Test::More tests => 9;
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
            value => { flags => 2**34 }    # displays flag = 34
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
            value => { flags => 2**34 }    # displays flag = 34
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
            value => { flags => 2**34 }    # displays flag = 34
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

    plan tests => 25;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**34 }    # displays flag = 34
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
        display_days        => 14,
        display_return_over => "no",
        start_date          => "2024-01-01",
        end_date            => "2024-12-31",
        enabled             => JSON::true,
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
        display_days        => 14,
        display_return_over => "no",
        start_date          => "2024-01-01",
        end_date            => "2024-12-31",
        enabled             => JSON::true
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
        ->json_is( '/display_days'        => $display->{display_days} )
        ->json_is( '/display_return_over' => $display->{display_return_over} )
        ->json_is( '/start_date'          => $display->{start_date} )
        ->json_is( '/end_date'            => $display->{end_date} )
        ->json_is( '/enabled'             => $display->{enabled} )
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

    # A library-restricted user must not leave a display behind when rejected
    my $own_library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $other_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $restricted    = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0, branchcode => $own_library->branchcode }
        }
    );
    $restricted->set_password( { password => $password, skip_validation => 1 } );
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $restricted->borrowernumber,
                module_bit     => 34,
                code           => 'add_displays',
            }
        }
    );
    my $restricted_userid = $restricted->userid;

    my $rejected_display = {
        %{$display},
        display_name   => 'Rejected display',
        display_branch => $other_library->branchcode,
    };
    delete $rejected_display->{display_id};

    $t->post_ok( "//$restricted_userid:$password@/api/v1/displays" => json => $rejected_display )->status_is(403);
    is(
        Koha::Displays->search( { display_name => 'Rejected display' } )->count, 0,
        'A rejected display is not stored'
    );
    $t->post_ok( "//$restricted_userid:$password@/api/v1/displays" => json =>
            { %{$rejected_display}, display_branch => $own_library->branchcode } )->status_is(201);

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**34 }    # displays flag = 34
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
        display_name        => "Updated Display",
        display_return_over => "any",
        enabled             => JSON::false,
        start_date          => "2024-01-01",
        end_date            => "2024-12-31",
    };

    $t->put_ok( "//$userid:$password@/api/v1/displays/$display_id" => json => $display_with_missing_field )
        ->status_is(400)
        ->json_is( "/errors" => [ { message => "Missing property.", path => "/body/display_days" } ] );

    # Full object update on PUT
    my $display_with_updated_field = {
        display_name        => "Updated Display Name",
        display_days        => 14,
        display_return_over => "any",
        enabled             => JSON::false,
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
            value => { flags => 2**34 }    # displays flag = 34
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

subtest 'library restrictions and round trips' => sub {

    plan tests => 28;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $own      = $builder->build_object( { class => 'Koha::Libraries' } );
    my $foreign  = $builder->build_object( { class => 'Koha::Libraries' } );

    my $make_user = sub {
        my (@codes) = @_;
        my $patron = $builder->build_object(
            { class => 'Koha::Patrons', value => { flags => 0, branchcode => $own->branchcode } } );
        $patron->set_password( { password => $password, skip_validation => 1 } );
        for my $code (@codes) {
            $builder->build(
                {
                    source => 'UserPermission',
                    value  => { borrowernumber => $patron->borrowernumber, module_bit => 34, code => $code }
                }
            );
        }
        return $patron->userid;
    };

    # Restricted to the displays of their own library
    my $userid = $make_user->(qw( view_displays edit_displays delete_displays ));
    my $url    = sub { "//$userid:$password@/api/v1/displays" . ( shift // '' ) };

    my $make = sub {
        my ($library) = @_;
        return $builder->build_object(
            {
                class => 'Koha::Displays',
                value => {
                    display_branch      => $library->branchcode,
                    enabled             => 1,
                    start_date          => '2000-01-01',
                    end_date            => '2100-01-01',
                    display_days        => 7,
                    display_return_over => 'no',
                    display_name        => 'Original name',
                }
            }
        );
    };
    my $own_display     = $make->($own);
    my $foreign_display = $make->($foreign);

    $t->get_ok( $url->() )->status_is(200);
    ok(
        !( grep { $_->{display_id} == $foreign_display->display_id } @{ $t->tx->res->json } ),
        'The other library\'s display is not listed'
    );
    $t->get_ok( $url->( '/' . $foreign_display->display_id ) )->status_is(403);

    # What a client GETs can be PUT back: computed and embedded keys are ignored
    $t->get_ok( $url->( '/' . $own_display->display_id ) => { 'x-koha-embed' => 'display_library' } )->status_is(200);
    my $received = $t->tx->res->json;
    ok( exists $received->{display_library}, 'The embedded library is part of the representation' );
    delete @{$received}{qw( active display_id )};    # read-only: a client does not send these back
    $t->put_ok( $url->( '/' . $own_display->display_id ) => json => { %{$received}, display_name => 'Round trip' } )
        ->status_is(200);
    is( $own_display->get_from_storage->display_name, 'Round trip', 'The display was updated' );

    # A restricted user cannot edit another library's display...
    $t->put_ok( $url->( '/' . $foreign_display->display_id ) => json => { %{$received}, display_name => 'Hijacked' } )
        ->status_is(403);
    is( $foreign_display->get_from_storage->display_name, 'Original name', '...and it was not changed' );

    # ...nor move their own out of their libraries
    $t->put_ok(
        $url->( '/' . $own_display->display_id ) => json => { %{$received}, display_branch => $foreign->branchcode } )
        ->status_is(403);
    is( $own_display->get_from_storage->display_branch, $own->branchcode, '...the display stayed in its library' );

    # Delete
    $t->delete_ok( $url->( '/' . $foreign_display->display_id ) )->status_is(403);
    ok( $foreign_display->get_from_storage, 'The other library\'s display still exists' );

    # Permission to manage the items is checked before anything is written
    my $item = $builder->build_sample_item;
    $t->put_ok(
        $url->( '/' . $own_display->display_id ) => json => {
            %{$received},
            display_name  => 'Written before the check',
            display_items => [
                {
                    itemnumber  => $item->itemnumber, biblionumber => $item->biblionumber, date_added => '2000-01-01',
                    date_remove => '2100-01-01'
                }
            ],
        }
    )->status_is(403);
    is(
        $own_display->get_from_storage->display_name, 'Round trip',
        'Nothing was written when the items permission was missing'
    );

    $t->delete_ok( $url->( '/' . $own_display->display_id ) )->status_is(204);

    # A user who can add displays only to their own library
    my $adder = $make_user->(qw( add_displays ));
    my $new   = {
        display_name        => 'New',
        display_days        => 7,
        display_return_over => 'no',
        start_date          => '2000-01-01',
        end_date            => '2100-01-01',
        enabled             => JSON::true,
        display_branch      => $foreign->branchcode,
    };
    $t->post_ok( "//$adder:$password@/api/v1/displays" => json => $new )->status_is(403);
    is( Koha::Displays->search( { display_name => 'New' } )->count, 0, 'Nothing was stored' );

    $schema->storage->txn_rollback;
};

subtest 'public embeds' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => {
                enabled        => 1,
                start_date     => '2000-01-01',
                end_date       => '2100-01-01',
                display_branch => $library->branchcode,
                staff_note     => 'Staff only',
                public_note    => 'For everyone',
            }
        }
    );

    $t->get_ok( '/api/v1/public/displays/' . $display->display_id => { 'x-koha-embed' => 'display_library' } )
        ->status_is(200)
        ->json_is( '/display_library/library_id' => $library->branchcode )
        ->json_hasnt( '/staff_note', 'staff_note is not exposed' )
        ->json_is( '/public_note' => 'For everyone' );

    # The embeds that were not safe for anonymous users are no longer accepted
    $t->get_ok( '/api/v1/public/displays/' . $display->display_id => { 'x-koha-embed' => 'display_items' } )
        ->status_is(400);
    $t->get_ok( '/api/v1/public/displays/' . $display->display_id => { 'x-koha-embed' => 'library' } )->status_is(400);

    $schema->storage->txn_rollback;
};
