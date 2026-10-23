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
use Test::More tests => 4;
use Test::Exception;

use Koha::Database;
use Koha::ERM::EUsage::CounterLog;
use Koha::ERM::EUsage::CounterLogSummaries;
use Koha::ERM::EUsage::CounterLogSummary;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'erm_counter_log_summary holds the latest status of each month' => sub {

    plan tests => 19;

    $schema->storage->txn_begin;

    my $provider       = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );
    my $other_provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );

    my $add_log = sub {
        my ( $owner, $values ) = @_;
        return Koha::ERM::EUsage::CounterLog->new(
            {
                importdate             => '2026-01-01 08:00:00',
                filename               => undef,
                usage_data_provider_id => $owner->erm_usage_data_provider_id,
                counter_files_id       => undef,
                background_job_id      => undef,
                report_type            => 'TR_J1',
                %{$values},
            }
        )->store;
    };

    # January: one success
    $add_log->(
        $provider,
        { report_year => 2026, report_month => 1, status => 'success', importdate => '2026-02-01 08:00:00' }
    );

    # February: a retry, then a later success
    $add_log->(
        $provider,
        { report_year => 2026, report_month => 2, status => 'retry', importdate => '2026-03-01 08:00:00' }
    );
    $add_log->(
        $provider,
        { report_year => 2026, report_month => 2, status => 'success', importdate => '2026-03-05 08:00:00' }
    );

    # March: a retry with nothing after it
    $add_log->(
        $provider,
        { report_year => 2026, report_month => 3, status => 'retry', importdate => '2026-04-01 08:00:00' }
    );

    # April: the newest import wins, whatever the order of the ids
    $add_log->(
        $provider,
        { report_year => 2026, report_month => 4, status => 'success', importdate => '2026-05-02 08:00:00' }
    );
    $add_log->(
        $provider,
        { report_year => 2026, report_month => 4, status => 'error', importdate => '2026-05-01 08:00:00' }
    );

    # May: same import date, the higher id wins
    my $same_time = '2026-06-01 08:00:00';
    $add_log->( $provider, { report_year => 2026, report_month => 5, status => 'retry',   importdate => $same_time } );
    $add_log->( $provider, { report_year => 2026, report_month => 5, status => 'success', importdate => $same_time } );

    # A multi-month harvest has no period and is not summarised
    $add_log->(
        $provider,
        { report_year => undef, report_month => undef, status => 'success', importdate => '2026-07-01 08:00:00' }
    );

    # Another year and another report type give their own rows
    $add_log->(
        $provider,
        { report_year => 2025, report_month => 12, status => 'success', importdate => '2026-01-01 08:00:00' }
    );
    $add_log->(
        $provider,
        {
            report_year => 2026, report_month => 1, status => 'no_data', report_type => 'PR_P1',
            importdate  => '2026-02-01 08:00:00'
        }
    );

    # Another provider must not be mixed in
    $add_log->(
        $other_provider,
        { report_year => 2026, report_month => 1, status => 'error', importdate => '2026-02-01 08:00:00' }
    );

    my $summaries = Koha::ERM::EUsage::CounterLogSummaries->search(
        { usage_data_provider_id => $provider->erm_usage_data_provider_id },
        { order_by               => [ 'report_type', 'report_year' ] }
    );
    is( $summaries->count, 3, 'One row per report type and year' );

    my ( $pr_2026, $tr_2025, $tr_2026 ) = $summaries->as_list;

    is( $tr_2026->usage_data_provider->name, $provider->name, 'The row belongs to the provider' );
    is( $tr_2026->report_type,               'TR_J1',         'The row holds the report type' );
    is( $tr_2026->report_year,               2026,            'The row holds the year' );
    is( $tr_2026->month_1,                   'success',       'January shows the only log' );
    is( $tr_2026->month_2,                   'success',       'February shows the later success, not the retry' );
    is( $tr_2026->month_3,                   'retry',         'March still needs a retry' );
    is( $tr_2026->month_4,                   'success',       'April shows the newest import date' );
    is( $tr_2026->month_5,                   'success', 'May shows the higher id when the import dates are equal' );
    is( $tr_2026->month_6,                   undef,     'A month without a log is NULL' );
    is( $tr_2026->month_12,                  undef,     'December of 2026 has no log' );

    is( $tr_2025->report_year, 2025,      'The 2025 row is separate' );
    is( $tr_2025->month_12,    'success', 'December of 2025 is in the 2025 row' );
    is( $tr_2025->month_1,     undef,     'The 2025 row has no January' );

    is( $pr_2026->report_type, 'PR_P1',   'The PR_P1 row is separate' );
    is( $pr_2026->month_1,     'no_data', 'The PR_P1 row shows its own status' );

    my $other_summaries =
        Koha::ERM::EUsage::CounterLogSummaries->search(
        { usage_data_provider_id => $other_provider->erm_usage_data_provider_id } );
    is( $other_summaries->count,         1,       'The other provider has one row' );
    is( $other_summaries->next->month_1, 'error', 'The other provider keeps its own status' );

    my $api = $tr_2026->to_api;
    is(
        $api->{erm_counter_log_summary_id}, $tr_2026->erm_counter_log_summary_id,
        'The table exposes a primary key'
    );

    $schema->storage->txn_rollback;
};

subtest 'CounterLogSummary is read-only' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    throws_ok {
        Koha::ERM::EUsage::CounterLogSummary->new( { report_year => 2026, report_type => 'TR_J1' } )->store;
    }
    'Koha::Exception', 'store throws';

    my $provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );
    my $log      = Koha::ERM::EUsage::CounterLog->new(
        {
            usage_data_provider_id => $provider->erm_usage_data_provider_id,
            report_type            => 'TR_J1',
            report_year            => 2026,
            report_month           => 1,
            status                 => 'success',
        }
    )->store;
    my $summary =
        Koha::ERM::EUsage::CounterLogSummaries->search( { usage_data_provider_id => $log->usage_data_provider_id } )
        ->next;

    is(
        $summary->usage_data_provider->erm_usage_data_provider_id, $log->usage_data_provider_id,
        'usage_data_provider accessor'
    );
    throws_ok { $summary->delete } 'Koha::Exception', 'delete throws';

    $schema->storage->txn_rollback;
};

subtest 'rebuild follows the counter logs' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my $provider    = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );
    my $provider_id = $provider->erm_usage_data_provider_id;

    my $add_log = sub {
        my ($values) = @_;
        return Koha::ERM::EUsage::CounterLog->new(
            {
                importdate             => '2026-01-01 08:00:00',
                filename               => undef,
                usage_data_provider_id => $provider_id,
                counter_files_id       => undef,
                background_job_id      => undef,
                report_type            => 'TR_J1',
                report_year            => 2026,
                importdate             => '2026-03-01 08:00:00',
                %{$values},
            }
        )->store;
    };
    my $summaries = sub {
        Koha::ERM::EUsage::CounterLogSummaries->search(
            { usage_data_provider_id => $provider_id },
            { order_by               => 'report_year' }
        );
    };

    is( $summaries->()->count, 0, 'No counter log, no row' );

    my $january = $add_log->( { report_month => 1, status => 'retry' } );
    is( $summaries->()->next->month_1, 'retry', 'Storing a counter log writes the row' );

    $january->status('success')->store;
    is( $summaries->()->count,         1,         'A changed status does not add a row' );
    is( $summaries->()->next->month_1, 'success', 'A changed status changes the month' );

    $add_log->( { report_year => undef, report_month => undef, status => 'success' } );
    is( $summaries->()->count, 1, 'A counter log without a period is not summarised' );

    my $other_year = $add_log->( { report_year => 2027, report_month => 2, status => 'error' } );
    is( $summaries->()->count, 2, 'Another year is another row' );

    # The log moves from 2027 to 2026: the 2027 row goes, the 2026 row gets February
    $other_year->report_year(2026)->store;
    my @rows = $summaries->()->as_list;
    is( scalar @rows,      1,         'The row of the old year is removed' );
    is( $rows[0]->month_2, 'error',   'The row of the new year has the month' );
    is( $rows[0]->month_1, 'success', 'The row of the new year keeps the other months' );

    $other_year->delete;
    is( $summaries->()->next->month_2, undef, 'Deleting the counter log clears the month' );

    $january->delete;
    is( $summaries->()->count, 0, 'Deleting the last counter log of a year removes the row' );

    $add_log->( { report_month => 3, status => 'no_usage' } );
    my $rows = Koha::ERM::EUsage::CounterLogSummaries->rebuild( { usage_data_provider_id => $provider_id } );
    is( $rows, 1, 'rebuild returns the number of rows written' );
    Koha::ERM::EUsage::CounterLogSummaries->rebuild;
    is( $summaries->()->count,         1,          'A second rebuild does not duplicate the row' );
    is( $summaries->()->next->month_3, 'no_usage', 'The row has the status of the log' );

    $provider->delete;
    is(
        Koha::ERM::EUsage::CounterLogSummaries->search( { usage_data_provider_id => $provider_id } )->count, 0,
        'Deleting the provider deletes the rows'
    );

    $schema->storage->txn_rollback;
};
