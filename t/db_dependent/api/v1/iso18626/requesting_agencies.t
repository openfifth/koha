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

use Test::MockModule;
use Test::MockObject;
use Test::Mojo;

use MIME::Base64 qw(encode_base64);
use JSON         qw(encode_json);

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ILL::ISO18626::RequestingAgencies;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    # create an authorized user
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**22 }    # 22 => ill
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $requesting_agency_1 = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::RequestingAgencies',
        }
    );

    my $requesting_agency_2 = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::RequestingAgencies',
        }
    );

    # Two requesting agencies created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/ill/iso18626_requesting_agencies")->status_is(200)->json_is(
        [
            $requesting_agency_1->to_api,
            $requesting_agency_2->to_api,
        ]
    );

    $t->get_ok( "//$userid:$password@/api/v1/ill/iso18626_requesting_agencies/"
            . $requesting_agency_1->iso18626_requesting_agency_id )->status_is(200)->json_is(
        $requesting_agency_1->to_api,
            );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**22 } } );    # 22 => ill
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $requesting_agency = $builder->build_object( { class => 'Koha::ILL::ISO18626::RequestingAgencies' } );
    my $id                = $requesting_agency->iso18626_requesting_agency_id;

    my $body = $requesting_agency->to_api;
    delete $body->{iso18626_requesting_agency_id};
    $body->{name} = 'New name';

    $t->put_ok( "//$unauth_userid:$password@/api/v1/ill/iso18626_requesting_agencies/$id" => json => $body )
        ->status_is(403);

    $t->put_ok( "//$userid:$password@/api/v1/ill/iso18626_requesting_agencies/$id" => json => $body )
        ->status_is(200)
        ->json_is( '/name' => 'New name' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**22 } } );    # 22 => ill
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $requesting_agency = $builder->build_object( { class => 'Koha::ILL::ISO18626::RequestingAgencies' } );
    my $id                = $requesting_agency->iso18626_requesting_agency_id;

    $t->delete_ok("//$unauth_userid:$password@/api/v1/ill/iso18626_requesting_agencies/$id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/ill/iso18626_requesting_agencies/$id")->status_is(204);

    ok( !Koha::ILL::ISO18626::RequestingAgencies->find($id), 'Requesting agency deleted' );

    $schema->storage->txn_rollback;
};
