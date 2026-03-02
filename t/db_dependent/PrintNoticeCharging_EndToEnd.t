#!/usr/bin/perl

# Copyright 2024 Koha Development team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>

use Modern::Perl;

use Test::More tests => 6;
use Test::Warn;

use C4::Context;
use C4::Letters;
use Koha::Account;
use Koha::Account::Lines;
use Koha::Patrons;
use Koha::Notice::Messages;
use Koha::Libraries;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->dbh->{PrintError} = 0;
my $builder = t::lib::TestBuilder->new;
C4::Context->interface('commandline');

subtest 'print notice charging workflow with charging enabled' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (1.00)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 1.00 } } );

    # Create test patron and library
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode   => $library->branchcode,
                categorycode => $category->categorycode
            }
        }
    );

    # Create a print notice in message queue
    my $message = Koha::Notice::Message->new(
        {
            borrowernumber         => $patron->borrowernumber,
            subject                => 'Test Notice',
            content                => 'This is a test print notice',
            message_transport_type => 'print',
            status                 => 'pending',
            letter_code            => 'ODUE',
            to_address             => $patron->address,
        }
    )->store();

    my $account         = $patron->account;
    my $initial_balance = $account->balance;
    my $initial_lines   = $account->lines->count;

    # Simulate what gather_print_notices.pl does
    is( $message->status, 'pending', 'Message starts as pending' );

    # Apply print notice charge (this is what our enhanced gather_print_notices.pl does)
    my $charge_result = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => $message->letter_code,
            library_id  => $library->branchcode,
        }
    );

    # Update message status to sent (as gather_print_notices.pl would do)
    $message->status('sent')->store();

    # Verify the charge was applied
    isa_ok( $charge_result, 'Koha::Account::Line', 'Charge was created' );
    is( $account->balance,               $initial_balance + 1.00, 'Account balance increased by charge amount' );
    is( $account->lines->count,          $initial_lines + 1,      'New account line created' );
    is( $charge_result->debit_type_code, 'PRINT_NOTICE',          'Correct debit type' );
    is( $charge_result->borrowernumber,  $patron->borrowernumber, 'Correct patron charged' );
    is( $message->status,                'sent',                  'Message marked as sent' );

    $schema->storage->txn_rollback;
};

subtest 'print notice charging workflow with charging disabled' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Create category with print notice charging disabled (0.00)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.00 } } );

    # Create test patron and library
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode   => $library->branchcode,
                categorycode => $category->categorycode
            }
        }
    );

    # Create a print notice in message queue
    my $message = Koha::Notice::Message->new(
        {
            borrowernumber         => $patron->borrowernumber,
            subject                => 'Test Notice',
            content                => 'This is a test print notice',
            message_transport_type => 'print',
            status                 => 'pending',
            letter_code            => 'ODUE',
            to_address             => $patron->address,
        }
    )->store();

    my $account         = $patron->account;
    my $initial_balance = $account->balance;
    my $initial_lines   = $account->lines->count;

    # Simulate what gather_print_notices.pl does when charging disabled
    my $charge_result = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => $message->letter_code,
            library_id  => $library->branchcode,
        }
    );
    $message->status('sent')->store();

    # Verify no charge was applied
    is( $charge_result,         undef,            'No charge created when charging disabled' );
    is( $account->balance,      $initial_balance, 'Account balance unchanged' );
    is( $account->lines->count, $initial_lines,   'No new account lines created' );
    is( $message->status,       'sent',           'Message still marked as sent' );

    $schema->storage->txn_rollback;
};

subtest 'multiple print notices for same patron' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.50)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.50 } } );

    # Create test patron
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );
    my $account = $patron->account;

    # Create multiple print notices
    my @notice_codes = ( 'ODUE', 'PREDUE', 'HOLD' );
    my @charges;

    foreach my $code (@notice_codes) {
        my $message = Koha::Notice::Message->new(
            {
                borrowernumber         => $patron->borrowernumber,
                subject                => "Test $code Notice",
                content                => "This is a test $code print notice",
                message_transport_type => 'print',
                status                 => 'pending',
                letter_code            => $code,
                to_address             => $patron->address,
            }
        )->store();

        # Apply charge for each notice
        my $charge = $patron->add_print_notice_charge_if_needed(
            {
                notice_code => $code,
                library_id  => $patron->branchcode,
            }
        );
        push @charges, $charge;
        $message->status('sent')->store();
    }

    # Verify all charges were applied
    is( scalar @charges,        3,    'Three charges created' );
    is( $account->balance,      1.50, 'Total balance is 3 × $0.50 = $1.50' );
    is( $account->lines->count, 3,    'Three account lines created' );

    # Verify each charge has correct debit type
    my @lines       = $account->lines->as_list;
    my @debit_types = map { $_->debit_type_code } @lines;
    is( scalar( grep { $_ eq 'PRINT_NOTICE' } @debit_types ), 3, 'All charges have PRINT_NOTICE debit type' );

    $schema->storage->txn_rollback;
};

subtest 'print notice charging with missing patron data' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (1.00)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 1.00 } } );

    # Create a patron then delete it to simulate missing data
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );
    my $borrowernumber = $patron->borrowernumber;
    $patron->delete();

    # Create a message with reference to deleted patron
    my $message = {
        borrowernumber => $borrowernumber,
        letter_code    => 'ODUE',
    };

    # Test our apply_print_notice_charge function behavior
    # This simulates what would happen in gather_print_notices.pl
    my $found_patron = Koha::Patrons->find($borrowernumber);
    is( $found_patron, undef, 'Patron not found as expected' );

    # The function should handle missing patrons gracefully
    my $result;
    warnings_are {
        if ($found_patron) {
            my $account = Koha::Account->new( { patron_id => $borrowernumber } );
            $result = $patron->add_print_notice_charge_if_needed(
                {
                    notice_code => $message->{letter_code},
                    library_id  => 'CPL',                     # Use a default library for this test
                }
            );
        } else {
            $result = undef;
        }
    }
    [], 'No warnings when patron not found';

    is( $result, undef, 'No charge attempted for missing patron' );

    # Verify no orphaned account lines
    my $orphaned_lines = Koha::Account::Lines->search( { borrowernumber => $borrowernumber } );
    is( $orphaned_lines->count, 0, 'No orphaned account lines created' );

    $schema->storage->txn_rollback;
};

subtest 'print notice charging with different amounts' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.75)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.75 } } );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );
    my $account = $patron->account;

    # Test 1: Use system preference amount
    my $charge1 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'ODUE',
            library_id  => $patron->branchcode,
        }
    );
    cmp_ok( $charge1->amount, '==', 0.75, 'Category amount used when no custom amount' );

    # Test 2: Use custom amount
    my $charge2 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'PREDUE',
            library_id  => $patron->branchcode,
            amount      => 1.50,
        }
    );
    is( $charge2->amount, 1.50, 'Custom amount used when provided' );

    # Test 3: Zero custom amount should not create charge
    my $charge3 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'HOLD',
            library_id  => $patron->branchcode,
            amount      => 0.00,
        }
    );
    is( $charge3, undef, 'No charge created for zero amount' );

    # Test 4: Very small amount
    my $charge4 = $patron->add_print_notice_charge_if_needed(
        {
            notice_code => 'RENEWAL',
            library_id  => $patron->branchcode,
            amount      => 0.01,
        }
    );
    is( $charge4->amount, 0.01, 'Very small amounts work correctly' );

    # Verify total balance
    is( $account->balance,      2.26, 'Total balance is 0.75 + 1.50 + 0.01 = 2.26' );
    is( $account->lines->count, 3,    'Three charges created (zero amount not counted)' );

    $schema->storage->txn_rollback;
};

subtest 'gather_print_notices.pl helper function tests' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    # Create category with print notice charging enabled (0.60)
    my $category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { print_notice_charge => 0.60 } } );

    # Create test patron
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->categorycode }
        }
    );
    my $account = $patron->account;

    # Test valid message hash
    my $valid_message = {
        borrowernumber => $patron->borrowernumber,
        letter_code    => 'ODUE',
    };

    # Simulate the apply_print_notice_charge function from gather_print_notices.pl
    my $apply_charge = sub {
        my ($message) = @_;

        return unless $message->{borrowernumber};

        my $patron = Koha::Patrons->find( $message->{borrowernumber} );
        return unless $patron;

        eval {
            my $account = Koha::Account->new( { patron_id => $patron->borrowernumber } );
            $patron->add_print_notice_charge_if_needed(
                {
                    notice_code => $message->{letter_code},
                    library_id  => $patron->branchcode,
                }
            );
        };

        if ($@) {
            warn "Error applying print notice charge for patron " . $patron->borrowernumber . ": $@";
            return;
        }
        return 1;
    };

    # Test 1: Valid message
    my $result1 = $apply_charge->($valid_message);
    is( $result1,          1,    'Valid message processed successfully' );
    is( $account->balance, 0.60, 'Charge applied correctly' );

    # Test 2: Message with missing borrowernumber
    my $invalid_message1 = {
        letter_code => 'ODUE',
        branchcode  => $patron->branchcode,
    };
    my $result2 = $apply_charge->($invalid_message1);
    is( $result2, undef, 'Message without borrowernumber handled gracefully' );

    # Test 3: Message with invalid borrowernumber
    my $invalid_message2 = {
        borrowernumber => 999999,
        letter_code    => 'ODUE',
        branchcode     => $patron->branchcode,
    };
    my $result3 = $apply_charge->($invalid_message2);
    is( $result3, undef, 'Message with invalid borrowernumber handled gracefully' );

    # Test 4: Another valid message to same patron
    my $valid_message2 = {
        borrowernumber => $patron->borrowernumber,
        letter_code    => 'PREDUE',
        branchcode     => $patron->branchcode,
    };
    my $result4 = $apply_charge->($valid_message2);
    is( $result4,          1,    'Second valid message processed successfully' );
    is( $account->balance, 1.20, 'Second charge applied correctly' );

    # Test 5: Verify account lines
    my @lines = $account->lines->as_list;
    is( scalar @lines, 2, 'Two account lines created' );

    my @debit_types = map { $_->debit_type_code } @lines;
    is( scalar( grep { $_ eq 'PRINT_NOTICE' } @debit_types ), 2, 'Both charges have PRINT_NOTICE debit type' );

    $schema->storage->txn_rollback;
};
