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

use Test::More tests => 9;
use Test::NoWarnings;
use Test::MockModule;
use Test::Exception;
use Test::Warn;

use C4::Context;
use Koha::Account;
use Koha::Account::Lines;
use Koha::Patrons;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->dbh->{PrintError} = 0;
my $builder = t::lib::TestBuilder->new;
C4::Context->interface('commandline');

subtest 'add_print_notice_charge_if_needed with charging disabled' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Create category with print notice charging disabled (0.00)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.00 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

    my $initial_balance = $account->balance;

    my $result = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron->branchcode
        }
    );

    is( $result,                undef,            'No charge applied when charging disabled' );
    is( $account->balance,      $initial_balance, 'Account balance unchanged' );
    is( $account->lines->count, 0,                'No account lines created' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed with charging enabled' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.75)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.75 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

    my $initial_balance = $account->balance;

    my $result = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron->branchcode
        }
    );

    isa_ok( $result, 'Koha::Account::Line', 'Returns account line object' );
    is( $account->balance,        $initial_balance + 0.75, 'Account balance increased by charge amount' );
    is( $result->debit_type_code, 'PRINT_NOTICE',          'Correct debit type applied' );
    cmp_ok( $result->amount,            '==', 0.75, 'Correct amount charged' );
    cmp_ok( $result->amountoutstanding, '==', 0.75, 'Full amount outstanding' );
    is( $result->borrowernumber, $patron->borrowernumber, 'Correct patron charged' );
    is( $result->interface,      'commandline',           'Correct interface recorded' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed with custom amount' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.50)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.50 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

    my $custom_amount = 1.25;
    my $result        = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'PREDUE',
            library_id  => $patron->branchcode,
            amount      => $custom_amount
        }
    );

    isa_ok( $result, 'Koha::Account::Line', 'Returns account line object' );
    is( $result->amount,   $custom_amount, 'Custom amount used instead of system preference' );
    is( $account->balance, $custom_amount, 'Account balance reflects custom amount' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed with zero amount' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Create category with charging disabled (0.00)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.00 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

    my $result = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'HOLD',
            library_id  => $patron->branchcode
        }
    );

    is( $result,                undef, 'No charge applied when amount is zero' );
    is( $account->balance,      0,     'Account balance unchanged' );
    is( $account->lines->count, 0,     'No account lines created' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed validation tests' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.50 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );

    # Test with invalid negative amount
    my $result1 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron->branchcode,
            amount      => -0.50
        }
    );
    is( $result1, undef, 'No charge applied for negative amount' );

    # Test with invalid non-numeric amount
    my $result2 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron->branchcode,
            amount      => 'invalid'
        }
    );
    is( $result2, undef, 'No charge applied for non-numeric amount' );

    # Test with valid amount works
    my $result3 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron->branchcode,
            amount      => 1.00
        }
    );
    isa_ok( $result3, 'Koha::Account::Line', 'Valid amount works correctly' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed without notice code' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.50)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.50 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

    my $result = $patron->add_print_notice_charge_if_needed( { library_id => $patron->branchcode } );

    isa_ok( $result, 'Koha::Account::Line', 'Returns account line object even without notice code' );
    cmp_ok( $result->amount, '==', 0.50, 'Category amount used' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed library_id handling' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.50)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.50 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { categorycode => $category->categorycode } } );
    my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );

    # Get the patron's library for testing
    my $patron_library = $patron->branchcode;

    # Mock userenv for default library
    my $mock_context = Test::MockModule->new('C4::Context');
    $mock_context->mock(
        'userenv',
        sub {
            return { branch => $patron_library };
        }
    );

    # Test with explicit library_id
    my $result1 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron_library
        }
    );
    is( $result1->branchcode, $patron_library, 'Explicit library_id used when provided' );

    # Test without library_id (should use userenv)
    my $result2 = $patron->add_print_notice_charge_if_needed( { notice_code => 'PREDUE' } );
    is( $result2->branchcode, $patron_library, 'Default library from userenv used when not provided' );

    # Test with undefined userenv
    $mock_context->mock( 'userenv', sub { return; } );
    my $result3 = $patron->add_print_notice_charge_if_needed( { notice_code => 'HOLD' } );
    isa_ok( $result3, 'Koha::Account::Line', 'Still works with undefined userenv' );
    is( $result3->branchcode, undef, 'Library_id is undef when no userenv' );

    $schema->storage->txn_rollback;
};

subtest 'add_print_notice_charge_if_needed category isolation test' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    # Create two categories - one with charging enabled, one disabled
    my $category_enabled =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 1.25 } } );
    my $category_disabled =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.00 } } );

    # Create patrons in each category
    my $patron_enabled = $builder->build_object(
        { class => 'Koha::Patrons', value => { categorycode => $category_enabled->categorycode } } );
    my $patron_disabled = $builder->build_object(
        { class => 'Koha::Patrons', value => { categorycode => $category_disabled->categorycode } } );

    my $account_enabled  = Koha::Account->new( { patron_id => $patron_enabled->borrowernumber } );
    my $account_disabled = Koha::Account->new( { patron_id => $patron_disabled->borrowernumber } );

    # Test patron with enabled category gets charged
    my $result_enabled = $patron_enabled->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron_enabled->branchcode
        }
    );

    isa_ok( $result_enabled, 'Koha::Account::Line', 'Patron with enabled category gets charged' );
    cmp_ok( $result_enabled->amount,   '==', 1.25, 'Correct amount from enabled category' );
    cmp_ok( $account_enabled->balance, '==', 1.25, 'Enabled patron account balance updated' );

    # Test patron with disabled category does not get charged
    my $result_disabled = $patron_disabled->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron_disabled->branchcode
        }
    );

    is( $result_disabled, undef, 'Patron with disabled category not charged' );
    cmp_ok( $account_disabled->balance, '==', 0, 'Disabled patron account balance unchanged' );
    is( $account_disabled->lines->count, 0, 'No account lines for disabled category patron' );

    $schema->storage->txn_rollback;
};
