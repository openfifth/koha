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
use Test::More tests => 6;

use Koha::Database;
use Koha::BackgroundJobs;
use Koha::BackgroundJob::ErmSushiHarvester;
use Koha::ERM::EUsage::CounterLogs;
use Koha::ERM::EUsage::MonthlyUsage;
use Koha::ERM::EUsage::MonthlyUsages;
use Koha::ERM::EUsage::YearlyUsages;

use JSON           qw( decode_json );
use File::Basename qw( dirname );
use File::Slurp;

use t::lib::Mocks;
use t::lib::TestBuilder;
use Test::MockModule;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

my $sushi_response_file_TR_J1      = dirname(__FILE__) . "/../../data/erm/eusage/COUNTER_5/TR_J1.json";
my $sushi_counter_5_response_TR_J1 = read_file($sushi_response_file_TR_J1);
my $sushi_counter_report_TR_J1 =
    Koha::ERM::EUsage::SushiCounter->new( { response => decode_json($sushi_counter_5_response_TR_J1) } );

my $ua = Test::MockModule->new('LWP::UserAgent');
$ua->mock(
    'simple_request',
    sub {
        my $response = Test::MockObject->new();

        $response->mock(
            'code',
            sub {
                return 200;
            }
        );
        $response->mock(
            'is_error',
            sub {
                return 0;
            }
        );
        $response->mock(
            'is_redirect',
            sub {
                return 0;
            }
        );
        $response->mock(
            'decoded_content',
            sub {
                return $sushi_counter_5_response_TR_J1;
            }
        );
        $response->{_rc} = 200;
        return $response;
    }
);

subtest 'enqueue_sushi_harvest_jobs' => sub {

    plan tests => 33;

    $schema->storage->txn_begin;

    my $patron = Koha::Patrons->search()->last;
    t::lib::Mocks::mock_userenv( { number => $patron->borrowernumber } );    # Is superlibrarian

    my $usage_data_provider = $builder->build_object(
        { class => 'Koha::ERM::EUsage::UsageDataProviders', value => { name => 'TestProvider' } } );

    my $job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $job = Koha::BackgroundJobs->find( $job->id );
    $job->process(
        {
            job_id           => $job->id,
            ud_provider_id   => $usage_data_provider->erm_usage_data_provider_id,
            report_type      => 'TR_J1',
            begin_date       => '2023-08-01',
            end_date         => '2023-09-30',
            ud_provider_name => $usage_data_provider->name,
        }
    );

    my $report = decode_json( $job->get_from_storage->data )->{report};

    is( $report->{ud_provider_id}, $usage_data_provider->erm_usage_data_provider_id );
    is( $report->{report_type},    'TR_J1' );
    is( $report->{begin_date},     '2023-08-01', 'Report holds the harvest begin date' );
    is( $report->{end_date},       '2023-09-30', 'Report holds the harvest end date' );
    is( $report->{harvest_status}, 'success',    'Report holds the harvest status' );

    my $counter_log = Koha::ERM::EUsage::CounterLogs->search( { background_job_id => $job->id } );
    is( $counter_log->count, 1, 'One counter log was written for the job' );
    $counter_log = $counter_log->next;
    is( $counter_log->status,       'success', 'The counter log is a success' );
    is( $counter_log->report_type,  'TR_J1',   'The counter log holds the report type' );
    is( $counter_log->report_year,  undef,     'A two month harvest has no report year' );
    is( $counter_log->report_month, undef,     'A two month harvest has no report month' );
    ok( $counter_log->counter_files_id, 'The counter log points at the stored file' );
    is( $report->{ud_provider_name},                      $usage_data_provider->name );
    is( $report->{us_report_info}->{skipped_mus},         0 );
    is( $report->{us_report_info}->{updated_mus},         0 );
    is( $report->{us_report_info}->{added_mus},           22 );
    is( $report->{us_report_info}->{added_usage_objects}, 2 );

    my $yus_search = { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id };
    is( Koha::ERM::EUsage::YearlyUsages->search($yus_search)->count, 6, '6 yearly usages computed from the view' );

    # Subsequent job
    my $another_job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $another_job = Koha::BackgroundJobs->find( $another_job->id );

    $another_job->process(
        {
            job_id           => $job->id,
            ud_provider_id   => $usage_data_provider->erm_usage_data_provider_id,
            report_type      => 'TR_J1',
            begin_date       => '2023-08-01',
            end_date         => '2023-09-30',
            ud_provider_name => $usage_data_provider->name,
        }
    );

    my $another_report = decode_json( $another_job->get_from_storage->data )->{report};

    is( $another_report->{ud_provider_id},                        $usage_data_provider->erm_usage_data_provider_id );
    is( $another_report->{report_type},                           'TR_J1' );
    is( $another_report->{ud_provider_name},                      $usage_data_provider->name );
    is( $another_report->{us_report_info}->{skipped_mus},         22 );
    is( $another_report->{us_report_info}->{updated_mus},         0 );
    is( $another_report->{us_report_info}->{added_mus},           0 );
    is( $another_report->{us_report_info}->{added_usage_objects}, 0 );

    is(
        Koha::ERM::EUsage::YearlyUsages->search($yus_search)->count, 6,
        'Yearly usages are not duplicated by a second harvest'
    );

    # Simulate stale and duplicated data left by earlier harvests
    my $mus_search = { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id };
    my $stale_usage =
        Koha::ERM::EUsage::MonthlyUsages->search( $mus_search, { order_by => 'monthly_usage_summary_id' } )->next;
    my $original_count = $stale_usage->usage_count;
    $stale_usage->usage_count( $original_count + 999 )->store;

    my $duplicated_usage =
        Koha::ERM::EUsage::MonthlyUsages->search( $mus_search, { order_by => 'monthly_usage_summary_id' } )->last;
    Koha::ERM::EUsage::MonthlyUsage->new( { %{ $duplicated_usage->unblessed }, monthly_usage_summary_id => undef } )
        ->store;

    # A month the file reports as zero, stored by an earlier harvest
    my $zero_month_usage = Koha::ERM::EUsage::MonthlyUsage->new(
        { %{ $stale_usage->unblessed }, monthly_usage_summary_id => undef, year => 2021, month => 9, usage_count => 7 }
    )->store;
    is(
        Koha::ERM::EUsage::MonthlyUsages->search($mus_search)->count, 24,
        'A duplicate and a stale zero month exist before the third harvest'
    );

    my $third_job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $third_job = Koha::BackgroundJobs->find( $third_job->id );

    $third_job->process(
        {
            job_id           => $third_job->id,
            ud_provider_id   => $usage_data_provider->erm_usage_data_provider_id,
            report_type      => 'TR_J1',
            begin_date       => '2023-08-01',
            end_date         => '2023-09-30',
            ud_provider_name => $usage_data_provider->name,
        }
    );

    my $third_report = decode_json( $third_job->get_from_storage->data )->{report};

    is(
        $third_report->{us_report_info}->{updated_mus}, 2,
        'The stale monthly usage was updated and the zero month removed'
    );
    is( $third_report->{us_report_info}->{skipped_mus}, 21,              'Unchanged monthly usages were skipped' );
    is( $third_report->{us_report_info}->{added_mus},   0,               'No monthly usage was added' );
    is( $stale_usage->get_from_storage->usage_count,    $original_count, 'The stale usage_count was corrected' );
    is(
        Koha::ERM::EUsage::MonthlyUsages->search($mus_search)->count, 22,
        'The duplicate monthly usage was removed'
    );
    is(
        Koha::ERM::EUsage::MonthlyUsages->find( $zero_month_usage->monthly_usage_summary_id ), undef,
        'The month reported as zero was removed'
    );
    is(
        Koha::ERM::EUsage::YearlyUsages->search($yus_search)->count, 6,
        'Yearly usages are unchanged after the third harvest'
    );

    #TODO: Test more report types

    $schema->storage->txn_rollback;

};

subtest 'enqueue_counter_file_processing_job' => sub {

    plan tests => 31;

    $schema->storage->txn_begin;

    my $usage_data_provider = $builder->build_object(
        { class => 'Koha::ERM::EUsage::UsageDataProviders', value => { name => 'TestProvider' } } );

    $usage_data_provider->{report_type} = 'TR_J1';

    my $job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $job = Koha::BackgroundJobs->find( $job->id );

    $job->process(
        {
            job_id         => $job->id,
            ud_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content   => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
        }
    );

    my $report = decode_json( $job->get_from_storage->data )->{report};

    is( $report->{ud_provider_id}, $usage_data_provider->erm_usage_data_provider_id );
    is( $report->{report_type},    'TR_J1' );
    is( $report->{begin_date},     undef,     'A file upload has no harvest begin date' );
    is( $report->{end_date},       undef,     'A file upload has no harvest end date' );
    is( $report->{harvest_status}, 'success', 'Report holds the status of the upload log' );

    my $counter_log = Koha::ERM::EUsage::CounterLogs->search( { background_job_id => $job->id } );
    is( $counter_log->count, 1, 'One counter log was written for the upload job' );
    $counter_log = $counter_log->next;
    is( $counter_log->status,                             'success', 'The upload log is a success' );
    is( $counter_log->report_type,                        'TR_J1',   'The report type comes from the file' );
    is( $counter_log->report_year,                        undef,     'A file over several months has no report year' );
    is( $counter_log->report_month,                       undef,     'A file over several months has no report month' );
    is( $report->{ud_provider_name},                      $usage_data_provider->name );
    is( $report->{us_report_info}->{skipped_mus},         0 );
    is( $report->{us_report_info}->{updated_mus},         0 );
    is( $report->{us_report_info}->{added_mus},           22 );
    is( $report->{us_report_info}->{added_usage_objects}, 2 );

    my $yus_search = { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id };
    is( Koha::ERM::EUsage::YearlyUsages->search($yus_search)->count, 6, '6 yearly usages computed from the view' );

    # Subsequent job
    my $another_job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $another_job = Koha::BackgroundJobs->find( $another_job->id );

    $another_job->process(
        {
            job_id         => $job->id,
            ud_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content   => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
        }
    );

    my $another_report = decode_json( $another_job->get_from_storage->data )->{report};

    is( $another_report->{ud_provider_id},                        $usage_data_provider->erm_usage_data_provider_id );
    is( $another_report->{report_type},                           'TR_J1' );
    is( $another_report->{ud_provider_name},                      $usage_data_provider->name );
    is( $another_report->{us_report_info}->{skipped_mus},         22 );
    is( $another_report->{us_report_info}->{updated_mus},         0 );
    is( $another_report->{us_report_info}->{added_mus},           0 );
    is( $another_report->{us_report_info}->{added_usage_objects}, 0 );

    is(
        Koha::ERM::EUsage::YearlyUsages->search($yus_search)->count, 6,
        'Yearly usages are not duplicated by a second file upload'
    );

    # Simulate stale and duplicated data left by earlier uploads
    my $mus_search = { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id };
    my $stale_usage =
        Koha::ERM::EUsage::MonthlyUsages->search( $mus_search, { order_by => 'monthly_usage_summary_id' } )->next;
    my $original_count = $stale_usage->usage_count;
    $stale_usage->usage_count( $original_count + 999 )->store;

    my $duplicated_usage =
        Koha::ERM::EUsage::MonthlyUsages->search( $mus_search, { order_by => 'monthly_usage_summary_id' } )->last;
    Koha::ERM::EUsage::MonthlyUsage->new( { %{ $duplicated_usage->unblessed }, monthly_usage_summary_id => undef } )
        ->store;
    is(
        Koha::ERM::EUsage::MonthlyUsages->search($mus_search)->count, 23,
        'A duplicate monthly usage exists before the third upload'
    );

    my $third_job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $third_job = Koha::BackgroundJobs->find( $third_job->id );

    $third_job->process(
        {
            job_id         => $third_job->id,
            ud_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content   => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
        }
    );

    my $third_report = decode_json( $third_job->get_from_storage->data )->{report};

    is( $third_report->{us_report_info}->{updated_mus}, 1,               'The stale monthly usage was updated' );
    is( $third_report->{us_report_info}->{skipped_mus}, 21,              'Unchanged monthly usages were skipped' );
    is( $third_report->{us_report_info}->{added_mus},   0,               'No monthly usage was added' );
    is( $stale_usage->get_from_storage->usage_count,    $original_count, 'The stale usage_count was corrected' );
    is(
        Koha::ERM::EUsage::MonthlyUsages->search($mus_search)->count, 22,
        'The duplicate monthly usage was removed'
    );
    is(
        Koha::ERM::EUsage::YearlyUsages->search($yus_search)->count, 6,
        'Yearly usages are unchanged after the third upload'
    );

    #TODO: Test a big file larger than max_allowed_packets
    #TODO: Test more report types

    $schema->storage->txn_rollback;

};

$ua->unmock_all;
$ua->mock(
    'simple_request',
    sub {
        my $response = Test::MockObject->new();

        $response->mock(
            'code',
            sub {
                return 200;
            }
        );
        $response->mock(
            'is_error',
            sub {
                return 0;
            }
        );
        $response->mock(
            'is_redirect',
            sub {
                return 0;
            }
        );
        $response->mock(
            'decoded_content',
            sub {
                return '{
                "Code": 2010,
                "Message": "Requestor is Not Authorized to Access Usage for Institution"
            }';
            }
        );
        $response->{_rc} = 200;
        return $response;
    }
);

subtest 'enqueue_sushi_harvest_jobs_error_handling' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $usage_data_provider_error = $builder->build_object(
        { class => 'Koha::ERM::EUsage::UsageDataProviders', value => { name => 'TestProvider' } } );

    my $job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    $job = Koha::BackgroundJobs->find( $job->id );

    $job->process(
        {
            job_id         => $job->id,
            ud_provider_id => $usage_data_provider_error->erm_usage_data_provider_id,
            report_type    => 'TR_J1',
        }
    );

    is( ref $job->messages,          'ARRAY', 'messages is an array' );
    is( $job->messages->[0]->{code}, 2010,    'first message has code 2010' );

    my $counter_log = Koha::ERM::EUsage::CounterLogs->search( { background_job_id => $job->id } )->next;
    is( $counter_log->status,           'error',                           'A 2010 exception is logged as an error' );
    is( $counter_log->counter_files_id, undef,                             'No counter file was stored' );
    is( $counter_log->decoded_logdetails->{exceptions}->[0]->{code}, 2010, 'logdetails hold the exception' );
    is( decode_json( $job->get_from_storage->data )->{report}->{harvest_status}, 'error', 'Report holds the status' );

    $schema->storage->txn_rollback;

};

my $unsupported_sushi_response_file =
    dirname(__FILE__) . "/../../data/erm/eusage/UnsupportedCOUNTER/UnsupportedCOUNTER.json";
my $unsupported_sushi_counter_5_response_TR_J1 = read_file($unsupported_sushi_response_file);

eval {
    Koha::ERM::EUsage::SushiCounter->new( { response => decode_json($unsupported_sushi_counter_5_response_TR_J1) } );
};
if ($@) {
    isa_ok(
        $@, 'Koha::Exceptions::ERM::EUsage::CounterFile::UnsupportedRelease',
        'Unsupported release throws UnsupportedRelease exception'
    );

    is( $@->{message}->{counter_release}, 99, 'exception message has counter_release set to 99' );
}
