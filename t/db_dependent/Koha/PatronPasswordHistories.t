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
use Koha::AuthUtils;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'cleanup_old_password_history' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    # Create 5 password history entries
    my @passwords = ();
    for my $i ( 1 .. 5 ) {
        my $password_history = Koha::PatronPasswordHistory->new(
            {
                borrowernumber => $patron->borrowernumber,
                password       => Koha::AuthUtils::hash_password("password_$i")
            }
        );
        $password_history->store;
        push @passwords, $password_history;
        sleep(1);    # Ensure different timestamps
    }

    my $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;
    is( $count, 5, 'Initially have 5 password history entries' );

    # Keep 3 most recent
    my $deleted = Koha::PatronPasswordHistories->cleanup_old_password_history( $patron->borrowernumber, 3 );
    is( $deleted, 2, 'Deleted 2 old entries' );

    $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;
    is( $count, 3, 'Now have 3 password history entries' );

    # Keep 1 most recent
    $deleted = Koha::PatronPasswordHistories->cleanup_old_password_history( $patron->borrowernumber, 1 );
    is( $deleted, 2, 'Deleted 2 more entries' );

    $count = Koha::PatronPasswordHistories->search( { borrowernumber => $patron->borrowernumber } )->count;
    is( $count, 1, 'Now have 1 password history entry' );

    # Delete all (count = 0)
    $deleted = Koha::PatronPasswordHistories->cleanup_old_password_history( $patron->borrowernumber, 0 );
    is( $deleted, 1, 'Deleted remaining entry' );

    $schema->storage->txn_rollback;
};

subtest 'has_used_password with category settings' => sub {
    plan tests => 10;

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
            value => {
                categorycode => $category->categorycode,
                password     => Koha::AuthUtils::hash_password('current_password')
            }
        }
    );

    # Create password history
    my $old_password1 = 'old_password_1';
    my $old_password2 = 'old_password_2';

    my $history1 = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => Koha::AuthUtils::hash_password($old_password1)
        }
    );
    $history1->store;
    sleep(1);

    my $history2 = Koha::PatronPasswordHistory->new(
        {
            borrowernumber => $patron->borrowernumber,
            password       => Koha::AuthUtils::hash_password($old_password2)
        }
    );
    $history2->store;

    # Test checking against current password
    my $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => 'current_password',
            current_password => $patron->password
        }
    );
    ok( $is_used, 'Current password detected as already used' );

    # Test checking against history
    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => $old_password1,
            current_password => $patron->password
        }
    );
    ok( $is_used, 'Old password from history detected as already used' );

    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => $old_password2,
            current_password => $patron->password
        }
    );
    ok( $is_used, 'Another old password from history detected as already used' );

    # Test new password
    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => 'brand_new_password',
            current_password => $patron->password
        }
    );
    ok( !$is_used, 'New password not detected as used' );

    # Test with category history_count = 1 (only checks current)
    $category->password_history_count(1)->store;

    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => $old_password1,
            current_password => $patron->password
        }
    );
    ok( !$is_used, 'With history_count=1, old passwords not checked against history' );

    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => 'current_password',
            current_password => $patron->password
        }
    );
    ok( $is_used, 'With history_count=1, current password still checked' );

    # Test with category history_count = 0 (no checking)
    $category->password_history_count(0)->store;

    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => 'current_password',
            current_password => $patron->password
        }
    );
    ok( !$is_used, 'With history_count=0, no password checking performed' );

    # Test fallback to system preference
    $category->password_history_count(undef)->store;
    t::lib::Mocks::mock_preference( 'PasswordHistoryCount', 2 );

    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $patron->borrowernumber,
            password         => $old_password2,
            current_password => $patron->password
        }
    );
    ok( $is_used, 'Falls back to system preference when category setting is null' );

    # Test without current password parameter
    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber => $patron->borrowernumber,
            password       => $old_password1
        }
    );
    ok( $is_used, 'Can check password history without current_password parameter' );

    # Test with patron that has no password history
    my $new_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->categorycode,
                password     => Koha::AuthUtils::hash_password('new_patron_password')
            }
        }
    );

    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber   => $new_patron->borrowernumber,
            password         => 'some_password',
            current_password => $new_patron->password
        }
    );
    ok( !$is_used, 'Returns false for patron with no password history' );

    $schema->storage->txn_rollback;
};

subtest 'edge cases and validation' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Test with missing parameters
    my $is_used = Koha::PatronPasswordHistories->has_used_password( {} );
    ok( !$is_used, 'Returns false with no parameters' );

    $is_used = Koha::PatronPasswordHistories->has_used_password( { borrowernumber => 99999 } );
    ok( !$is_used, 'Returns false with missing password' );

    $is_used = Koha::PatronPasswordHistories->has_used_password( { password => 'test' } );
    ok( !$is_used, 'Returns false with missing borrowernumber' );

    # Test with non-existent patron
    $is_used = Koha::PatronPasswordHistories->has_used_password(
        {
            borrowernumber => 99999,
            password       => 'test_password'
        }
    );
    ok( !$is_used, 'Returns false for non-existent patron' );

    $schema->storage->txn_rollback;
};
