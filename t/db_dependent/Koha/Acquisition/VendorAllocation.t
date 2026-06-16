#!/usr/bin/perl

# Copyright 2026 Koha Development team
#
# This file is part of Koha
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

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Acquisition::VendorAllocation;
use Koha::Acquisition::VendorAllocations;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'to_api() mapping' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $allocation = $builder->build_object( { class => 'Koha::Acquisition::VendorAllocations' } );
    my $api        = $allocation->to_api;

    ok( exists $api->{allocation_id}, 'allocation_id is present in API output' );
    ok( !exists $api->{id},           'id is absent from API output' );
    ok( exists $api->{vendor_id},     'vendor_id is present in API output' );
    ok( !exists $api->{booksellerid}, 'booksellerid is absent from API output' );

    $schema->storage->txn_rollback;
};

subtest 'spent()' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CalculateFundValuesIncludingTax', 1 );

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $budget = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    my $fund   = $builder->build_object(
        {
            class => 'Koha::Acquisition::Funds',
            value => { budget_period_id => $budget->budget_period_id }
        }
    );
    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => { booksellerid => $vendor->id }
        }
    );

    # Two received orders for this vendor + period
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 2,
                quantityreceived        => 2,
                unitprice_tax_included  => '10.000000',
                ecost_tax_included      => '10.000000',
                datecancellationprinted => undef,
            }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 1,
                quantityreceived        => 1,
                unitprice_tax_included  => '5.000000',
                ecost_tax_included      => '5.000000',
                datecancellationprinted => undef,
            }
        }
    );

    # Received order for a different vendor — must be excluded
    my $other_basket = $builder->build_object( { class => 'Koha::Acquisition::Baskets' } );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $other_basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 1,
                quantityreceived        => 1,
                unitprice_tax_included  => '100.000000',
                ecost_tax_included      => '100.000000',
                datecancellationprinted => undef,
            }
        }
    );

    # Cancelled received order — must be excluded
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 1,
                quantityreceived        => 1,
                unitprice_tax_included  => '50.000000',
                ecost_tax_included      => '50.000000',
                datecancellationprinted => '2026-01-01',
            }
        }
    );

    my $allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $budget->budget_period_id,
            allocation_amount => '500.000000',
        }
    )->store;

    is( $allocation->spent + 0, 25, 'spent() returns correct sum (2×10 + 1×5 = 25)' );
    is( $allocation->ordered + 0, 0, 'ordered() returns 0 when all matching orders are received' );
    is( $allocation->used + 0, 25, 'used() = spent() + ordered()' );

    $schema->storage->txn_rollback;
};

subtest 'ordered()' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CalculateFundValuesIncludingTax', 1 );

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $budget = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    my $fund   = $builder->build_object(
        {
            class => 'Koha::Acquisition::Funds',
            value => { budget_period_id => $budget->budget_period_id }
        }
    );
    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => { booksellerid => $vendor->id }
        }
    );

    # Two open (not yet received) orders
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 3,
                quantityreceived        => 0,
                ecost_tax_included      => '10.000000',
                datecancellationprinted => undef,
            }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 2,
                quantityreceived        => 0,
                ecost_tax_included      => '7.500000',
                datecancellationprinted => undef,
            }
        }
    );

    # A received order — must be excluded from ordered()
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 1,
                quantityreceived        => 1,
                unitprice_tax_included  => '100.000000',
                ecost_tax_included      => '100.000000',
                datecancellationprinted => undef,
            }
        }
    );

    my $allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $budget->budget_period_id,
            allocation_amount => '500.000000',
        }
    )->store;

    is( $allocation->ordered + 0, 45, 'ordered() returns correct sum (3×10 + 2×7.5 = 45)' );
    is( $allocation->spent + 0, 100, 'spent() excludes the open orders' );
    is( $allocation->used + 0, 145, 'used() = spent() + ordered()' );

    $schema->storage->txn_rollback;
};

subtest 'remaining()' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CalculateFundValuesIncludingTax', 1 );

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $budget = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    my $fund   = $builder->build_object(
        {
            class => 'Koha::Acquisition::Funds',
            value => { budget_period_id => $budget->budget_period_id }
        }
    );
    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets',
            value => { booksellerid => $vendor->id }
        }
    );

    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 1,
                quantityreceived        => 1,
                unitprice_tax_included  => '30.000000',
                ecost_tax_included      => '30.000000',
                datecancellationprinted => undef,
            }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => {
                basketno                => $basket->basketno,
                budget_id               => $fund->budget_id,
                quantity                => 1,
                quantityreceived        => 0,
                ecost_tax_included      => '20.000000',
                datecancellationprinted => undef,
            }
        }
    );

    my $allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $budget->budget_period_id,
            allocation_amount => '200.000000',
        }
    )->store;

    is( $allocation->used + 0,       50,  'used() = 30 spent + 20 ordered = 50' );
    is( $allocation->remaining + 0,  150, 'remaining() = allocation_amount - used() = 150' );

    $schema->storage->txn_rollback;
};

subtest 'Koha::Acquisition::VendorAllocations->clone_for_period()' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $vendor_a = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $vendor_b = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );

    my $from_period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    my $to_period   = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );

    Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor_a->id,
            budget_period_id  => $from_period->budget_period_id,
            allocation_amount => '1000.000000',
            warn_at_percentage => '80.0000',
            warn_at_amount    => '900.000000',
        }
    )->store;
    Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor_b->id,
            budget_period_id  => $from_period->budget_period_id,
            allocation_amount => '500.000000',
            warn_at_percentage => '75.0000',
            warn_at_amount    => '0.000000',
        }
    )->store;

    # Clone with no percentage change — amounts should be copied as-is
    Koha::Acquisition::VendorAllocations->clone_for_period(
        {
            from_budget_period_id => $from_period->budget_period_id,
            to_budget_period_id   => $to_period->budget_period_id,
        }
    );

    my $cloned = Koha::Acquisition::VendorAllocations->search(
        { budget_period_id => $to_period->budget_period_id }
    );
    is( $cloned->count, 2, 'Two allocations cloned to new period' );

    my $cloned_a = $cloned->search( { booksellerid => $vendor_a->id } )->single;
    is( $cloned_a->allocation_amount + 0,  1000, 'allocation_amount copied correctly' );
    is( $cloned_a->warn_at_percentage + 0, 80,   'warn_at_percentage copied correctly' );
    is( $cloned_a->warn_at_amount + 0,     900,  'warn_at_amount copied correctly' );

    # Original allocations unchanged
    is(
        Koha::Acquisition::VendorAllocations->search(
            { budget_period_id => $from_period->budget_period_id }
        )->count,
        2,
        'Original period still has 2 allocations'
    );

    # Clone a third period with reset => 1
    my $reset_period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    Koha::Acquisition::VendorAllocations->clone_for_period(
        {
            from_budget_period_id => $from_period->budget_period_id,
            to_budget_period_id   => $reset_period->budget_period_id,
            reset                 => 1,
        }
    );

    my $reset_a = Koha::Acquisition::VendorAllocations->search(
        {
            budget_period_id => $reset_period->budget_period_id,
            booksellerid     => $vendor_a->id,
        }
    )->single;
    is( $reset_a->allocation_amount + 0, 0, 'reset => 1 sets allocation_amount to 0' );

    # Clone a fourth period with amount_change_percentage => 10
    my $pct_period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    Koha::Acquisition::VendorAllocations->clone_for_period(
        {
            from_budget_period_id    => $from_period->budget_period_id,
            to_budget_period_id      => $pct_period->budget_period_id,
            amount_change_percentage => 10,
        }
    );

    my $pct_a = Koha::Acquisition::VendorAllocations->search(
        {
            budget_period_id => $pct_period->budget_period_id,
            booksellerid     => $vendor_a->id,
        }
    )->single;
    is( $pct_a->allocation_amount + 0, 1100, 'amount_change_percentage => 10 increases amount by 10%' );

    my $pct_b = Koha::Acquisition::VendorAllocations->search(
        {
            budget_period_id => $pct_period->budget_period_id,
            booksellerid     => $vendor_b->id,
        }
    )->single;
    is( $pct_b->allocation_amount + 0, 550, 'amount_change_percentage applies to second allocation' );

    # Clone with rounding
    my $round_period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    Koha::Acquisition::VendorAllocations->clone_for_period(
        {
            from_budget_period_id         => $from_period->budget_period_id,
            to_budget_period_id           => $round_period->budget_period_id,
            amount_change_percentage      => 10,
            amount_change_round_increment => 100,
        }
    );

    my $round_b = Koha::Acquisition::VendorAllocations->search(
        {
            budget_period_id => $round_period->budget_period_id,
            booksellerid     => $vendor_b->id,
        }
    )->single;
    is( $round_b->allocation_amount + 0, 600, '550 rounded up to nearest 100 = 600' );

    my $round_a = Koha::Acquisition::VendorAllocations->search(
        {
            budget_period_id => $round_period->budget_period_id,
            booksellerid     => $vendor_a->id,
        }
    )->single;
    is( $round_a->allocation_amount + 0, 1100, '1100 already on a 100 boundary, stays 1100' );

    # warn_at fields copied regardless of reset/percentage
    is( $reset_a->warn_at_percentage + 0, 80,  'warn_at_percentage preserved on reset clone' );
    is( $pct_a->warn_at_amount + 0,       900, 'warn_at_amount preserved on percentage clone' );

    $schema->storage->txn_rollback;
};
