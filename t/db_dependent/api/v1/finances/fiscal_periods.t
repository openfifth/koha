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

use Koha::Acquisition::Finances::FiscalPeriods;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::Finances::FiscalPeriods->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
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

    # No fiscal periods, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(200)->json_is( [] );

    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    # One fiscal period created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods")
        ->status_is(200)
        ->json_is( [ $fiscal_period->to_api ] );

    my $another_fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    # Two fiscal periods, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(200)->json_is(
        [
            $fiscal_period->to_api,
            $another_fiscal_period->to_api
        ]
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );
    my $librarian     = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
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

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods/" . $fiscal_period->fiscal_period_id )
        ->status_is(200)
        ->json_is( $fiscal_period->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods/" . $fiscal_period->fiscal_period_id )
        ->status_is(403);

    my $fiscal_period_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );
    my $non_existent_id         = $fiscal_period_to_delete->fiscal_period_id;
    $fiscal_period_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Fiscal period not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
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

    my $fiscal_period = {
        name       => 'Test Fiscal Period',
        start_date => '2024-01-01',
        end_date   => '2024-12-31',
        status     => Mojo::JSON->true,
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period )
        ->status_is(403);

    # Authorized attempt to write
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/fiscal_periods\/\d+|, 'REST3.4.1' )
        ->json_is( '/name'       => $fiscal_period->{name} )
        ->json_is( '/start_date' => $fiscal_period->{start_date} )
        ->json_is( '/end_date'   => $fiscal_period->{end_date} );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
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

    my $fiscal_period    = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );
    my $fiscal_period_id = $fiscal_period->fiscal_period_id;

    my $updated_fiscal_period = {
        name       => 'Updated Fiscal Period',
        start_date => '2024-01-01',
        end_date   => '2024-12-31',
        status     => Mojo::JSON->true,
    };

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id" => json =>
            $updated_fiscal_period )->status_is(403);

    # Authorized update
    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id" => json => $updated_fiscal_period )
        ->status_is(200)
        ->json_is( '/name' => 'Updated Fiscal Period' );

    my $fiscal_period_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );
    my $non_existent_id         = $fiscal_period_to_delete->fiscal_period_id;
    $fiscal_period_to_delete->delete;

    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/fiscal_periods/$non_existent_id" => json => $updated_fiscal_period )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
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

    my $fiscal_period_id =
        $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } )->fiscal_period_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id")->status_is(404);

    $schema->storage->txn_rollback;
};
