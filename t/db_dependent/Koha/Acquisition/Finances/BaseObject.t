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

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Acquisition::Finances::FiscalPeriods;
use Koha::Acquisition::Finances::Ledgers;
use Koha::Acquisition::Finances::Funds;
use Koha::Acquisition::Finances::Allocations;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'cascade_status() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );
    my $ledger        = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 1 }
        }
    );

    # Parent inactive -> active child: change should be detected
    $fiscal_period->status(0);
    my $changed = $fiscal_period->cascade_status( { parent_status => 0, child => $ledger } );
    is( $changed,        1, 'Change detected when parent goes inactive and child is active' );
    is( $ledger->status, 0, 'Child status updated to inactive' );

    # Parent active -> already-inactive child: no change
    my $ledger2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 0 }
        }
    );
    $fiscal_period->status(1);
    my $not_changed = $fiscal_period->cascade_status( { parent_status => 1, child => $ledger2 } );
    is( $not_changed,     0, 'No change detected when parent is active and child is already inactive' );
    is( $ledger2->status, 0, 'Child status unchanged' );

    $schema->storage->txn_rollback;
};

subtest 'relationship embedding tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );
    my $ledger        = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { fiscal_period_id => $fiscal_period->fiscal_period_id }
        }
    );
    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id      => $ledger->ledger_id,
                parent_fund_id => undef,
            }
        }
    );
    my $allocation = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Allocations',
            value => { fund_id => $fund->fund_id }
        }
    );
    my $patron            = $builder->build_object( { class => 'Koha::Patrons' } );
    my $ledger_with_owner = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { owner_id => $patron->borrowernumber }
        }
    );

    # ledger() on a fund
    my $embedded_ledger = $fund->ledger;
    isa_ok( $embedded_ledger, 'Koha::Acquisition::Finances::Ledger', 'ledger() returns a Ledger object' );
    is( $embedded_ledger->ledger_id, $ledger->ledger_id, 'ledger() returns the correct ledger' );

    # fiscal_period() on a fund
    my $embedded_fp = $fund->fiscal_period;
    isa_ok(
        $embedded_fp, 'Koha::Acquisition::Finances::FiscalPeriod',
        'fiscal_period() returns a FiscalPeriod object'
    );
    is(
        $embedded_fp->fiscal_period_id, $fiscal_period->fiscal_period_id,
        'fiscal_period() returns the correct fiscal period'
    );

    # funds() on a ledger
    my $embedded_funds = $ledger->funds;
    isa_ok( $embedded_funds, 'Koha::Acquisition::Finances::Funds', 'funds() returns a Funds collection' );

    # owner() on a ledger with owner set
    my $embedded_owner = $ledger_with_owner->owner;
    isa_ok( $embedded_owner, 'Koha::Patron', 'owner() returns a Patron object' );

    $schema->storage->txn_rollback;
};

subtest 'owner() returns undef when not set' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $ledger_no_owner = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { owner_id => undef }
        }
    );

    is( $ledger_no_owner->owner, undef, 'owner() returns undef when owner_id is not set' );

    $schema->storage->txn_rollback;
};

subtest 'update_amount() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 10000 }
        }
    );

    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id      => $ledger->ledger_id,
                fund_amount    => 0,
                parent_fund_id => undef,
            }
        }
    );

    # Increase within limit
    my $result = $fund->update_amount( { type => 'increase', value => 1000 } );
    $fund->discard_changes;
    is( $result->{within_limit}, 1, 'Increase within limit returns within_limit => 1' );
    cmp_ok( $fund->fund_amount, '==', 1000, 'Fund amount updated after increase' );

    # Increase exceeding limit
    my $breach_result = $fund->update_amount( { type => 'increase', value => 99999 } );
    $fund->discard_changes;
    is( $breach_result->{within_limit}, 0, 'Increase exceeding limit returns within_limit => 0' );
    cmp_ok( $fund->fund_amount, '==', 1000, 'Fund amount NOT updated when limit exceeded' );

    # Decrease: no validation, no return value
    $fund->update_amount( { type => 'decrease', value => 500 } );
    $fund->discard_changes;
    cmp_ok( $fund->fund_amount, '==', 500, 'Fund amount updated after decrease' );

    $schema->storage->txn_rollback;
};

subtest 'validate_child_object_amounts_against_parent_amount() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    # Test against a ledger as parent (top-level fund)
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { ledger_amount => 1000 }
        }
    );
    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id      => $ledger->ledger_id,
                fund_amount    => 0,
                parent_fund_id => undef,
            }
        }
    );

    # Within limit
    my $within = $fund->validate_child_object_amounts_against_parent_amount( { new_allocation => 500 } );
    is( $within->{within_limit}, 1, 'Returns within_limit => 1 when new allocation fits within ledger amount' );

    # Exceeds limit
    my $exceeded = $fund->validate_child_object_amounts_against_parent_amount( { new_allocation => 99999 } );
    is( $exceeded->{within_limit},  0,     'Returns within_limit => 0 when new allocation exceeds ledger amount' );
    is( $exceeded->{breach_amount}, 98999, 'breach_amount is correctly calculated (99999 - 1000 = 98999)' );

    # Test against a parent fund (sub-fund)
    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { fund_amount => 500, parent_fund_id => undef }
        }
    );
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id      => $parent_fund->ledger_id,
                parent_fund_id => $parent_fund->fund_id,
                fund_amount    => 0,
            }
        }
    );

    my $sub_exceeded = $sub_fund->validate_child_object_amounts_against_parent_amount( { new_allocation => 9999 } );
    is( $sub_exceeded->{within_limit}, 0, 'Returns within_limit => 0 when sub-fund exceeds parent fund amount' );

    $schema->storage->txn_rollback;
};

subtest 'parent_object() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $ledger = $builder->build_object( { class => 'Koha::Acquisition::Finances::Ledgers' } );
    my $fund   = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id      => $ledger->ledger_id,
                parent_fund_id => undef,
            }
        }
    );

    # Top-level fund: parent is the ledger
    my $parent = $fund->parent_object;
    isa_ok( $parent, 'Koha::Acquisition::Finances::Ledger', 'parent_object returns a Ledger for a top-level fund' );
    is( $parent->ledger_id, $ledger->ledger_id, 'parent_object returns the correct ledger' );

    $schema->storage->txn_rollback;
};

subtest 'parent_object() for sub-fund tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $parent_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { parent_fund_id => undef }
        }
    );
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => { parent_fund_id => $parent_fund->fund_id }
        }
    );

    # Sub-fund: parent is the parent fund
    my $parent = $sub_fund->parent_object;
    isa_ok( $parent, 'Koha::Acquisition::Finances::Fund', 'parent_object returns a Fund for a sub-fund' );
    is( $parent->fund_id, $parent_fund->fund_id, 'parent_object returns the correct parent fund' );

    $schema->storage->txn_rollback;
};
