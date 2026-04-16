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
use Test::More tests => 10;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::Finances::Allocations;
use Koha::Acquisition::Finances::Funds;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::Finances::Funds->search->delete;

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

    # No funds, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/funds")->status_is(200)->json_is( [] );

    my $fund = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );

    # One fund created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/funds")->status_is(200)->json_is( [ $fund->to_api ] );

    my $another_fund = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );

    # Two funds, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/funds")->status_is(200)->json_is(
        [
            $fund->to_api,
            $another_fund->to_api
        ]
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/funds")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $fund      = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
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

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/funds/" . $fund->fund_id )
        ->status_is(200)
        ->json_is( $fund->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/funds/" . $fund->fund_id )->status_is(403);

    my $fund_to_delete  = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    my $non_existent_id = $fund_to_delete->fund_id;
    $fund_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/funds/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Fund not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 10;

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

    # Create an unlocked ledger with a large amount to ensure fund amount stays within limit
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 100000, locked => 0 }
        }
    );
    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    my $fund = {
        name             => 'Test Fund',
        ledger_id        => $ledger->ledger_id,
        fiscal_period_id => $fiscal_period->fiscal_period_id,
        fund_amount      => 1000,
        status           => Mojo::JSON->true,
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/funds" => json => $fund )->status_is(403);

    # Authorized attempt to write
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/funds" => json => $fund )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/funds\/\d+|, 'REST3.4.1' )
        ->json_is( '/name'             => $fund->{name} )
        ->json_is( '/ledger_id'        => $fund->{ledger_id} )
        ->json_is( '/fiscal_period_id' => $fund->{fiscal_period_id} );

    my $created_fund_id    = $t->tx->res->json->{fund_id};
    my $initial_allocation = Koha::Acquisition::Finances::Allocations->search(
        { fund_id => $created_fund_id, type => 'initial' }
    )->single;
    ok( $initial_allocation, 'Initial allocation was created for new fund' );
    cmp_ok( $initial_allocation->allocation_amount, '==', $fund->{fund_amount}, 'Initial allocation amount matches fund amount' );

    $schema->storage->txn_rollback;
};

subtest 'add() with amount breach tests' => sub {

    plan tests => 5;

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

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 100, locked => 0 }
        }
    );
    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    my $fund_exceeding_limit = {
        name             => 'Overfunded',
        ledger_id        => $ledger->ledger_id,
        fiscal_period_id => $fiscal_period->fiscal_period_id,
        fund_amount      => 99999,
        status           => Mojo::JSON->true,
    };

    # Adding a fund that exceeds the ledger amount should return 400 with breach details
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/funds" => json => $fund_exceeding_limit )
        ->status_is(400)
        ->json_is( '/error'                => 'Amount has been breached' )
        ->json_is( '/result/within_limit'  => 0 )
        ->json_is( '/result/breach_amount' => 99899 );

    $schema->storage->txn_rollback;
};

subtest 'add() sub-fund with amount breach tests' => sub {

    plan tests => 5;

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

    # Create an unlocked ledger and a parent fund with a small amount
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { locked => 0 }
        }
    );
    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_amount => 200, ledger_id => $ledger->ledger_id }
        }
    );

    my $sub_fund_exceeding_limit = {
        name             => 'Overfunded Sub Fund',
        ledger_id        => $parent_fund->ledger_id,
        parent_fund_id   => $parent_fund->fund_id,
        fiscal_period_id => $parent_fund->fiscal_period_id,
        fund_amount      => 99999,
        status           => Mojo::JSON->true,
    };

    # Adding a sub-fund that exceeds the parent fund amount should return 400 with breach details
    # breach_amount = sub_fund_amount (99999) - parent_fund_amount (200) = 99799
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/funds" => json => $sub_fund_exceeding_limit )
        ->status_is(400)
        ->json_is( '/error'                => 'Amount has been breached' )
        ->json_is( '/result/within_limit'  => 0 )
        ->json_is( '/result/breach_amount' => 99799 );

    $schema->storage->txn_rollback;
};

subtest 'add() with locked ledger tests' => sub {

    plan tests => 3;

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

    my $locked_ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 10000, locked => 1 }
        }
    );
    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    my $fund = {
        name             => 'Test Fund',
        ledger_id        => $locked_ledger->ledger_id,
        fiscal_period_id => $fiscal_period->fiscal_period_id,
        fund_amount      => 1000,
        status           => Mojo::JSON->true,
    };

    # Adding a fund to a locked ledger should return 400
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/funds" => json => $fund )
        ->status_is(400)
        ->json_is( '/error' => 'Ledger is locked' );

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

    my $ledger  = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { locked => 0 }
        }
    );
    my $fund    = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger->ledger_id }
        }
    );
    my $fund_id = $fund->fund_id;

    my $updated_fund = {
        name             => 'Updated Fund',
        ledger_id        => $ledger->ledger_id,
        fiscal_period_id => $fund->fiscal_period_id,
        fund_amount      => 7500,
        status           => Mojo::JSON->true,
    };

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/funds/$fund_id" => json => $updated_fund )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/funds/$fund_id" => json => $updated_fund )
        ->status_is(200)
        ->json_is( '/name' => 'Updated Fund' );

    my $fund_to_delete  = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    my $non_existent_id = $fund_to_delete->fund_id;
    $fund_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/funds/$non_existent_id" => json => $updated_fund )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'update() with locked ledger tests' => sub {

    plan tests => 3;

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

    my $locked_ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { locked => 1 }
        }
    );
    my $fund    = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $locked_ledger->ledger_id }
        }
    );
    my $fund_id = $fund->fund_id;

    my $updated_fund = {
        name             => 'Updated Fund',
        ledger_id        => $locked_ledger->ledger_id,
        fiscal_period_id => $fund->fiscal_period_id,
        fund_amount      => 1000,
        status           => Mojo::JSON->true,
    };

    # Updating a fund under a locked ledger should return 400
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/funds/$fund_id" => json => $updated_fund )
        ->status_is(400)
        ->json_is( '/error' => 'Ledger is locked' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 10;

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

    my $fund    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    my $fund_id = $fund->fund_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/funds/$fund_id")->status_is(403);

    # Attempt to delete a fund that has sub funds should return 400
    my $parent_fund = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { parent_fund_id => $parent_fund->fund_id }
        }
    );
    $t->delete_ok( "//$userid:$password@/api/v1/acquisitions/funds/" . $parent_fund->fund_id )
        ->status_is(400)
        ->json_is( '/error' => 'Fund has sub funds' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/funds/$fund_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/funds/$fund_id")->status_is(404);

    $schema->storage->txn_rollback;
};
