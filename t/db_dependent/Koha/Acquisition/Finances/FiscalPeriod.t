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
use Test::More tests => 6;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Acquisition::Finances::FiscalPeriod;
use Koha::Acquisition::Finances::FiscalPeriods;
use Koha::Acquisition::Finances::Ledgers;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { status => 1 }
        }
    );

    # Attach an active ledger
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => {
                fiscal_period_id => $fiscal_period->fiscal_period_id,
                status           => 1
            }
        }
    );

    # Deactivate the fiscal period; cascade should deactivate the ledger
    $fiscal_period->status(0)->store;
    $ledger->discard_changes;

    is( $fiscal_period->status, 0, 'Fiscal period status updated to 0' );
    is( $ledger->status,        0, 'Ledger status cascaded to 0' );

    # Re-activating the fiscal period should NOT re-activate the ledger
    $fiscal_period->status(1)->store;
    $ledger->discard_changes;

    is( $ledger->status, 0, 'Re-activating fiscal period does not re-activate ledger' );

    $schema->storage->txn_rollback;
};

subtest 'store() with no_cascade tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { status => 1 }
        }
    );

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => {
                fiscal_period_id => $fiscal_period->fiscal_period_id,
                status           => 1
            }
        }
    );

    $fiscal_period->status(0)->store( { no_cascade => 1 } );
    $ledger->discard_changes;

    is( $fiscal_period->status, 0, 'Fiscal period status updated to 0' );
    is( $ledger->status,        1, 'Ledger status not cascaded when no_cascade is set' );

    $schema->storage->txn_rollback;
};

subtest 'cascade_to_ledgers() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { status => 1 }
        }
    );

    my $active_ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => {
                fiscal_period_id => $fiscal_period->fiscal_period_id,
                status           => 1
            }
        }
    );

    my $inactive_ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => {
                fiscal_period_id => $fiscal_period->fiscal_period_id,
                status           => 0
            }
        }
    );

    # Deactivate fiscal period and cascade
    $fiscal_period->status(0);
    $fiscal_period->cascade_to_ledgers;

    $active_ledger->discard_changes;
    $inactive_ledger->discard_changes;

    is( $active_ledger->status,   0, 'Active ledger status cascaded to inactive' );
    is( $inactive_ledger->status, 0, 'Already-inactive ledger remains inactive' );

    # Create a fresh active fiscal period and cascade active status (should not affect ledger)
    my $fp2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { status => 1 }
        }
    );
    my $inactive_ledger2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::Ledgers',
            value => {
                fiscal_period_id => $fp2->fiscal_period_id,
                status           => 0
            }
        }
    );

    $fp2->status(1);
    $fp2->cascade_to_ledgers;
    $inactive_ledger2->discard_changes;

    is( $inactive_ledger2->status, 0, 'Cascading active status does not reactivate inactive ledger' );

    # A fiscal period with no ledgers should cascade without errors
    my $fp_no_ledgers = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { status => 1 }
        }
    );
    $fp_no_ledgers->status(0);
    eval { $fp_no_ledgers->cascade_to_ledgers };
    ok( !$@, 'Cascade on fiscal period with no ledgers does not throw an error' );

    $schema->storage->txn_rollback;
};

subtest 'managing_library() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $fiscal_period_with_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { managing_branch => $library->branchcode }
        }
    );
    my $fiscal_period_no_branch = $builder->build_object(
        {
            class => 'Koha::Acquisition::Finances::FiscalPeriods',
            value => { managing_branch => undef }
        }
    );

    my $managing_library = $fiscal_period_with_branch->managing_library;
    is( $managing_library->branchcode, $library->branchcode, 'managing_library returns the correct library' );

    is( $fiscal_period_no_branch->managing_library, undef, 'managing_library returns undef when no branch set' );

    $schema->storage->txn_rollback;
};

subtest '_object_hierarchy() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object( { class => 'Koha::Acquisition::Finances::FiscalPeriods' } );

    my $hierarchy = $fiscal_period->_object_hierarchy;

    is( $hierarchy->{object},   'fiscal_period', 'object is fiscal_period' );
    is( $hierarchy->{parent},   undef,           'parent is undef (top of hierarchy)' );
    is( $hierarchy->{child},    'ledger',        'child is ledger' );
    is( $hierarchy->{children}, 'ledgers',       'children is ledgers' );

    $schema->storage->txn_rollback;
};
