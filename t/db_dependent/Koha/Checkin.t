#!/usr/bin/env perl

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

use Test::More tests => 20;
use Test::Exception;
use Test::NoWarnings;
use Test::Warn;

use C4::Circulation qw( AddIssue AddReturn );
use C4::Reserves    qw( AddReserve );
use Koha::Account;
use Koha::Checkins;
use Koha::Database;
use Koha::Old::Holds;
use Koha::Recall;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'item() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
        }
    )->store;

    my $THE_item = $checkin->item;
    is( ref($THE_item),        'Koha::Item',      'item() returns a Koha::Item' );
    is( $THE_item->itemnumber, $item->itemnumber, 'Correct item returned' );

    $item->delete;
    $checkin = Koha::Checkins->find( $checkin->checkin_id );
    is( $checkin, undef, 'Checkin deleted when item is deleted (CASCADE)' );

    $schema->storage->txn_rollback;
};

subtest 'user() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
        }
    )->store;

    my $THE_user = $checkin->user;
    is( ref($THE_user),            'Koha::Patron',        'user() returns a Koha::Patron' );
    is( $THE_user->borrowernumber, $user->borrowernumber, 'Correct user returned' );

    $user->delete;
    $checkin->discard_changes;
    is( $checkin->user, undef, 'user() returns undef after user deleted (SET NULL)' );

    $schema->storage->txn_rollback;
};

subtest 'library() tests' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
        }
    )->store;

    my $THE_library = $checkin->library;
    is( ref($THE_library),        'Koha::Library',      'library() returns a Koha::Library' );
    is( $THE_library->branchcode, $library->branchcode, 'Correct library returned' );

    $library->delete;
    $checkin = Koha::Checkins->find( $checkin->checkin_id );
    is( $checkin, undef, 'Checkin deleted when library is deleted (CASCADE)' );

    $schema->storage->txn_rollback;
};

subtest 'desk() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $desk    = $builder->build_object( { class => 'Koha::Desks', value => { branchcode => $library->branchcode } } );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
            desk_id    => $desk->desk_id,
        }
    )->store;

    my $THE_desk = $checkin->desk;
    is( ref($THE_desk),     'Koha::Desk',   'desk() returns a Koha::Desk' );
    is( $THE_desk->desk_id, $desk->desk_id, 'Correct desk returned' );

    # desk_id SET NULL on delete
    $desk->delete;
    $checkin->discard_changes;
    is( $checkin->desk, undef, 'desk() returns undef after desk deleted (SET NULL)' );

    $schema->storage->txn_rollback;
};

subtest 'checkout() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    my $issue = AddIssue( $patron, $item->barcode );
    AddReturn( $item->barcode, $library->branchcode );

    my $old_checkout = Koha::Old::Checkouts->find( $issue->issue_id );

    my $checkin = Koha::Checkin->new(
        {
            item_id     => $item->itemnumber,
            user_id     => $user->borrowernumber,
            library_id  => $library->branchcode,
            checkout_id => $old_checkout->issue_id,
        }
    )->store;

    my $THE_checkout = $checkin->checkout;
    is( ref($THE_checkout),      'Koha::Old::Checkout',   'checkout() returns a Koha::Old::Checkout' );
    is( $THE_checkout->issue_id, $old_checkout->issue_id, 'Correct checkout returned' );

    # No checkout
    my $checkin2 = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
        }
    )->store;
    $checkin2->discard_changes;
    is( $checkin2->checkout, undef, 'checkout() returns undef when checkout_id is NULL' );

    $schema->storage->txn_rollback;
};

subtest 'transfer() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );

    my $transfer = $builder->build_object(
        {
            class => 'Koha::Item::Transfers',
            value => { itemnumber => $item->itemnumber },
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id     => $item->itemnumber,
            user_id     => $user->borrowernumber,
            library_id  => $library->branchcode,
            transfer_id => $transfer->branchtransfer_id,
        }
    )->store;

    my $THE_transfer = $checkin->transfer;
    is( ref($THE_transfer),               'Koha::Item::Transfer',       'transfer() returns a Koha::Item::Transfer' );
    is( $THE_transfer->branchtransfer_id, $transfer->branchtransfer_id, 'Correct transfer returned' );

    $schema->storage->txn_rollback;
};

subtest 'hold() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );

    my $hold = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                biblionumber   => $item->biblionumber,
                borrowernumber => $patron->borrowernumber,
            },
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
            hold_id    => $hold->reserve_id,
        }
    )->store;

    my $THE_hold = $checkin->hold;
    is( ref($THE_hold),        'Koha::Hold',      'hold() returns a Koha::Hold' );
    is( $THE_hold->reserve_id, $hold->reserve_id, 'Correct hold returned' );

    $schema->storage->txn_rollback;
};

subtest 'recall() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );

    my $recall = $builder->build_object(
        {
            class => 'Koha::Recalls',
            value => {
                biblio_id => $item->biblionumber,
                patron_id => $patron->borrowernumber,
            },
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
            recall_id  => $recall->id,
        }
    )->store;

    my $THE_recall = $checkin->recall;
    is( ref($THE_recall), 'Koha::Recall', 'recall() returns a Koha::Recall' );
    is( $THE_recall->id,  $recall->id,    'Correct recall returned' );

    $schema->storage->txn_rollback;
};

subtest 'restriction() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );

    my $restriction = $builder->build_object(
        {
            class => 'Koha::Patron::Restrictions',
            value => { borrowernumber => $user->borrowernumber },
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id        => $item->itemnumber,
            user_id        => $user->borrowernumber,
            library_id     => $library->branchcode,
            restriction_id => $restriction->borrower_debarment_id,
        }
    )->store;

    my $THE_restriction = $checkin->restriction;
    is( ref($THE_restriction), 'Koha::Patron::Restriction', 'restriction() returns a Koha::Patron::Restriction' );
    is(
        $THE_restriction->borrower_debarment_id,
        $restriction->borrower_debarment_id,
        'Correct restriction returned'
    );

    $schema->storage->txn_rollback;
};

subtest 'claim() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $item    = $builder->build_sample_item;
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );

    my $claim = $builder->build_object(
        {
            class => 'Koha::Checkouts::ReturnClaims',
            value => { itemnumber => $item->itemnumber },
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
            claim_id   => $claim->id,
        }
    )->store;

    my $THE_claim = $checkin->claim;
    is( ref($THE_claim), 'Koha::Checkouts::ReturnClaim', 'claim() returns a Koha::Checkouts::ReturnClaim' );
    is( $THE_claim->id,  $claim->id,                     'Correct claim returned' );

    $schema->storage->txn_rollback;
};

subtest 'AddReturn creates a Koha::Checkin' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode, borrowernumber => $user->borrowernumber } );

    my $issue = AddIssue( $patron, $item->barcode );

    my ( $doreturn, $messages, $old_issue, $borrower, $checkin ) = AddReturn( $item->barcode, $library->branchcode );

    ok( $doreturn, 'AddReturn succeeded' );
    is( ref($checkin),         'Koha::Checkin',       'Fifth return value is a Koha::Checkin' );
    is( $checkin->item_id,     $item->itemnumber,     'item_id set correctly' );
    is( $checkin->user_id,     $user->borrowernumber, 'user_id set from userenv' );
    is( $checkin->library_id,  $library->branchcode,  'library_id set correctly' );
    is( $checkin->checkout_id, $issue->issue_id,      'checkout_id links to old_issues' );
    is( $checkin->exempt_fine, 0,                     'exempt_fine defaults to false' );
    is( $checkin->local_use,   0,                     'local_use defaults to false' );
    ok( $checkin->checkin_id, 'checkin_id is set (persisted)' );

    $schema->storage->txn_rollback;
};

subtest 'AddReturn sets local_use for non-issued items' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode, borrowernumber => $user->borrowernumber } );
    t::lib::Mocks::mock_preference( 'RecordLocalUseOnReturn', 1 );

    # Item is not checked out — should be recorded as local use
    my ( $doreturn, $messages, $issue, $borrower, $checkin ) = AddReturn( $item->barcode, $library->branchcode );

    is( ref($checkin),         'Koha::Checkin', 'Checkin created for non-issued item' );
    is( $checkin->local_use,   1,               'local_use set to true' );
    is( $checkin->checkout_id, undef,           'checkout_id is undef (not checked out)' );

    $schema->storage->txn_rollback;
};

subtest 'debits() and credits() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            library_id => $library->branchcode,
            local_use  => 0,
        }
    )->store;

    # No accountlines yet
    is( $checkin->debits->count,  0, 'No debits linked initially' );
    is( $checkin->credits->count, 0, 'No credits linked initially' );

    # Add debits
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );
    my $debit1  = $account->add_debit(
        {
            amount    => 5.00,
            type      => 'OVERDUE',
            item_id   => $item->itemnumber,
            interface => 'commandline',
        }
    );
    $debit1->checkin_id( $checkin->id )->store;

    my $debit2 = $account->add_debit(
        {
            amount    => 10.00,
            type      => 'LOST',
            item_id   => $item->itemnumber,
            interface => 'commandline',
        }
    );
    $debit2->checkin_id( $checkin->id )->store;

    # Add a credit
    my $credit = $account->add_credit(
        {
            amount    => 5.00,
            type      => 'LOST_FOUND',
            interface => 'commandline',
        }
    );
    $credit->checkin_id( $checkin->id )->store;

    # Test accessors
    my $debits = $checkin->debits;
    is( ref($debits),   'Koha::Account::Debits', 'debits() returns Koha::Account::Debits' );
    is( $debits->count, 2,                       'Two debits linked' );

    my $credits = $checkin->credits;
    is( ref($credits),   'Koha::Account::Credits', 'credits() returns Koha::Account::Credits' );
    is( $credits->count, 1,                        'One credit linked' );

    # Verify the right lines are in each set
    is( $debits->total_outstanding, 15.00, 'Debits total is correct' );

    $schema->storage->txn_rollback;
};

subtest 'confirm_hold() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $checkin_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $pickup_library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user            = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron          = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item            = $builder->build_sample_item( { library => $checkin_library->branchcode } );

    t::lib::Mocks::mock_userenv(
        { branchcode => $checkin_library->branchcode, borrowernumber => $user->borrowernumber } );

    # Create a hold at the same library (no transfer needed)
    my $reserve_id = AddReserve(
        {
            branchcode     => $checkin_library->branchcode,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item->biblionumber,
            itemnumber     => $item->itemnumber,
            priority       => 1,
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $checkin_library->branchcode,
            hold_id    => $reserve_id,
        }
    )->store;

    # Test confirm_hold at same library (no transfer)
    $checkin->confirm_hold;
    $checkin->discard_changes;

    my $hold = Koha::Holds->find($reserve_id);
    is( $hold->found,          'W',   'Hold set to waiting after confirm_hold' );
    is( $checkin->transfer_id, undef, 'No transfer created when same library' );

    $schema->storage->txn_rollback;

    # Test confirm_hold with different pickup library (transfer needed)
    $schema->storage->txn_begin;

    $checkin_library = $builder->build_object( { class => 'Koha::Libraries' } );
    $pickup_library  = $builder->build_object( { class => 'Koha::Libraries' } );
    $user            = $builder->build_object( { class => 'Koha::Patrons' } );
    $patron          = $builder->build_object( { class => 'Koha::Patrons' } );
    $item            = $builder->build_sample_item( { library => $checkin_library->branchcode } );

    t::lib::Mocks::mock_userenv(
        { branchcode => $checkin_library->branchcode, borrowernumber => $user->borrowernumber } );

    $reserve_id = AddReserve(
        {
            branchcode     => $pickup_library->branchcode,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item->biblionumber,
            itemnumber     => $item->itemnumber,
            priority       => 1,
        }
    );

    $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $checkin_library->branchcode,
            hold_id    => $reserve_id,
        }
    )->store;

    $checkin->confirm_hold;
    $checkin->discard_changes;

    $hold = Koha::Holds->find($reserve_id);
    is( $hold->found, 'T', 'Hold set to in-transit when pickup differs' );
    ok( $checkin->transfer_id, 'Transfer ID set on checkin' );

    my $transfer = $checkin->transfer;
    is( $transfer->tobranch, $pickup_library->branchcode, 'Transfer destination is pickup library' );
    ok( $transfer->datesent, 'Transfer set in transit (datesent populated)' );

    $schema->storage->txn_rollback;
};

subtest 'cancel_hold() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode, borrowernumber => $user->borrowernumber } );

    # Test cancel without reason (no letter attempted)
    my $reserve_id = AddReserve(
        {
            branchcode     => $library->branchcode,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item->biblionumber,
            itemnumber     => $item->itemnumber,
            priority       => 1,
        }
    );

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
            hold_id    => $reserve_id,
        }
    )->store;

    $checkin->cancel_hold;
    $checkin->discard_changes;

    is( $checkin->hold_id, undef, 'hold_id cleared after cancel_hold (no reason)' );
    my $old_hold = Koha::Old::Holds->find($reserve_id);
    ok( $old_hold, 'Hold moved to old_reserves (no reason)' );
    is( $old_hold->cancellation_reason, undef, 'No cancellation reason stored' );

    # Test cancel with reason (letter warning expected)
    my $reserve_id2 = AddReserve(
        {
            branchcode     => $library->branchcode,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item->biblionumber,
            itemnumber     => $item->itemnumber,
            priority       => 1,
        }
    );

    my $checkin2 = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $library->branchcode,
            hold_id    => $reserve_id2,
        }
    )->store;

    warning_like { $checkin2->cancel_hold( { reason => 'PATRON_REQUEST' } ) }
    qr/HOLD_CANCELLATION/,
        'Warning about missing letter template when cancelling with reason';

    $checkin2->discard_changes;
    is( $checkin2->hold_id, undef, 'hold_id cleared after cancel_hold (with reason)' );
    my $old_hold2 = Koha::Old::Holds->find($reserve_id2);
    ok( $old_hold2, 'Hold moved to old_reserves (with reason)' );
    is( $old_hold2->cancellation_reason, 'PATRON_REQUEST', 'Cancellation reason stored' );

    $schema->storage->txn_rollback;
};

subtest 'confirm_transfer() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $from_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $to_library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item         = $builder->build_sample_item( { library => $from_library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $from_library->branchcode, borrowernumber => $user->borrowernumber } );

    # Create a pending transfer (not yet in transit)
    my $transfer = $item->request_transfer( { to => $to_library, reason => 'Manual' } );
    ok( !$transfer->datesent, 'Transfer not yet in transit' );

    my $checkin = Koha::Checkin->new(
        {
            item_id     => $item->itemnumber,
            user_id     => $user->borrowernumber,
            library_id  => $from_library->branchcode,
            transfer_id => $transfer->id,
        }
    )->store;

    # Confirm the transfer
    $checkin->confirm_transfer;

    $transfer->discard_changes;
    ok( $transfer->datesent, 'Transfer set in transit after confirm_transfer' );

    # Calling again on already-sent transfer is a no-op
    my $datesent = $transfer->datesent;
    $checkin->confirm_transfer;
    $transfer->discard_changes;
    is( $transfer->datesent, $datesent, 'confirm_transfer is idempotent on already-sent transfer' );

    # Test that confirm_transfer returns self for chaining
    my $result = $checkin->confirm_transfer;
    is( ref($result), 'Koha::Checkin', 'confirm_transfer returns $self for chaining' );

    $schema->storage->txn_rollback;
};

subtest 'cancel_transfer() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $from_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $to_library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item         = $builder->build_sample_item( { library => $from_library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $from_library->branchcode, borrowernumber => $user->borrowernumber } );
    t::lib::Mocks::mock_preference( 'UseRecalls', 0 );

    # Create a transfer and set it in transit
    my $transfer = $item->request_transfer( { to => $to_library, reason => 'Manual' } );
    $transfer->transit;
    ok( $transfer->datesent, 'Transfer is in transit' );

    my $checkin = Koha::Checkin->new(
        {
            item_id     => $item->itemnumber,
            user_id     => $user->borrowernumber,
            library_id  => $from_library->branchcode,
            transfer_id => $transfer->id,
        }
    )->store;

    # Cancel the transfer
    $checkin->cancel_transfer;
    $checkin->discard_changes;

    is( $checkin->transfer_id, undef, 'transfer_id cleared after cancel_transfer' );

    $transfer->discard_changes;
    ok( $transfer->datecancelled, 'Transfer has datecancelled set' );
    is( $transfer->cancellation_reason, 'Manual', 'Cancellation reason is Manual' );

    $schema->storage->txn_rollback;
};

subtest 'confirm_recall() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $checkin_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $pickup_library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user            = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron          = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item            = $builder->build_sample_item( { library => $checkin_library->branchcode } );

    t::lib::Mocks::mock_userenv(
        { branchcode => $checkin_library->branchcode, borrowernumber => $user->borrowernumber } );
    t::lib::Mocks::mock_preference( 'UseRecalls', 1 );

    # Test confirm_recall at same library (set to waiting)
    my $recall = Koha::Recall->new(
        {
            patron_id         => $patron->borrowernumber,
            created_date      => \'NOW()',
            biblio_id         => $item->biblionumber,
            pickup_library_id => $checkin_library->branchcode,
            status            => 'requested',
            item_id           => $item->itemnumber,
            expiration_date   => undef,
            item_level        => 1,
        }
    )->store;

    my $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $checkin_library->branchcode,
            recall_id  => $recall->id,
        }
    )->store;

    $checkin->confirm_recall;

    $recall->discard_changes;
    ok( $recall->waiting,         'Recall set to waiting when same library' );
    ok( $recall->expiration_date, 'Expiration date set' );

    $schema->storage->txn_rollback;

    # Test confirm_recall with different pickup library (start transfer)
    $schema->storage->txn_begin;

    $checkin_library = $builder->build_object( { class => 'Koha::Libraries' } );
    $pickup_library  = $builder->build_object( { class => 'Koha::Libraries' } );
    $user            = $builder->build_object( { class => 'Koha::Patrons' } );
    $patron          = $builder->build_object( { class => 'Koha::Patrons' } );
    $item            = $builder->build_sample_item( { library => $checkin_library->branchcode } );

    t::lib::Mocks::mock_userenv(
        { branchcode => $checkin_library->branchcode, borrowernumber => $user->borrowernumber } );
    t::lib::Mocks::mock_preference( 'UseRecalls', 1 );

    $recall = Koha::Recall->new(
        {
            patron_id         => $patron->borrowernumber,
            created_date      => \'NOW()',
            biblio_id         => $item->biblionumber,
            pickup_library_id => $pickup_library->branchcode,
            status            => 'requested',
            item_id           => $item->itemnumber,
            expiration_date   => undef,
            item_level        => 1,
        }
    )->store;

    $checkin = Koha::Checkin->new(
        {
            item_id    => $item->itemnumber,
            user_id    => $user->borrowernumber,
            library_id => $checkin_library->branchcode,
            recall_id  => $recall->id,
        }
    )->store;

    $checkin->confirm_recall;

    $recall->discard_changes;
    ok( $recall->in_transit, 'Recall set to in_transit when pickup differs' );
    is( $recall->item_id, $item->itemnumber, 'Item assigned to recall' );

    # Idempotent - calling again doesn't fail
    $checkin->confirm_recall;
    $recall->discard_changes;
    ok( $recall->in_transit, 'confirm_recall is idempotent on in-transit recall' );

    $schema->storage->txn_rollback;
};

subtest 'verify_bundle' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $user = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    # Create a bundle host with 3 component items
    my $host  = $builder->build_sample_item( { library => $library->branchcode } );
    my $comp1 = $builder->build_sample_item( { library => $library->branchcode } );
    my $comp2 = $builder->build_sample_item( { library => $library->branchcode } );
    my $comp3 = $builder->build_sample_item( { library => $library->branchcode } );

    $host->add_to_bundle($comp1);
    $host->add_to_bundle($comp2);
    $host->add_to_bundle($comp3);

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode, borrowernumber => $user->borrowernumber } );
    t::lib::Mocks::mock_preference( 'BundleLostValue', 1 );

    # Issue and return the bundle to create a checkin
    C4::Circulation::AddIssue( $patron, $host->barcode );
    my ( $doreturn, $messages, $issue, $borrower, $checkin ) =
        C4::Circulation::AddReturn( $host->barcode, $library->branchcode );

    ok( $checkin, 'Checkin created for bundle item' );

    # Verify with 2 of 3 barcodes — comp3 should be marked lost
    my $result = $checkin->verify_bundle( { verified_barcodes => [ $comp1->barcode, $comp2->barcode ] } );

    is( scalar @{ $result->{verified} },   2, '2 items verified' );
    is( scalar @{ $result->{missing} },    1, '1 item marked as missing' );
    is( scalar @{ $result->{unexpected} }, 0, '0 unexpected items' );

    $comp3->discard_changes;
    is( $comp3->itemlost, 1, 'Missing item marked as lost with BundleLostValue' );

    $schema->storage->txn_rollback;
};
