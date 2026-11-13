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
use Test::More tests => 8;
use Test::Mojo;
use JSON;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Display::Items;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::Display::Items->search->delete;

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
    # No displayitems, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/display/items")->status_is(200)->json_is( [] );

    # Create test data
    my $display = $builder->build_object( { class => 'Koha::Displays' } );
    my $biblio  = $builder->build_sample_biblio();
    my $item    = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    my $displayitem = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );

    # One displayitem created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/display/items")->status_is(200)->json_is( [ $displayitem->to_api ] );

    # Create another displayitem with same display
    my $item2               = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    my $another_displayitem = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display->display_id,
                itemnumber   => $item2->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );

    # Create displayitem with different display
    my $display2                      = $builder->build_object( { class => 'Koha::Displays' } );
    my $item3                         = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    my $displayitem_different_display = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display2->display_id,
                itemnumber   => $item3->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );

    # Three displayitems created, they should all be returned
    $t->get_ok("//$userid:$password@/api/v1/display/items")->status_is(200)->json_is(
        [
            $displayitem->to_api,
            $another_displayitem->to_api,
            $displayitem_different_display->to_api
        ]
    );

    # Filtering works, two displayitems sharing display_id
    $t->get_ok( "//$userid:$password@/api/v1/display/items?display_id=" . $display->display_id )
        ->status_is(200)
        ->json_is(
        [
            $displayitem->to_api,
            $another_displayitem->to_api
        ]
        );

    $t->get_ok( "//$userid:$password@/api/v1/display/items?itemnumber=" . $item->itemnumber )
        ->status_is(200)
        ->json_is( [ $displayitem->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/display/items?displayitem_blah=blah")
        ->status_is(400)
        ->json_is( [ { path => '/query/displayitem_blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/display/items")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    # Create test data
    my $display = $builder->build_object( { class => 'Koha::Displays' } );
    my $biblio  = $builder->build_sample_biblio();
    my $item    = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    my $displayitem = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );

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

    $t->get_ok(
        "//$userid:$password@/api/v1/display/items/" . $displayitem->display_id . "/" . $displayitem->itemnumber )
        ->status_is(200)
        ->json_is( $displayitem->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber )->status_is(403);

    # Create displayitem to delete
    my $item_to_delete        = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    my $displayitem_to_delete = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display->display_id,
                itemnumber   => $item_to_delete->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );
    my $non_existent_display_id = $displayitem_to_delete->display_id;
    my $non_existent_item_id    = $displayitem_to_delete->itemnumber;
    $displayitem_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/display/items/$non_existent_display_id/$non_existent_item_id")
        ->status_is(404)
        ->json_is( '/error' => 'Display item not found' );

    # Test with completely non-existent IDs
    $t->get_ok("//$userid:$password@/api/v1/display/items/99999/99999")
        ->status_is(404)
        ->json_is( '/error' => 'Display item not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 27;

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

    # Create test data
    my $display = $builder->build_object( { class => 'Koha::Displays' } );
    my $biblio  = $builder->build_sample_biblio();
    my $item    = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    my $displayitem = {
        display_id   => $display->display_id,
        itemnumber   => $item->itemnumber,
        biblionumber => $biblio->biblionumber,
        date_added   => "2024-01-15",
        date_remove  => "2024-02-15"
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/display/items" => json => $displayitem )->status_is(403);

    # Authorized attempt to write invalid data
    my $displayitem_with_invalid_field = {
        blah         => "DisplayItem Blah",
        display_id   => $display->display_id,
        itemnumber   => $item->itemnumber,
        biblionumber => $biblio->biblionumber
    };

    $t->post_ok( "//$userid:$password@/api/v1/display/items" => json => $displayitem_with_invalid_field )
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
    $t->post_ok( "//$userid:$password@/api/v1/display/items" => json => $displayitem )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like(
        Location => qr|^\/api\/v1\/display/items/\d+/\d+|,
        'REST3.4.1'
        )
        ->json_is( '/display_id'   => $displayitem->{display_id} )
        ->json_is( '/itemnumber'   => $displayitem->{itemnumber} )
        ->json_is( '/biblionumber' => $displayitem->{biblionumber} )
        ->json_is( '/date_added'   => $displayitem->{date_added} );

    # Test missing required field (display_id is required)
    my $displayitem_missing_field = {
        itemnumber   => $item->itemnumber,
        biblionumber => $biblio->biblionumber

        # Missing display_id (required field)
    };

    $t->post_ok( "//$userid:$password@/api/v1/display/items" => json => $displayitem_missing_field )
        ->status_is(400)
        ->json_has('/errors');

    # A display item the model declines to store must not report success
    my $item_unstored = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    $t->post_ok(
        "//$userid:$password@/api/v1/display/items" => json => {
            display_id   => $display->display_id,
            itemnumber   => $item_unstored->itemnumber,
            biblionumber => $biblio->biblionumber,
            date_added   => "2024-03-01",
            date_remove  => "2024-02-01",                 # before date_added
        }
    )->status_is(400)->json_is( '/error_code' => 'bad_parameter' );
    is(
        Koha::Display::Items->search( { itemnumber => $item_unstored->itemnumber } )->count, 0,
        'Nothing was stored'
    );

    # Unknown item and unknown display are client errors, not server errors
    $t->post_ok(
        "//$userid:$password@/api/v1/display/items" => json => {
            display_id   => $display->display_id,
            itemnumber   => 999999999,
            biblionumber => $biblio->biblionumber,
            date_added   => "2024-03-01",
            date_remove  => "2024-04-01",
        }
    )->status_is(400)->json_is( '/error_code' => 'bad_parameter' );
    $t->post_ok(
        "//$userid:$password@/api/v1/display/items" => json => {
            display_id   => 999999999,
            itemnumber   => $item_unstored->itemnumber,
            biblionumber => $biblio->biblionumber,
            date_added   => "2024-03-01",
            date_remove  => "2024-04-01",
        }
    )->status_is(400)->json_is( '/error_code' => 'bad_parameter' );

    # Test successful creation with different item
    my $item2        = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );
    my $displayitem2 = {
        display_id   => $display->display_id,
        itemnumber   => $item2->itemnumber,
        biblionumber => $biblio->biblionumber,
        date_added   => "2024-01-16",
        date_remove  => "2024-02-16"
    };
    $t->post_ok( "//$userid:$password@/api/v1/display/items" => json => $displayitem2 )->status_is(201);

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

    # Create test data
    my $display = $builder->build_object( { class => 'Koha::Displays' } );
    my $biblio  = $builder->build_sample_biblio();
    my $item    = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    my $displayitem = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber => json => { date_added => '2024-01-20' } )->status_is(403);

    # Attempt partial update on a PUT (missing required field)
    my $displayitem_with_missing_field = {
        biblionumber => $biblio->biblionumber

            # Missing display_id and itemnumber (required fields)
    };

    $t->put_ok( "//$userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber => json => $displayitem_with_missing_field )
        ->status_is(400)
        ->json_has("/errors");

    # Full object update on PUT
    my $displayitem_with_updated_field = {
        display_id   => $display->display_id,
        itemnumber   => $item->itemnumber,
        biblionumber => $biblio->biblionumber,
        date_added   => "2024-01-20",
        date_remove  => "2024-03-20"
    };

    $t->put_ok( "//$userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber => json => $displayitem_with_updated_field )
        ->status_is(200)
        ->json_is( '/date_added' => '2024-01-20' );

    # Authorized attempt to write invalid data
    my $displayitem_with_invalid_field = {
        blah         => "DisplayItem Blah",
        display_id   => $display->display_id,
        itemnumber   => $item->itemnumber,
        biblionumber => $biblio->biblionumber
    };

    $t->put_ok( "//$userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber => json => $displayitem_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
            );

    # Test with non-existent displayitem
    $t->put_ok( "//$userid:$password@/api/v1/display/items/99999/99999" => json => $displayitem_with_updated_field )
        ->status_is(404);

    # Wrong method (POST)
    $t->post_ok( "//$userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber => json => $displayitem_with_updated_field )->status_is(404);

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

    # Create test data
    my $display = $builder->build_object( { class => 'Koha::Displays' } );
    my $biblio  = $builder->build_sample_biblio();
    my $item    = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    my $displayitem = $builder->build_object(
        {
            class => 'Koha::Display::Items',

            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $biblio->biblionumber
            }
        }
    );

    # Unauthorized attempt to delete
    $t->delete_ok( "//$unauth_userid:$password@/api/v1/display/items/"
            . $displayitem->display_id . "/"
            . $displayitem->itemnumber )->status_is(403);

    $t->delete_ok(
        "//$userid:$password@/api/v1/display/items/" . $displayitem->display_id . "/" . $displayitem->itemnumber )
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok(
        "//$userid:$password@/api/v1/display/items/" . $displayitem->display_id . "/" . $displayitem->itemnumber )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'batch_add() and batch_delete() barcodes' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**34 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $display = $builder->build_object( { class => 'Koha::Displays' } );

    # Barcodes are strings and may contain letters
    $t->post_ok(
        "//$userid:$password@/api/v1/display/items/batch" => json => {
            display_id => $display->display_id,
            barcodes   => [ 'ABC123', '0012345' ],
        }
    )->status_is(202);

    $t->delete_ok(
        "//$userid:$password@/api/v1/display/items/batch" => json => {
            barcodes => [ 'ABC123', '0012345' ],
        }
    )->status_is(202);

    $t->post_ok(
        "//$userid:$password@/api/v1/display/items/batch" => json => {
            display_id => $display->display_id,
            barcodes   => [],
        }
    )->status_is(400);

    $schema->storage->txn_rollback;
};

subtest 'list_public() and get_public() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );
    t::lib::Mocks::mock_preference( 'OpacSuppression',  1 );
    t::lib::Mocks::mock_preference( 'OpacHiddenItems',  'withdrawn: [1]' );
    t::lib::Mocks::mock_preference( 'hidelostitems',    0 );

    my $display = $builder->build_object(
        {
            class => 'Koha::Displays',
            value => { enabled => 1, start_date => '2000-01-01', end_date => '2100-01-01' },
        }
    );

    my $make = sub {
        my ( $item_params, $suppress ) = @_;
        my $biblio = $builder->build_sample_biblio;
        $biblio->opac_suppressed(1)->store if $suppress;
        my $item = $builder->build_sample_item( { biblionumber => $biblio->biblionumber, %{ $item_params // {} } } );
        $builder->build_object(
            {
                class => 'Koha::Display::Items',
                value => {
                    display_id   => $display->display_id,
                    itemnumber   => $item->itemnumber,
                    biblionumber => $biblio->biblionumber,
                    date_added   => '2000-01-01',
                    date_remove  => '2100-01-01',
                },
            }
        );
        return $item;
    };

    my $visible1   = $make->();
    my $visible2   = $make->();
    my $hidden     = $make->( { withdrawn => 1 } );
    my $suppressed = $make->( undef, 1 );

    $t->get_ok( '/api/v1/public/display/items?display_id=' . $display->display_id )
        ->status_is(200)
        ->json_has( '/0', 'there is a first result' );

    my $returned = $t->tx->res->json;
    is_deeply(
        [ sort map { $_->{itemnumber} } @{$returned} ],
        [ sort $visible1->itemnumber, $visible2->itemnumber ],
        'Items hidden by OpacHiddenItems or on suppressed records are not returned'
    );

    $t->get_ok( '/api/v1/public/display/items?_per_page=1&display_id=' . $display->display_id )->status_is(200);
    is( scalar @{ $t->tx->res->json }, 1, 'Public list is paginated' );

    $t->get_ok( '/api/v1/public/display/items/' . $display->display_id . '/' . $visible1->itemnumber )->status_is(200);
    $t->get_ok( '/api/v1/public/display/items/' . $display->display_id . '/' . $hidden->itemnumber )->status_is(404);

    $schema->storage->txn_rollback;
};
