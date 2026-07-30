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
use Test::More tests => 4;
use Test::Mojo;
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Item::BiblioLink;
use Koha::Item::BiblioLinks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth',        1 );
t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 1 );
t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue',   0 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 18;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    my $unauthorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $unauthorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $unauthorized_patron->userid;

    my $native_biblio = $builder->build_sample_biblio();
    my $linked_biblio = $builder->build_sample_biblio();
    my $item          = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );
    my $biblio_id     = $linked_biblio->biblionumber;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links")->status_is( 200, 'REST3.2.2' );
    is( scalar @{ $t->tx->res->json }, 0, 'No links yet' );

    my $link = Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $biblio_id,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );

    $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links")->status_is( 200, 'REST3.2.2' );
    is( scalar @{ $t->tx->res->json }, 1, 'One link returned' );

    my $json = $t->tx->res->json->[0];
    is( $json->{item_biblio_link_id}, $link->id,         'item_biblio_link_id is mapped' );
    is( $json->{item_id},             $item->itemnumber, 'item_id is mapped' );
    is( $json->{biblio_id},           $biblio_id,        'biblio_id is mapped' );
    is( $json->{link_type},           'binding',         'link_type is returned' );

    $t->get_ok(
        "//$userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => { 'x-koha-embed' => 'item,item.biblio' } )
        ->status_is( 200, 'REST3.2.2' );

    $json = $t->tx->res->json->[0];
    is( $json->{item}{item_id}, $item->itemnumber, 'item embed returns the linked item' );
    is(
        $json->{item}{biblio}{title}, $native_biblio->title,
        'item.biblio embed returns the record the item record lives on'
    );

    my $non_existent_biblio = $builder->build_sample_biblio();
    my $deleted_biblio_id   = $non_existent_biblio->biblionumber;
    $non_existent_biblio->delete;

    $t->get_ok("//$userid:$password@/api/v1/biblios/$deleted_biblio_id/item_biblio_links")->status_is(404);

    $t->get_ok("//$unauth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 25;

    $schema->storage->txn_begin;

    my $authorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $authorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $auth_userid = $authorized_patron->userid;

    my $unauthorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $unauthorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $unauthorized_patron->userid;

    my $catalogue_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 }
        }
    );
    $catalogue_patron->set_password( { password => $password, skip_validation => 1 } );
    my $catalogue_userid = $catalogue_patron->userid;

    my $native_biblio = $builder->build_sample_biblio();
    my $linked_biblio = $builder->build_sample_biblio();
    my $item          = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );
    my $biblio_id     = $linked_biblio->biblionumber;

    my $body = { item_id => $item->itemnumber, link_type => 'binding' };

    # Feature disabled
    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 0 );
    $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json => $body )
        ->status_is(400)
        ->json_is( '/error_code' => 'feature_disabled' );
    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 1 );

    # Unauthorized attempts
    $t->post_ok( "//$unauth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json => $body )
        ->status_is(403);
    $t->post_ok( "//$catalogue_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json => $body )
        ->status_is( 403, 'catalogue permission is not enough to create links' );

    # Authorized attempt
    $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json => $body )
        ->status_is( 201, 'REST3.2.1' )
        ->json_is( '/item_id'   => $item->itemnumber )
        ->json_is( '/biblio_id' => $biblio_id )
        ->json_is( '/link_type' => 'binding' );

    # Duplicate link
    warning_like {
        $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json => $body )
            ->status_is(409);
    }
    qr/Duplicate ID/, 'Duplicate link warns before the API returns 409';

    # Linking the item to its own record
    my $native_biblio_id = $native_biblio->biblionumber;
    $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$native_biblio_id/item_biblio_links" => json => $body )
        ->status_is(409);

    # Unknown item
    my $deleted_item    = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );
    my $deleted_item_id = $deleted_item->itemnumber;
    $deleted_item->delete( { skip_record_index => 1 } );
    warning_like {
        $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json =>
                { item_id => $deleted_item_id, link_type => 'binding' } )->status_is(409);
    }
    qr/Broken FK constraint/, 'Unknown item warns before the API returns 409';

    # Invalid link type
    $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links" => json =>
            { item_id => $item->itemnumber, link_type => 'not_a_link_type' } )
        ->status_is(400)
        ->json_is( '/error_code' => 'invalid_link_type' );

    # Unknown biblio
    my $non_existent_biblio = $builder->build_sample_biblio();
    my $deleted_biblio_id   = $non_existent_biblio->biblionumber;
    $non_existent_biblio->delete;
    $t->post_ok( "//$auth_userid:$password@/api/v1/biblios/$deleted_biblio_id/item_biblio_links" => json => $body )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $authorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
        }
    );
    my $password = 'thePassword123';
    $authorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $auth_userid = $authorized_patron->userid;

    my $unauthorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $unauthorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $unauthorized_patron->userid;

    my $native_biblio = $builder->build_sample_biblio();
    my $linked_biblio = $builder->build_sample_biblio();
    my $item          = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );
    my $biblio_id     = $linked_biblio->biblionumber;

    my $link = Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $biblio_id,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );
    my $link_id = $link->id;

    # Unauthorized attempt
    $t->delete_ok("//$unauth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links/$link_id")->status_is(403);

    # Unknown link
    my $non_existent_id = $link_id + 1000;
    $t->delete_ok("//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links/$non_existent_id")
        ->status_is(404);

    # Holds guard
    my $hold = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                biblionumber => $biblio_id,
                itemnumber   => $item->itemnumber,
                found        => undef,
            }
        }
    );

    $t->delete_ok("//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links/$link_id")
        ->status_is(409)
        ->json_is( '/error_code' => 'holds_exist' );

    # Forced removal
    $t->delete_ok("//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links/$link_id?force=1")
        ->status_is( 204, 'REST3.2.4' );

    # Plain removal without holds
    $hold->delete;
    $link = Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $biblio_id,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );
    $link_id = $link->id;

    $t->delete_ok("//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links/$link_id")
        ->status_is( 204, 'REST3.2.4' );

    $t->delete_ok("//$auth_userid:$password@/api/v1/biblios/$biblio_id/item_biblio_links/$link_id")->status_is(404);

    $schema->storage->txn_rollback;
};
