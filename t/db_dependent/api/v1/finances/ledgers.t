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
use Test::More tests => 7;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::Finances::Allocations;
use Koha::Acquisition::Finances::Funds;
use Koha::Acquisition::Finances::Ledgers;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::Finances::Ledgers->search->delete;

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

    # No ledgers, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is( [] );

    my $ledger = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );

    # One ledger created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is( [ $ledger->to_api ] );

    my $another_ledger = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );

    # Two ledgers, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is(
        [
            $ledger->to_api,
            $another_ledger->to_api
        ]
    );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/ledgers")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $ledger    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
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

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/" . $ledger->ledger_id )
        ->status_is(200)
        ->json_is( $ledger->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers/" . $ledger->ledger_id )->status_is(403);

    my $ledger_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $non_existent_id  = $ledger_to_delete->ledger_id;
    $ledger_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Ledger not found' );

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

    my $ledger = {
        name          => 'Test Ledger',
        currency      => 'GBP',
        ledger_amount => 10000,
        status        => Mojo::JSON->true,
        locked        => Mojo::JSON->false,
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers" => json => $ledger )->status_is(403);

    # Authorized attempt to write
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers" => json => $ledger )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/ledgers\/\d+|, 'REST3.4.1' )
        ->json_is( '/name'          => $ledger->{name} )
        ->json_is( '/currency'      => $ledger->{currency} )
        ->json_is( '/ledger_amount' => $ledger->{ledger_amount} );

    my $created_ledger_id = $t->tx->res->json->{ledger_id};
    my $initial_allocation =
        Koha::Acquisition::Finances::Allocations->search( { ledger_id => $created_ledger_id, type => 'initial' } )
        ->single;
    ok( $initial_allocation, 'Initial allocation was created for new ledger' );
    cmp_ok(
        $initial_allocation->allocation_amount, '==', $ledger->{ledger_amount},
        'Initial allocation amount matches ledger amount'
    );

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

    my $ledger    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $ledger_id = $ledger->ledger_id;

    my $updated_ledger = {
        name          => 'Updated Ledger',
        currency      => 'EUR',
        ledger_amount => 20000,
        status        => Mojo::JSON->true,
        locked        => Mojo::JSON->false,
    };

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $updated_ledger )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $updated_ledger )
        ->status_is(200)
        ->json_is( '/name' => 'Updated Ledger' );

    my $ledger_to_delete = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $non_existent_id  = $ledger_to_delete->ledger_id;
    $ledger_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$non_existent_id" => json => $updated_ledger )
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

    my $ledger_id = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } )->ledger_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'rollover() tests' => sub {

    plan tests => 34;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }
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

    my $new_fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    my $base_body = {
        fiscal_period_id => $new_fiscal_period->fiscal_period_id,
        name             => 'Rolled Over Ledger',
        status           => Mojo::JSON->true,
        locked           => Mojo::JSON->false,
    };

    # Unauthorized access
    my $ledger1 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 10000, currency => 'GBP', status => 1, locked => 0 }
        }
    );

    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/ledgers/"
            . $ledger1->ledger_id
            . "/rollover" => json => { %$base_body, ledger_amount => $ledger1->ledger_amount } )->status_is(403);

    # Ledger not found
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/99999999/rollover" => json =>
            { %$base_body, ledger_amount => 1000 } )->status_is(404)->json_is( '/error' => 'Ledger not found' );

    # Basic rollover — funds copied with original amounts, original ledger deactivated
    my $fund1 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger1->ledger_id, parent_fund_id => undef, fund_amount => 5000 }
        }
    );

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/"
            . $ledger1->ledger_id
            . "/rollover" => json => { %$base_body, ledger_amount => $ledger1->ledger_amount } )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/ledgers\/\d+|, 'REST3.4.1' )
        ->json_is( '/name' => $base_body->{name} );

    my $new_ledger1_id = $t->tx->res->json->{ledger_id};
    $ledger1->discard_changes;
    ok( !$ledger1->status, 'Original ledger set inactive after rollover' );

    my @copied_funds1 = Koha::Acquisition::Finances::Funds->search( { ledger_id => $new_ledger1_id } )->as_list;
    is( scalar @copied_funds1,          1,                   'Fund copied to new ledger' );
    is( $copied_funds1[0]->fund_amount, $fund1->fund_amount, 'Fund amount unchanged when no adjust options given' );

    my $rollover_allocation = Koha::Acquisition::Finances::Allocations->search(
        { ledger_id => $new_ledger1_id, type => 'ROLLOVER_TRANSFER' } )->single;
    ok( $rollover_allocation, 'Rollover allocation created for new ledger' );
    is(
        $rollover_allocation->allocation_amount, $ledger1->ledger_amount,
        'Rollover allocation amount matches ledger amount'
    );

    # set_funds_to_zero — all copied fund amounts set to 0
    my $ledger2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 8000, currency => 'GBP', status => 1, locked => 0 }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger2->ledger_id, parent_fund_id => undef, fund_amount => 3000 }
        }
    );

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/"
            . $ledger2->ledger_id
            . "/rollover" => json =>
            { %$base_body, ledger_amount => $ledger2->ledger_amount, set_funds_to_zero => Mojo::JSON->true } )
        ->status_is(201);

    my $new_ledger2_id = $t->tx->res->json->{ledger_id};
    my @copied_funds2  = Koha::Acquisition::Finances::Funds->search( { ledger_id => $new_ledger2_id } )->as_list;
    is( scalar @copied_funds2,              1, 'Fund copied to new ledger when set_funds_to_zero' );
    is( $copied_funds2[0]->fund_amount + 0, 0, 'Fund amount set to zero when set_funds_to_zero is true' );

    # adjust_by_percent + round_to_multiple — ledger and fund amounts adjusted then rounded down
    # 1000 + 1000 * 15/100 = 1150 → int(1150/100) * 100 = 1100
    #  500 +  500 * 15/100 =  575 → int(575/100)  * 100 =  500
    my $ledger3 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 1000, currency => 'GBP', status => 1, locked => 0 }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger3->ledger_id, parent_fund_id => undef, fund_amount => 500 }
        }
    );

    $t->post_ok(
        "//$userid:$password@/api/v1/acquisitions/ledgers/" . $ledger3->ledger_id . "/rollover" => json => {
            %$base_body,
            ledger_amount     => $ledger3->ledger_amount,
            adjust_by_percent => 15,
            round_to_multiple => 100,
        }
    )->status_is(201)->json_is( '/ledger_amount' => 1100 );

    my $new_ledger3_id = $t->tx->res->json->{ledger_id};
    my @copied_funds3  = Koha::Acquisition::Finances::Funds->search( { ledger_id => $new_ledger3_id } )->as_list;
    is( $copied_funds3[0]->fund_amount + 0, 500, 'Fund amount adjusted by percent and rounded down to multiple' );

    # dry_run — returns 200 with preview data, nothing persisted
    my $ledger4 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 5000, currency => 'GBP', status => 1, locked => 0 }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger4->ledger_id, parent_fund_id => undef, fund_amount => 2500 }
        }
    );

    my $ledger_count_before = Koha::Acquisition::Finances::Ledgers->search->count;

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/"
            . $ledger4->ledger_id
            . "/rollover?dry_run=1" => json => { %$base_body, ledger_amount => $ledger4->ledger_amount } )
        ->status_is(200)
        ->json_is( '/name'                => $base_body->{name} )
        ->json_is( '/funds/0/fund_amount' => 2500 );

    $ledger4->discard_changes;
    ok( $ledger4->status, 'Original ledger still active after dry run' );
    is(
        Koha::Acquisition::Finances::Ledgers->search->count,
        $ledger_count_before,
        'No new ledger persisted during dry run'
    );

    # dry_run with adjust_by_percent + round_to_multiple — amounts calculated correctly, nothing persisted
    # 1000 + 1000 * 15/100 = 1150 → int(1150/100) * 100 = 1100
    #  500 +  500 * 15/100 =  575 → int(575/100)  * 100 =  500
    my $ledger5 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 1000, currency => 'GBP', status => 1, locked => 0 }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger5->ledger_id, parent_fund_id => undef, fund_amount => 500 }
        }
    );

    my $ledger5_count_before = Koha::Acquisition::Finances::Ledgers->search->count;

    $t->post_ok(
        "//$userid:$password@/api/v1/acquisitions/ledgers/" . $ledger5->ledger_id . "/rollover?dry_run=1" => json => {
            %$base_body,
            ledger_amount     => $ledger5->ledger_amount,
            adjust_by_percent => 15,
            round_to_multiple => 100,
        }
    )->status_is(200)->json_is( '/ledger_amount' => 1100 )->json_is( '/funds/0/fund_amount' => 500 );

    $ledger5->discard_changes;
    ok( $ledger5->status, 'Original ledger still active after dry run with adjust_by_percent' );
    is(
        Koha::Acquisition::Finances::Ledgers->search->count,
        $ledger5_count_before,
        'No new ledger persisted during dry run with adjust_by_percent'
    );

    $schema->storage->txn_rollback;
};
