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
use Test::More tests => 9;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Acquisition::Finances::Fund;
use Koha::Acquisition::Finances::Funds;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() and delete() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $fund    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    my $fund_id = $fund->fund_id;

    ok( defined $fund_id, 'Fund stored and has an ID' );

    my $retrieved = Koha::Acquisition::Finances::Funds->find($fund_id);
    ok( defined $retrieved, 'Fund can be retrieved from DB' );

    $fund->delete;
    my $deleted = Koha::Acquisition::Finances::Funds->find($fund_id);
    ok( !defined $deleted, 'Fund deleted successfully' );

    $schema->storage->txn_rollback;
};

subtest 'sub_funds() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => undef }
        }
    );

    is( $parent_fund->sub_funds->count, 0, 'No sub-funds initially' );

    my $sub_fund1 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => $parent_fund->fund_id }
        }
    );
    my $sub_fund2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => $parent_fund->fund_id }
        }
    );

    my $sub_funds = $parent_fund->sub_funds;
    is( $sub_funds->count, 2, 'Two sub-funds returned' );

    # With embed_children, also returns nested sub-funds
    my $nested_sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => $sub_fund1->fund_id }
        }
    );

    my $embedded = $parent_fund->sub_funds( { embed_children => 1 } );
    is( ref($embedded),     'ARRAY', 'sub_funds with embed_children returns an array ref' );
    is( scalar(@$embedded), 3,       'embed_children returns all nested sub-funds' );

    $schema->storage->txn_rollback;
};

subtest 'parent_fund() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => undef }
        }
    );
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => $parent_fund->fund_id }
        }
    );

    my $retrieved_parent = $sub_fund->parent_fund;
    is( $retrieved_parent->fund_id, $parent_fund->fund_id, 'parent_fund returns the correct parent fund' );

    is( $parent_fund->parent_fund, undef, 'parent_fund returns undef for a top-level fund' );

    $schema->storage->txn_rollback;
};

subtest 'is_sub_fund() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => undef }
        }
    );
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => $parent_fund->fund_id }
        }
    );

    is( $parent_fund->is_sub_fund, 0, 'Top-level fund is not a sub-fund' );
    is( $sub_fund->is_sub_fund,    1, 'Fund with fund_parent_id is a sub-fund' );

    $schema->storage->txn_rollback;
};

subtest 'has_sub_funds() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => undef }
        }
    );

    is( $parent_fund->has_sub_funds, 0, 'Fund with no sub-funds returns 0' );

    $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => $parent_fund->fund_id }
        }
    );

    is( $parent_fund->has_sub_funds, 1, 'Fund with sub-funds returns 1' );

    $schema->storage->txn_rollback;
};

subtest 'cascade_to_sub_funds() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { status => 1, fund_parent_id => undef }
        }
    );

    my $active_sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                fund_parent_id => $parent_fund->fund_id,
                status         => 1
            }
        }
    );

    my $inactive_sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                fund_parent_id => $parent_fund->fund_id,
                status         => 0
            }
        }
    );

    $parent_fund->status(0);
    $parent_fund->cascade_to_sub_funds;

    $active_sub_fund->discard_changes;
    $inactive_sub_fund->discard_changes;

    is( $active_sub_fund->status,   0, 'Active sub-fund status cascaded to inactive' );
    is( $inactive_sub_fund->status, 0, 'Already-inactive sub-fund remains inactive' );

    # A fund with no sub-funds should cascade without errors
    my $fund_no_children = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_parent_id => undef, status => 1 }
        }
    );
    $fund_no_children->status(0);
    eval { $fund_no_children->cascade_to_sub_funds };
    ok( !$@, 'Cascade on fund with no sub-funds does not throw an error' );

    $schema->storage->txn_rollback;
};

subtest 'managing_library() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $fund_with_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { managing_branch => $library->branchcode }
        }
    );
    my $fund_no_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { managing_branch => undef }
        }
    );

    my $managing_library = $fund_with_branch->managing_library;
    is( $managing_library->branchcode, $library->branchcode, 'managing_library returns the correct library' );

    is( $fund_no_branch->managing_library, undef, 'managing_library returns undef when no branch set' );

    $schema->storage->txn_rollback;
};

subtest 'to_api() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { currency => 'GBP' }
        }
    );

    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { ledger_id => $ledger->ledger_id }
        }
    );

    my $api_response = $fund->to_api;

    ok( exists $api_response->{currency}, 'to_api includes currency field' );
    is( $api_response->{currency}, 'GBP', 'to_api currency matches the ledger currency' );

    $schema->storage->txn_rollback;
};
