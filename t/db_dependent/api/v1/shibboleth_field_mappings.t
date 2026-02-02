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

use Koha::ShibbolethFieldMappings;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ShibbolethFieldMappings->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    $t->get_ok("//$userid:$password@/api/v1/shibboleth/mappings")->status_is(200)->json_is( [] );

    my $mapping = $builder->build_object( { class => 'Koha::ShibbolethFieldMappings' } );

    $t->get_ok("//$userid:$password@/api/v1/shibboleth/mappings")->status_is(200)->json_is( [ $mapping->to_api ] );

    my $another_mapping = $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => { idp_field => 'eppn', koha_field => 'userid' }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/shibboleth/mappings")->status_is(200)->json_is(
        [
            $mapping->to_api,
            $another_mapping->to_api,
        ]
    );

    $mapping->delete;
    $another_mapping->delete;
    $t->get_ok(qq~//$userid:$password@/api/v1/shibboleth/mappings?q=[{"me.koha_field":{"like":"%user%"}}]~)
        ->status_is(200)->json_is( [] );

    my $mapping_to_search = $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => {
                koha_field => 'userid',
            }
        }
    );

    $t->get_ok(qq~//$userid:$password@/api/v1/shibboleth/mappings?q=[{"me.koha_field":{"like":"%user%"}}]~)
        ->status_is(200)->json_is( [ $mapping_to_search->to_api ] );

    $t->get_ok("//$userid:$password@/api/v1/shibboleth/mappings?blah=blah")->status_is(400)
        ->json_is( [ { path => '/query/blah', message => 'Malformed query string' } ] );

    $t->get_ok("//$unauth_userid:$password@/api/v1/shibboleth/mappings")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $mapping   = $builder->build_object( { class => 'Koha::ShibbolethFieldMappings' } );
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    $t->get_ok( "//$userid:$password@/api/v1/shibboleth/mappings/" . $mapping->mapping_id )->status_is(200)
        ->json_is( $mapping->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/shibboleth/mappings/" . $mapping->mapping_id )->status_is(403);

    my $mapping_to_delete = $builder->build_object( { class => 'Koha::ShibbolethFieldMappings' } );
    my $non_existent_id   = $mapping_to_delete->mapping_id;
    $mapping_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/shibboleth/mappings/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'Mapping not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 19;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    my $mapping = {
        idp_field     => "mail",
        koha_field    => "email",
        is_matchpoint => 0,
    };

    $t->post_ok( "//$unauth_userid:$password@/api/v1/shibboleth/mappings" => json => $mapping )->status_is(403);

    my $mapping_with_invalid_field = {
        blah          => "Mapping Blah",
        idp_field     => "mail",
        koha_field    => "email",
        is_matchpoint => 0,
    };

    $t->post_ok( "//$userid:$password@/api/v1/shibboleth/mappings" => json => $mapping_with_invalid_field )
        ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
        );

    my $mapping_id =
        $t->post_ok( "//$userid:$password@/api/v1/shibboleth/mappings" => json => $mapping )
        ->status_is( 201, 'REST3.2.1' )->header_like(
        Location => qr|^/api/v1/shibboleth/mappings/\d*|,
        'REST3.4.1'
    )->json_is( '/idp_field' => $mapping->{idp_field} )->json_is( '/koha_field' => $mapping->{koha_field} )
        ->tx->res->json->{mapping_id};

    $mapping->{mapping_id} = undef;
    $t->post_ok( "//$userid:$password@/api/v1/shibboleth/mappings" => json => $mapping )->status_is(400)
        ->json_has('/errors');

    $mapping->{mapping_id} = $mapping_id;

    $t->post_ok( "//$userid:$password@/api/v1/shibboleth/mappings" => json => $mapping )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/mapping_id"
            }
        ]
    );

    my $mapping_without_idp_or_default = {
        koha_field    => "phonepro",
        is_matchpoint => 0,
    };

    $t->post_ok( "//$userid:$password@/api/v1/shibboleth/mappings" => json => $mapping_without_idp_or_default )
        ->status_is(400)->json_is( "/error" => "Either idp_field or default_content must be provided" );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    my $mapping_id = $builder->build_object( { class => 'Koha::ShibbolethFieldMappings' } )->mapping_id;

    $t->put_ok( "//$unauth_userid:$password@/api/v1/shibboleth/mappings/$mapping_id" => json =>
            { idp_field => 'New unauthorized name change' } )->status_is(403);

    my $mapping_without_idp_or_default = {
        koha_field      => 'surname',
        idp_field       => undef,
        default_content => undef,
        is_matchpoint   => 0,
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/shibboleth/mappings/$mapping_id" => json => $mapping_without_idp_or_default )
        ->status_is(400)->json_is( "/error" => "Either idp_field or default_content must be provided" );

    my $mapping_with_updated_field = {
        idp_field     => "sn",
        koha_field    => "surname",
        is_matchpoint => 0,
    };

    $t->put_ok( "//$userid:$password@/api/v1/shibboleth/mappings/$mapping_id" => json => $mapping_with_updated_field )
        ->status_is(200)->json_is( '/idp_field' => 'sn' );

    my $mapping_with_invalid_field = {
        blah          => "Mapping Blah",
        idp_field     => "sn",
        koha_field    => "surname",
        is_matchpoint => 0,
    };

    $t->put_ok( "//$userid:$password@/api/v1/shibboleth/mappings/$mapping_id" => json => $mapping_with_invalid_field )
        ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
        );

    my $mapping_to_delete = $builder->build_object( { class => 'Koha::ShibbolethFieldMappings' } );
    my $non_existent_id   = $mapping_to_delete->mapping_id;
    $mapping_to_delete->delete;

    $t->put_ok(
        "//$userid:$password@/api/v1/shibboleth/mappings/$non_existent_id" => json => $mapping_with_updated_field )
        ->status_is(404);

    $mapping_with_updated_field->{mapping_id} = 2;

    $t->post_ok( "//$userid:$password@/api/v1/shibboleth/mappings/$mapping_id" => json => $mapping_with_updated_field )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    my $mapping_id = $builder->build_object( { class => 'Koha::ShibbolethFieldMappings' } )->mapping_id;

    $t->delete_ok("//$unauth_userid:$password@/api/v1/shibboleth/mappings/$mapping_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/shibboleth/mappings/$mapping_id")->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/shibboleth/mappings/$mapping_id")->status_is(404);

    $schema->storage->txn_rollback;
};
