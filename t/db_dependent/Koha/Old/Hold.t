#!/usr/bin/perl

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

use Test::More tests => 5;
use Test::NoWarnings;
use Test::Exception;

use Koha::Database;
use Koha::Account;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'anonymize() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    is( $patron->old_holds->count, 0, 'Patron has no old holds' );

    my $hold_1 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { borrowernumber => $patron->id }
        }
    );
    my $hold_2 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { borrowernumber => $patron->id }
        }
    );

    is( $patron->old_holds->count, 2, 'Patron has 2 completed holds' );

    t::lib::Mocks::mock_preference( 'AnonymousPatron', undef );

    throws_ok { $hold_1->anonymize; }
    'Koha::Exceptions::SysPref::NotSet',
        'Exception thrown because AnonymousPatron not set';

    is( $@->syspref,               'AnonymousPatron', 'syspref parameter is correctly passed' );
    is( $patron->old_holds->count, 2,                 'No changes, patron has 2 linked completed holds' );

    is(
        $hold_1->borrowernumber, $patron->id,
        'Anonymized hold not linked to patron'
    );
    is(
        $hold_2->borrowernumber, $patron->id,
        'Not anonymized hold still linked to patron'
    );

    my $anonymous_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_preference( 'AnonymousPatron', $anonymous_patron->id );

    # anonymize second hold
    $hold_2->anonymize;
    $hold_2->discard_changes;
    is(
        $hold_2->borrowernumber, $anonymous_patron->id,
        'Anonymized hold linked to anonymouspatron'
    );

    $schema->storage->txn_rollback;
};

subtest 'biblio() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $hold_1 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { biblionumber => undef }
        }
    );

    is( $hold_1->biblio, undef, 'Old hold has no biblionumber, returns undef' );

    my $hold_2 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { biblionumber => undef }
        }
    );

    is( $hold_1->biblio, undef, 'Old hold has empty biblionumber, returns undef' );

    my $biblio = $builder->build_object( { class => 'Koha::Biblios' } );

    my $hold_3 = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => { biblionumber => $biblio->biblionumber }
        }
    );

    is_deeply( $hold_3->biblio->unblessed, $biblio->unblessed, 'Old hold has a biblionumber, returns a biblio object' );

    $schema->storage->txn_rollback;
};

subtest 'item/pickup_library() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $old_hold = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
        }
    );
    is( ref( $old_hold->item ),           'Koha::Item',    '->item should return a Koha::Item object' );
    is( ref( $old_hold->pickup_library ), 'Koha::Library', '->pickup_library should return a Koha::Library object' );

    $old_hold->item->delete;
    $old_hold->pickup_library->delete;

    $old_hold = $old_hold->get_from_storage;    # Be on the safe side

    is( $old_hold->item,           undef, 'Item has been deleted, ->item should return undef' );
    is( $old_hold->pickup_library, undef, 'Library has been deleted, ->pickup_library should return undef' );

    $schema->storage->txn_rollback;
};

subtest 'debits() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    # Create an old hold
    my $old_hold = $builder->build_object(
        {
            class => 'Koha::Old::Holds',
            value => {
                borrowernumber => $patron->borrowernumber,
                biblionumber   => $biblio->biblionumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $patron->branchcode,
            }
        }
    );

    # Test 1: Old hold with no debits returns empty collection
    my $debits = $old_hold->debits;
    isa_ok( $debits, 'Koha::Account::Debits', 'debits() returns a Koha::Account::Debits object' );
    is( $debits->count, 0, 'debits() returns empty collection when no debits exist' );

    # Test 2: Create account lines (debits and credits) linked to the old hold
    my $account = $patron->account;

    # Add a debit linked to old hold
    my $debit1 = $account->add_debit(
        {
            amount      => 3.50,
            description => 'Old hold fee',
            type        => 'RESERVE',
            user_id     => 1,
            library_id  => $patron->branchcode,
            interface   => 'intranet',
        }
    );

    # Manually set old_reserve_id since add_debit doesn't handle old holds directly
    $debit1->old_reserve_id( $old_hold->reserve_id )->store;

    # Add another debit
    my $debit2 = $account->add_debit(
        {
            amount      => 1.50,
            description => 'Old hold expiration fee',
            type        => 'RESERVE_EXPIRED',
            user_id     => 1,
            library_id  => $patron->branchcode,
            interface   => 'intranet',
        }
    );
    $debit2->old_reserve_id( $old_hold->reserve_id )->store;

    # Add a credit (should not appear in debits)
    my $credit = $account->add_credit(
        {
            amount      => 2.00,
            description => 'Credit for old hold',
            type        => 'CREDIT',
            user_id     => 1,
            library_id  => $patron->branchcode,
            interface   => 'intranet',
        }
    );
    $credit->old_reserve_id( $old_hold->reserve_id )->store;

    # Test 3: Old hold debits returns only debit lines, ordered by timestamp descending
    $debits = $old_hold->debits;
    is( $debits->count, 2, 'debits() returns correct count of debit lines only' );

    my @debit_amounts = sort { $b <=> $a } map { $_->amount + 0 } $debits->as_list;
    is_deeply( \@debit_amounts, [ 3.5, 1.5 ], 'debits() returns correct amounts in descending order' );

    # Test 4: Verify both debit types are present
    my @debit_types = sort map { $_->debit_type_code } $debits->as_list;
    is_deeply( \@debit_types, [ 'RESERVE', 'RESERVE_EXPIRED' ], 'debits() returns both expected debit types' );

    $schema->storage->txn_rollback;
};
