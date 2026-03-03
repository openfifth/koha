#!/usr/bin/perl

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

use Test::More tests => 10;
use Test::NoWarnings;

use C4::Circulation qw( AddIssue AddReturn );
use Koha::Acquisition::Invoices;
use Koha::Acquisition::Order::Items;
use Koha::Database;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'check_and_close: all items received closes invoice' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    my $order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );
    my $item = $builder->build_sample_item;
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $order->{ordernumber},
                itemnumber  => $item->itemnumber,
                received    => '2026-01-01 10:00:00',
            },
        }
    );

    my $closed = $invoice->check_and_close;
    is( $closed, 1, 'check_and_close returns 1 when all items received' );

    $invoice->discard_changes;
    ok( $invoice->closedate, 'Invoice has a closedate after check_and_close' );

    my $closed_again = $invoice->check_and_close;
    is( $closed_again, 0, 'check_and_close returns 0 if already closed' );

    $schema->storage->txn_rollback;
};

subtest 'check_and_close: unreceived item keeps invoice open' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    my $order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );

    # One received item
    my $item1 = $builder->build_sample_item;
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $order->{ordernumber},
                itemnumber  => $item1->itemnumber,
                received    => '2026-01-01 10:00:00',
            },
        }
    );

    # One NOT yet received item
    my $item2 = $builder->build_sample_item;
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $order->{ordernumber},
                itemnumber  => $item2->itemnumber,
                received    => undef,
            },
        }
    );

    my $closed = $invoice->check_and_close;
    is( $closed, 0, 'check_and_close returns 0 when an item is not yet received' );

    $invoice->discard_changes;
    ok( !$invoice->closedate, 'Invoice remains open' );

    $schema->storage->txn_rollback;
};

subtest 'check_and_close: cancelled order lines excluded' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    # Active order with all items received
    my $active_order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );
    my $item = $builder->build_sample_item;
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $active_order->{ordernumber},
                itemnumber  => $item->itemnumber,
                received    => '2026-01-01 10:00:00',
            },
        }
    );

    # Cancelled order with unreceived item — should NOT block close
    my $cancelled_order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'cancelled' },
        }
    );
    my $cancelled_item = $builder->build_sample_item;
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $cancelled_order->{ordernumber},
                itemnumber  => $cancelled_item->itemnumber,
                received    => undef,
            },
        }
    );

    my $closed = $invoice->check_and_close;
    is( $closed, 1, 'Invoice closed: cancelled order line unreceived item does not block' );

    $invoice->discard_changes;
    ok( $invoice->closedate, 'Invoice has a closedate' );

    $schema->storage->txn_rollback;
};

subtest 'check_and_close: invoice with no items stays open' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    # Order on invoice but no aqorders_items rows
    $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );

    my $closed = $invoice->check_and_close;
    is( $closed, 0, 'check_and_close returns 0 for invoice with no linked items' );

    $invoice->discard_changes;
    ok( !$invoice->closedate, 'Invoice remains open' );

    $schema->storage->txn_rollback;
};

subtest 'record_physical_receipt stamps received and auto-closes' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AcqCreateItem',              'ordering' );
    t::lib::Mocks::mock_preference( 'AutoCloseInvoicesOnCheckin', 1 );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    # Issue the item
    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    my $order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $order->{ordernumber},
                itemnumber  => $item->itemnumber,
                received    => undef,
            },
        }
    );

    # Check in the item
    my ($doreturn) = AddReturn( $item->barcode, $library->branchcode );
    ok( $doreturn, 'AddReturn succeeded' );

    # Verify received timestamp was set
    my $order_item = Koha::Acquisition::Order::Items->find( { itemnumber => $item->itemnumber } );
    ok( $order_item->received, 'aqorders_items.received was stamped on check-in' );

    # Second check-in should NOT overwrite the received timestamp
    AddIssue( $patron, $item->barcode );
    my $first_received = $order_item->received;
    AddReturn( $item->barcode, $library->branchcode );
    $order_item->discard_changes;
    is(
        $order_item->received, $first_received,
        'Second check-in does not overwrite received timestamp'
    );

    # Invoice should be closed (only one item, now received)
    $invoice->discard_changes;
    ok( $invoice->closedate, 'Invoice was auto-closed after last item checked in' );

    $schema->storage->txn_rollback;
};

subtest 'AutoCloseInvoicesOnCheckin disabled: no auto-close' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AcqCreateItem',              'ordering' );
    t::lib::Mocks::mock_preference( 'AutoCloseInvoicesOnCheckin', 0 );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    my $order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $order->{ordernumber},
                itemnumber  => $item->itemnumber,
                received    => undef,
            },
        }
    );

    AddReturn( $item->barcode, $library->branchcode );

    # received should still be stamped (that always happens)
    my $order_item = Koha::Acquisition::Order::Items->find( { itemnumber => $item->itemnumber } );
    ok( $order_item->received, 'received is stamped regardless of preference' );

    # Invoice should NOT be closed
    $invoice->discard_changes;
    ok( !$invoice->closedate, 'Invoice not auto-closed when AutoCloseInvoicesOnCheckin is off' );

    $schema->storage->txn_rollback;
};

subtest 'record_physical_receipt: item not in aqorders_items is a no-op' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    my ($doreturn) = AddReturn( $item->barcode, $library->branchcode );
    ok( $doreturn, 'AddReturn succeeds for item with no aqorders_items row' );

    my $order_item = Koha::Acquisition::Order::Items->find( { itemnumber => $item->itemnumber } );
    ok( !$order_item, 'No aqorders_items row exists — nothing stamped' );

    $schema->storage->txn_rollback;
};

subtest 'AcqCreateItem=receiving: record_physical_receipt is a no-op' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AcqCreateItem',              'receiving' );
    t::lib::Mocks::mock_preference( 'AutoCloseInvoicesOnCheckin', 1 );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    my $invoice = $builder->build_object( { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );

    my $order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'complete' },
        }
    );

    # Basket defaults to AcqCreateItem syspref (receiving), so effective_create_items = 'receiving'
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $order->{ordernumber},
                itemnumber  => $item->itemnumber,
                received    => undef,
            },
        }
    );

    AddReturn( $item->barcode, $library->branchcode );

    my $order_item = Koha::Acquisition::Order::Items->find( { itemnumber => $item->itemnumber } );
    ok( !$order_item->received, 'AcqCreateItem=receiving: received not stamped (no-op)' );

    $invoice->discard_changes;
    ok( !$invoice->closedate, 'AcqCreateItem=receiving: invoice not auto-closed (no-op)' );

    $schema->storage->txn_rollback;
};

subtest 'record_physical_receipt: cancelled order does not stamp received' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode },
        }
    );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    my $invoice = $builder->build_object(
        { class => 'Koha::Acquisition::Invoices', value => { closedate => undef } } );
    my $cancelled_order = $builder->build(
        {
            source => 'Aqorder',
            value  => { invoiceid => $invoice->invoiceid, orderstatus => 'cancelled' },
        }
    );
    $builder->build(
        {
            source => 'AqordersItem',
            value  => {
                ordernumber => $cancelled_order->{ordernumber},
                itemnumber  => $item->itemnumber,
                received    => undef,
            },
        }
    );

    AddReturn( $item->barcode, $library->branchcode );

    my $order_item = Koha::Acquisition::Order::Items->find( { itemnumber => $item->itemnumber } );
    ok( !$order_item->received, 'Cancelled order: received not stamped on check-in' );

    $invoice->discard_changes;
    ok( !$invoice->closedate, 'Cancelled order: invoice not auto-closed' );

    $schema->storage->txn_rollback;
};
