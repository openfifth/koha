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
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ILL::ISO18626::SupplyingAgencies;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';
my $patron   = sub {
    my ($flags) = @_;
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => $flags } } );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    return $patron->userid;
};

my $new_agency = {
    name         => 'Supplier',
    type         => 'ISIL',
    agency_id    => 'GB-SUP',
    account_id   => 'acc',
    securityCode => 'sec',
    endpoint     => 'https://supplier.example/api/v1/public/ill/iso18626',
};

subtest 'list() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    Koha::ILL::ISO18626::SupplyingAgencies->delete;

    my $librarian = $patron->( 2**22 );    # 22 => ill
    my $agency_1  = $builder->build_object( { class => 'Koha::ILL::ISO18626::SupplyingAgencies' } );
    my $agency_2  = $builder->build_object( { class => 'Koha::ILL::ISO18626::SupplyingAgencies' } );

    $t->get_ok("//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies")
        ->status_is(200)
        ->json_is( [ $agency_1->to_api, $agency_2->to_api ] );

    my $unauthorized = $patron->(0);
    $t->get_ok("//$unauthorized:$password@/api/v1/ill/iso18626_supplying_agencies")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $patron->( 2**22 );
    my $agency    = $builder->build_object( { class => 'Koha::ILL::ISO18626::SupplyingAgencies' } );
    my $id        = $agency->iso18626_supplying_agency_id;

    $t->get_ok("//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies/$id")
        ->status_is(200)
        ->json_is( $agency->to_api );

    $agency->delete;
    $t->get_ok("//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies/$id")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $librarian = $patron->( 2**22 );

    my $id =
        $t->post_ok( "//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies" => json => $new_agency )
        ->status_is(201)
        ->json_is( '/agency_id' => 'GB-SUP' )
        ->tx->res->json->{iso18626_supplying_agency_id};

    ok( Koha::ILL::ISO18626::SupplyingAgencies->find($id), 'Supplying agency stored' );

    warning_like {
        $t->post_ok( "//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies" => json => $new_agency )
            ->status_is(409);
    }
    qr/Duplicate ID/;

    my $unauthorized = $patron->(0);
    $t->post_ok( "//$unauthorized:$password@/api/v1/ill/iso18626_supplying_agencies" => json =>
            { %$new_agency, agency_id => 'GB-OTHER' } )->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $librarian = $patron->( 2**22 );
    my $agency    = $builder->build_object( { class => 'Koha::ILL::ISO18626::SupplyingAgencies' } );
    my $id        = $agency->iso18626_supplying_agency_id;

    $t->put_ok( "//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies/$id" => json => $new_agency )
        ->status_is(200)
        ->json_is( '/endpoint' => $new_agency->{endpoint} );

    $agency->delete;
    $t->put_ok( "//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies/$id" => json => $new_agency )
        ->status_is(404);

    is( Koha::ILL::ISO18626::SupplyingAgencies->search( { agency_id => 'GB-SUP' } )->count, 0, 'Nothing stored' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $patron->( 2**22 );
    my $agency    = $builder->build_object( { class => 'Koha::ILL::ISO18626::SupplyingAgencies' } );
    my $id        = $agency->iso18626_supplying_agency_id;

    my $unauthorized = $patron->(0);
    $t->delete_ok("//$unauthorized:$password@/api/v1/ill/iso18626_supplying_agencies/$id")->status_is(403);

    $t->delete_ok("//$librarian:$password@/api/v1/ill/iso18626_supplying_agencies/$id")->status_is(204);

    ok( !Koha::ILL::ISO18626::SupplyingAgencies->find($id), 'Supplying agency deleted' );

    $schema->storage->txn_rollback;
};
