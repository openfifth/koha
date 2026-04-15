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
use Test::More tests => 5;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Acquisition::Finances::Ledger;
use Koha::Acquisition::Finances::Ledgers;
use Koha::Acquisition::Finances::Funds;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 1 }
        }
    );

    # Attach an active fund
    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id => $ledger->ledger_id,
                status    => 1
            }
        }
    );

    # Deactivate the ledger; cascade should deactivate the fund
    $ledger->status(0)->store;
    $fund->discard_changes;

    is( $ledger->status, 0, 'Ledger status updated to 0' );
    is( $fund->status,   0, 'Fund status cascaded to 0' );

    # Re-activating the ledger should NOT re-activate the fund
    $ledger->status(1)->store;
    $fund->discard_changes;

    is( $fund->status, 0, 'Re-activating ledger does not re-activate fund' );

    $schema->storage->txn_rollback;
};

subtest 'store() with no_cascade tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 1 }
        }
    );

    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id => $ledger->ledger_id,
                status    => 1
            }
        }
    );

    $ledger->status(0)->store( { no_cascade => 1 } );
    $fund->discard_changes;

    is( $ledger->status, 0, 'Ledger status updated to 0' );
    is( $fund->status,   1, 'Fund status not cascaded when no_cascade is set' );

    $schema->storage->txn_rollback;
};

subtest 'cascade_to_funds() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 1 }
        }
    );

    my $active_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id => $ledger->ledger_id,
                status    => 1
            }
        }
    );

    my $inactive_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id => $ledger->ledger_id,
                status    => 0
            }
        }
    );

    $ledger->status(0);
    $ledger->cascade_to_funds;

    $active_fund->discard_changes;
    $inactive_fund->discard_changes;

    is( $active_fund->status,   0, 'Active fund status cascaded to inactive' );
    is( $inactive_fund->status, 0, 'Already-inactive fund remains inactive' );

    # Cascading an active status should not reactivate an inactive fund
    my $ledger2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 1 }
        }
    );
    my $inactive_fund2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Funds',
            value => {
                ledger_id => $ledger2->ledger_id,
                status    => 0
            }
        }
    );

    $ledger2->status(1);
    $ledger2->cascade_to_funds;
    $inactive_fund2->discard_changes;

    is( $inactive_fund2->status, 0, 'Cascading active status does not reactivate inactive fund' );

    # A ledger with no funds should cascade without errors
    my $ledger_no_funds = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { status => 1 }
        }
    );
    $ledger_no_funds->status(0);
    eval { $ledger_no_funds->cascade_to_funds };
    ok( !$@, 'Cascade on ledger with no funds does not throw an error' );

    $schema->storage->txn_rollback;
};

subtest 'managing_library() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $ledger_with_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { managing_branch => $library->branchcode }
        }
    );
    my $ledger_no_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => { managing_branch => undef }
        }
    );

    my $managing_library = $ledger_with_branch->managing_library;
    is( $managing_library->branchcode, $library->branchcode, 'managing_library returns the correct library' );

    is( $ledger_no_branch->managing_library, undef, 'managing_library returns undef when no branch set' );

    $schema->storage->txn_rollback;
};
