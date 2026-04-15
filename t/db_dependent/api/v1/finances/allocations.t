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
use Test::More tests => 8;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::Finances::Allocations;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::Finances::Allocations->search->delete;

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

    # No allocations, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/allocations")->status_is(200)->json_is( [] );

    my $allocation = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );

    # One allocation created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/allocations")
        ->status_is(200)
        ->json_is( [ $allocation->to_api ] );

    my $another_allocation = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );

    # Two allocations, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/allocations")->status_is(200)->json_is(
        [
            $allocation->to_api,
            $another_allocation->to_api
        ]
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/allocations")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $allocation = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );
    my $librarian  = $builder->build_object(
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

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/allocations/" . $allocation->allocation_id )
        ->status_is(200)
        ->json_is( $allocation->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/allocations/" . $allocation->allocation_id )
        ->status_is(403);

    my $allocation_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );
    my $non_existent_id      = $allocation_to_delete->allocation_id;
    $allocation_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/allocations/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Allocation not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() to ledger tests' => sub {

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

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 10000 }
        }
    );

    my $allocation = {
        ledger_id         => $ledger->ledger_id,
        allocation_amount => 1000,
        type              => 'increase',
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/allocations" => json => $allocation )->status_is(403);

    # Authorized attempt to write
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/allocations" => json => $allocation )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/allocations\/\d+|, 'REST3.4.1' )
        ->json_is( '/ledger_id'         => $allocation->{ledger_id} )
        ->json_is( '/allocation_amount' => $allocation->{allocation_amount} )
        ->json_is( '/type'              => $allocation->{type} );

    $schema->storage->txn_rollback;
};

subtest 'add() to fund tests' => sub {

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

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 10000 }
        }
    );
    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger->ledger_id, fund_amount => 0, fund_parent_id => undef }
        }
    );

    my $allocation = {
        fund_id           => $fund->fund_id,
        allocation_amount => 1000,
        type              => 'increase',
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/allocations" => json => $allocation )->status_is(403);

    # Authorized attempt to write
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/allocations" => json => $allocation )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/allocations\/\d+|, 'REST3.4.1' )
        ->json_is( '/fund_id'           => $allocation->{fund_id} )
        ->json_is( '/allocation_amount' => $allocation->{allocation_amount} )
        ->json_is( '/type'              => $allocation->{type} );

    $schema->storage->txn_rollback;
};

subtest 'add() transfer between funds tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::Finances::Allocations->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    # Source fund: decrease has no capacity check, so ledger_amount doesn't matter here
    my $source_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_amount => 5000, fund_parent_id => undef }
        }
    );

    # Destination fund: increase triggers a capacity check, so its ledger needs room
    my $dest_ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 10000 }
        }
    );
    my $dest_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $dest_ledger->ledger_id, fund_amount => 0, fund_parent_id => undef }
        }
    );

    my $transfer = {
        fund_id           => $source_fund->fund_id,
        is_transferred_to => $dest_fund->fund_id,
        allocation_amount => 500,
        type              => 'transfer',
    };

    # Transfer creates two allocations: one decreasing the source, one increasing the destination
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/allocations" => json => $transfer )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/allocations\/\d+|, 'REST3.4.1' )
        ->json_is( '/fund_id'           => $source_fund->fund_id )
        ->json_is( '/type'              => 'transfer' )
        ->json_is( '/is_transferred_to' => $dest_fund->fund_id )
        ->json_is( '/allocation_amount' => 500 );

    # Verify the mirror allocation was created for the destination fund
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/allocations")
        ->status_is(200)
        ->json_is( '/1/fund_id'             => $dest_fund->fund_id )
        ->json_is( '/1/is_transferred_from' => $source_fund->fund_id );

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

    my $allocation    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );
    my $allocation_id = $allocation->allocation_id;

    my $updated_allocation = {
        allocation_amount => 2500,
        type              => 'increase',
        reference         => 'Updated reference',
    };

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/acquisitions/allocations/$allocation_id" => json => $updated_allocation )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/allocations/$allocation_id" => json => $updated_allocation )
        ->status_is(200)
        ->json_is( '/allocation_amount' => 2500 );

    my $allocation_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );
    my $non_existent_id      = $allocation_to_delete->allocation_id;
    $allocation_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/allocations/$non_existent_id" => json => $updated_allocation )
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

    my $allocation_id =
        $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } )->allocation_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/allocations/$allocation_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/allocations/$allocation_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/allocations/$allocation_id")->status_is(404);

    $schema->storage->txn_rollback;
};
