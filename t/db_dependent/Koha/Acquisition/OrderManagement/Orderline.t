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

use Koha::Acquisition::Finances::Funds;
use Koha::Acquisition::OrderManagement::Orderlines;
use Koha::Acquisition::OrderManagement::OrderlineManagers;
use Koha::Acquisition::OrderManagement::OrderlineUsers;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'biblio() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, biblionumber => undef }
        }
    );

    is( $orderline->biblio, undef, 'biblio() returns undef when no biblionumber set' );

    $orderline->biblio(
        {
            biblio_data           => { title => 'Test Title', author => 'Test Author' },
            confirm_not_duplicate => 1,
        }
    );
    $orderline->discard_changes;

    ok( $orderline->biblionumber, 'biblionumber is set after biblio() creates a new biblio' );

    my $biblio = $orderline->biblio;
    ok( $biblio, 'biblio() returns a defined object' );
    is( $biblio->title,  'Test Title',  'biblio() title matches the supplied data' );
    is( $biblio->author, 'Test Author', 'biblio() author matches the supplied data' );

    $schema->storage->txn_rollback;
};

subtest 'fund_distributions() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1 }
        }
    );

    is( $orderline->fund_distributions->count, 0, 'fund_distributions() returns empty collection initially' );

    my $fund = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );

    my $distribution = {
        fund_id                         => $fund->fund_id,
        percentage                      => 100,
        distributed_amount_oc           => 0,
        exchange_rate                   => 1,
        distributed_amount              => 0,
        tax_rate                        => 0,
        tax_value                       => 0,
        distributed_amount_tax_excluded => 0,
        distributed_amount_tax_included => 0,
    };

    $orderline->fund_distributions( [$distribution] );

    my $dists = $orderline->fund_distributions;
    is( $dists->count,         1,              'fund_distributions() count is 1 after setting one distribution' );
    is( $dists->next->fund_id, $fund->fund_id, 'fund_distributions() returns the correct fund_id' );

    my $fund2 = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    $distribution->{fund_id} = $fund2->fund_id;
    $orderline->fund_distributions( [$distribution] );

    is(
        $orderline->fund_distributions->count, 1,
        'fund_distributions() count is still 1 after replacing distributions'
    );
    is(
        $orderline->fund_distributions->next->fund_id, $fund2->fund_id,
        'fund_distributions() replaced with new fund_id'
    );

    $schema->storage->txn_rollback;
};

subtest 'items() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $biblio    = $builder->build_sample_biblio;
    my $branch    = $builder->build_object( { class => 'Koha::Libraries' } );
    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, biblionumber => $biblio->biblionumber }
        }
    );

    is( $orderline->items->count, 0, 'items() returns empty collection initially' );

    $orderline->items(
        [
            {
                home_library_id    => $branch->branchcode,
                holding_library_id => $branch->branchcode,
            }
        ]
    );

    my $items = $orderline->items;
    is( $items->count,                   1,                     'items() count is 1 after adding an item' );
    is( $items->next->biblionumber,      $biblio->biblionumber, 'item is linked to the correct biblio' );
    is( $items->reset->next->homebranch, $branch->branchcode,   'item has the correct home branch' );

    $schema->storage->txn_rollback;
};

subtest 'vendor() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $orderline_no_vendor = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, vendor_id => undef }
        }
    );

    is( $orderline_no_vendor->vendor, undef, 'vendor() returns undef when no vendor set' );

    my $vendor    = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, vendor_id => $vendor->id }
        }
    );

    is( $orderline->vendor->id, $vendor->id, 'vendor() returns the correct vendor' );

    $schema->storage->txn_rollback;
};

subtest 'managing_library() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $orderline_no_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, managing_branch => undef }
        }
    );

    is( $orderline_no_branch->managing_library, undef, 'managing_library() returns undef when no branch set' );

    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, managing_branch => $library->branchcode }
        }
    );

    is(
        $orderline->managing_library->branchcode, $library->branchcode,
        'managing_library() returns the correct library'
    );

    $schema->storage->txn_rollback;
};

subtest 'managed_by() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1 }
        }
    );

    is( $orderline->managed_by->count, 0, 'managed_by() returns empty collection initially' );

    $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::OrderlineManagers',
            value => { orderline_id => $orderline->orderline_id }
        }
    );

    is( $orderline->managed_by->count, 1, 'managed_by() count is 1 after adding a manager' );

    $schema->storage->txn_rollback;
};

subtest 'patrons_to_notify() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1 }
        }
    );

    is( $orderline->patrons_to_notify->count, 0, 'patrons_to_notify() returns empty collection initially' );

    $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::OrderlineUsers',
            value => { orderline_id => $orderline->orderline_id }
        }
    );

    is( $orderline->patrons_to_notify->count, 1, 'patrons_to_notify() count is 1 after adding a user' );

    $schema->storage->txn_rollback;
};

subtest 'add_patron_relationships() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1 }
        }
    );

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    $orderline->add_patron_relationships( { patrons_to_notify => [ { borrowernumber => $patron1->borrowernumber } ] } );
    is( $orderline->patrons_to_notify->count, 1, 'patrons_to_notify count is 1 after first call' );

    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    $orderline->add_patron_relationships( { patrons_to_notify => [ { borrowernumber => $patron2->borrowernumber } ] } );
    is( $orderline->patrons_to_notify->count, 1, 'patrons_to_notify count is still 1 after replacement' );
    is(
        $orderline->patrons_to_notify->next->borrowernumber, $patron2->borrowernumber,
        'patrons_to_notify replaced with the new patron'
    );

    my $manager1 = $builder->build_object( { class => 'Koha::Patrons' } );
    $orderline->add_patron_relationships( { managed_by => [ { borrowernumber => $manager1->borrowernumber } ] } );
    is( $orderline->managed_by->count, 1, 'managed_by count is 1 after first call' );

    my $manager2 = $builder->build_object( { class => 'Koha::Patrons' } );
    $orderline->add_patron_relationships( { managed_by => [ { borrowernumber => $manager2->borrowernumber } ] } );
    is( $orderline->managed_by->count, 1, 'managed_by count is still 1 after replacement' );
    is(
        $orderline->managed_by->next->borrowernumber, $manager2->borrowernumber,
        'managed_by replaced with the new manager'
    );

    $schema->storage->txn_rollback;
};
