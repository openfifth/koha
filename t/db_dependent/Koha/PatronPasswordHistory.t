#!/usr/bin/perl

# Copyright 2025 Koha Development team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 4;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::PatronPasswordHistory;
use Koha::PatronPasswordHistories;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'basic functionality' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => { password_history_count => 3 }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );

    my $password_history = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => 'plaintext_password'
        }
    );

    ok( $password_history, 'PatronPasswordHistory object created' );
    isa_ok( $password_history, 'Koha::PatronPasswordHistory' );

    $password_history->store;
    ok( $password_history->in_storage, 'PatronPasswordHistory stored successfully' );

    $schema->storage->txn_rollback;
};

subtest 'password hashing on store' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => { password_history_count => 3 }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );

    my $plain_password   = 'test_password_123';
    my $password_history = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => $plain_password
        }
    );

    is( $password_history->password, $plain_password, 'Password is plain text before store' );

    $password_history->store;

    isnt( $password_history->password, $plain_password, 'Password is hashed after store' );
    like( $password_history->password, qr/^\$2a\$/, 'Password is bcrypt hashed' );

    # Test that already hashed password is not re-hashed
    my $hashed_password   = $password_history->password;
    my $password_history2 = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => $hashed_password
        }
    );

    $password_history2->store;
    is( $password_history2->password, $hashed_password, 'Already hashed password is not re-hashed' );

    $schema->storage->txn_rollback;
};

subtest 'cleanup of old history entries' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => { password_history_count => 3 }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );

    # Create multiple password history entries
    for my $i ( 1 .. 5 ) {
        my $password_history = Koha::PatronPasswordHistory->new(
            {
                borrowernumber => $patron->borrowernumber,
                password       => "password_$i"
            }
        );
        $password_history->store;
        sleep(1);    # Ensure different created_on timestamps
    }

    my $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;

    # With password_history_count = 3, we should keep 2 historical entries (3 - 1 for current)
    is( $count, 2, 'Old password history entries cleaned up correctly (kept 2 for history_count 3)' );

    # Test with different category setting - add more entries to test the limit
    $category->password_history_count(4)->store;

    # Add more password entries to exceed the limit
    for my $i ( 6 .. 10 ) {
        my $password_history = Koha::PatronPasswordHistory->new(
            {
                borrowernumber => $patron->borrowernumber,
                password       => "password_$i"
            }
        );
        $password_history->store;
        sleep(1);
    }

    $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;

    # With password_history_count = 4, we should keep 3 historical entries (4 - 1 for current)
    is( $count, 3, 'Cleanup respects updated category password_history_count and does not exceed limit' );

    # Test with history_count = 1 (should keep 1 historical entry)
    $category->password_history_count(1)->store;

    my $password_history2 = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => "password_7"
        }
    );
    $password_history2->store;

    $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;

    is( $count, 1, 'With history_count=1, keeps exactly 1 entry' );

    # Test with history_count = 0 (should delete all)
    $category->password_history_count(0)->store;

    my $password_history3 = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => "password_8"
        }
    );
    $password_history3->store;

    $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;

    is( $count, 0, 'With history_count=0, deletes all entries' );

    # Test fallback to system preference
    $category->password_history_count(undef)->store;
    t::lib::Mocks::mock_preference( 'PasswordHistoryCount', 2 );

    my $password_history4 = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => "password_9"
        }
    );
    $password_history4->store;

    $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;

    is( $count, 1, 'Falls back to system preference when category setting is null' );

    $schema->storage->txn_rollback;
};
