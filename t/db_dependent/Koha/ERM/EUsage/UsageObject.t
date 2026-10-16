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

use Test::NoWarnings;
use Test::More tests => 2;
use Test::Exception;
use Test::MockModule;

use Koha::Database;
use Koha::ERM::EUsage::MonthlyUsage;
use Koha::ERM::EUsage::MonthlyUsages;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'monthly_usages' => sub {

    plan tests => 30;

    $schema->storage->txn_begin;

    my $title = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageTitles' } );

    my @reported;
    my $job_callbacks = { report_info_callback => sub { push @reported, shift } };

    my $usage = {
        title_id               => $title->title_id,
        usage_data_provider_id => $title->usage_data_provider_id,
        year                   => 2023,
        month                  => 1,
        usage_count            => 5,
        metric_type            => 'Total_Item_Requests',
        report_type            => 'TR_J1',
    };

    # A new monthly usage is added
    my $monthly_usages = $title->monthly_usages( [$usage], $job_callbacks );
    is( $monthly_usages->count,             1, 'A new monthly usage is added' );
    is( $monthly_usages->next->usage_count, 5, 'usage_count is stored' );
    is_deeply( \@reported, ['added_mus'], 'added_mus is reported' );

    # The same monthly usage is skipped
    @reported       = ();
    $monthly_usages = $title->monthly_usages( [$usage], $job_callbacks );
    is( $monthly_usages->count, 1, 'The same monthly usage is not added twice' );
    is_deeply( \@reported, ['skipped_mus'], 'skipped_mus is reported' );

    # A changed usage_count updates the existing row
    @reported       = ();
    $monthly_usages = $title->monthly_usages( [ { %{$usage}, usage_count => 8 } ], $job_callbacks );
    is( $monthly_usages->count,             1, 'A changed usage_count does not add a row' );
    is( $monthly_usages->next->usage_count, 8, 'usage_count is updated' );
    is_deeply( \@reported, ['updated_mus'], 'updated_mus is reported' );

    # A different identity adds a row
    @reported       = ();
    $monthly_usages = $title->monthly_usages( [ { %{$usage}, month => 2 } ], $job_callbacks );
    is( $monthly_usages->count, 2, 'A different month is a new row' );
    is_deeply( \@reported, ['added_mus'], 'added_mus is reported for the new month' );

    # Duplicates from earlier harvests are removed, keeping the oldest row
    my $kept = $title->monthly_usages->search( { month => 1 } )->next;
    Koha::ERM::EUsage::MonthlyUsage->new(
        { %{ $kept->unblessed }, monthly_usage_summary_id => undef, usage_count => 100 } )->store;
    is( $title->monthly_usages->search( { month => 1 } )->count, 2, 'A duplicate row exists' );

    @reported = ();
    $title->monthly_usages( [ { %{$usage}, usage_count => 8 } ], $job_callbacks );
    my $remaining = $title->monthly_usages->search( { month => 1 } );
    is( $remaining->count, 1, 'The duplicate row is removed' );
    is(
        $remaining->next->monthly_usage_summary_id, $kept->monthly_usage_summary_id,
        'The oldest row is the one kept'
    );
    is_deeply( \@reported, ['skipped_mus'], 'The kept row already had the right usage_count' );

    # Works without job callbacks
    $monthly_usages = $title->monthly_usages( [ { %{$usage}, month => 3 } ] );
    is( $monthly_usages->count, 3, 'Monthly usage is added without job callbacks' );

    # A zero usage_count with no row changes nothing
    @reported       = ();
    $monthly_usages = $title->monthly_usages( [ { %{$usage}, month => 4, usage_count => 0 } ], $job_callbacks );
    is( $monthly_usages->count, 3, 'A zero month is not stored' );
    is_deeply( \@reported, [], 'Nothing is reported for a zero month without a row' );

    # A zero usage_count deletes the existing row
    @reported       = ();
    $monthly_usages = $title->monthly_usages( [ { %{$usage}, month => 3, usage_count => 0 } ], $job_callbacks );
    is( $monthly_usages->count,                                  2, 'A zero month removes the stored row' );
    is( $title->monthly_usages->search( { month => 3 } )->count, 0, 'The row of the zero month is gone' );
    is_deeply( \@reported, ['updated_mus'], 'updated_mus is reported for the removed row' );

    # A zero usage_count removes duplicates too
    $kept = $title->monthly_usages->search( { month => 2 } )->next;
    Koha::ERM::EUsage::MonthlyUsage->new( { %{ $kept->unblessed }, monthly_usage_summary_id => undef } )->store;
    @reported = ();
    $title->monthly_usages( [ { %{$usage}, month => 2, usage_count => 0 } ], $job_callbacks );
    is( $title->monthly_usages->search( { month => 2 } )->count, 0, 'A zero month removes every duplicate row' );
    is_deeply( \@reported, ['updated_mus'], 'One updated_mus is reported for the removed duplicates' );

    # Several months in one call: update, add and zero together
    @reported       = ();
    $monthly_usages = $title->monthly_usages(
        [
            { %{$usage}, month => 1, usage_count => 9 },
            { %{$usage}, month => 2, usage_count => 4 },
            { %{$usage}, month => 6, usage_count => 0 },
        ],
        $job_callbacks
    );
    is_deeply( \@reported, [ 'updated_mus', 'added_mus' ], 'Each month of one call is reported' );
    is( $monthly_usages->count, 2, 'The call leaves two rows' );
    is( $title->monthly_usages->search( { month => 1 } )->next->usage_count, 9, 'The first month was updated' );
    is( $title->monthly_usages->search( { month => 2 } )->next->usage_count, 4, 'The second month was added' );

    # All changes of one call run in one transaction
    my ( $depth, $stores ) = ( undef, 0 );
    my $mock = Test::MockModule->new('Koha::ERM::EUsage::MonthlyUsage');
    $mock->mock(
        'store',
        sub {
            my $self = shift;
            $stores++;
            $depth = $schema->storage->transaction_depth;
            die "store failed\n" if $stores == 2;
            return $mock->original('store')->( $self, @_ );
        }
    );
    throws_ok {
        $title->monthly_usages(
            [ { %{$usage}, month => 7, usage_count => 1 }, { %{$usage}, month => 8, usage_count => 1 } ] )
    }
    qr/store failed/, 'The exception of a failed store is passed on';
    $mock->unmock('store');
    is( $depth, 2, 'monthly_usages runs inside its own transaction' );
    is(
        $title->monthly_usages->search( { month => 7 } )->count, 0,
        'The row stored before the failure is rolled back'
    );
    is( $title->monthly_usages->search( { month => 8 } )->count, 0, 'The row that failed is not stored' );

    $schema->storage->txn_rollback;
};
