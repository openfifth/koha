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

use Koha::Database;
use Koha::ERM::EUsage::CounterFile;
use Koha::ERM::EUsage::CounterLogs;

use JSON           qw( decode_json );
use File::Basename qw( dirname );
use File::Slurp;

use t::lib::Mocks;
use t::lib::TestBuilder;
use Test::MockModule;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

my $sushi_response_file_TR_J1      = dirname(__FILE__) . "/../../../../data/erm/eusage/COUNTER_5/TR_J1.json";
my $sushi_counter_5_response_TR_J1 = read_file($sushi_response_file_TR_J1);
my $sushi_counter_report_TR_J1 =
    Koha::ERM::EUsage::SushiCounter->new( { response => decode_json($sushi_counter_5_response_TR_J1) } );

subtest 'store' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    my $patron = Koha::Patrons->search()->last;
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $usage_data_provider = $builder->build_object(
        { class => 'Koha::ERM::EUsage::UsageDataProviders', value => { name => 'TestProvider' } } );
    $usage_data_provider->{report_type} = 'TR_J1';

    my $now_time = POSIX::strftime( "%Y%m%d%H%M%S", localtime );

    my $counter_file = Koha::ERM::EUsage::CounterFile->new(
        {
            usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content           => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
            date_uploaded          => $now_time,
            filename               => $usage_data_provider->name . "_" . $usage_data_provider->{report_type},
        }
    )->store;

    # UsageTitles are added on CounterFile->store
    my $titles_rs = Koha::ERM::EUsage::UsageTitles->search(
        { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id } );

    # MonthlyUsages are added on CounterFile->store
    my $mus_rs = Koha::ERM::EUsage::MonthlyUsages->search(
        { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id } );

    # YearlyUsages are a view computed from the monthly usages
    my $yus_rs = Koha::ERM::EUsage::YearlyUsages->search(
        { usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id } );

    is( $titles_rs->count, 2,  '2 titles were added' );
    is( $mus_rs->count,    22, '22 monthly usages were added' );
    is( $yus_rs->count,    6,  '6 yearly usages are computed' );

    my $yearly_usage   = $yus_rs->next;
    my $expected_total = 0;
    $expected_total += $_->usage_count
        for Koha::ERM::EUsage::MonthlyUsages->search(
        {
            title_id               => $yearly_usage->title_id,
            usage_data_provider_id => $yearly_usage->usage_data_provider_id,
            year                   => $yearly_usage->year,
            metric_type            => $yearly_usage->metric_type,
            report_type            => $yearly_usage->report_type,
        }
        )->as_list;
    is( $yearly_usage->totalcount, $expected_total, 'Yearly totalcount is the sum of the monthly usage counts' );

    # A counter log is added on CounterFile->store
    my $counter_logs = $counter_file->counter_logs;
    is( $counter_logs->count, 1, 'One counter log was added' );
    my $counter_log = $counter_logs->next;
    is( $counter_log->status,            'success',               'A stored file without log args is a success' );
    is( $counter_log->report_type,       'TR_J1',                 'The report type comes from the file header' );
    is( $counter_log->report_year,       undef,                   'A file over several months has no report year' );
    is( $counter_log->report_month,      undef,                   'A file over several months has no report month' );
    is( $counter_log->background_job_id, undef,                   'No job id without log args' );
    is( $counter_log->borrowernumber,    $patron->borrowernumber, 'The log holds the user' );
    is( $counter_log->filename,          $counter_file->filename, 'The log holds the file name' );
    is_deeply( $counter_log->decoded_logdetails, { exceptions => [] }, 'logdetails hold no exception' );

    # Storing the same COUNTER file again must not duplicate the monthly usages
    my $job         = $builder->build_object( { class => 'Koha::BackgroundJobs' } );
    my $second_file = Koha::ERM::EUsage::CounterFile->new(
        {
            usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content           => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
            date_uploaded          => $now_time,
            filename               => $usage_data_provider->name . "_" . $usage_data_provider->{report_type},
        }
    )->store(
        undef,
        {
            background_job_id => $job->id,
            report_type       => 'TR_J1',
            report_year       => 2021,
            report_month      => 10,
            status            => 'retry',
            logdetails        => '{"http_status":200,"exceptions":[{"code":3040}]}',
        }
    );
    is( $mus_rs->count, 22, 'Storing the same COUNTER file again does not duplicate monthly usages' );

    my $second_log = $second_file->counter_logs->next;
    is( $second_log->status,            'retry',                          'The status comes from the log args' );
    is( $second_log->report_year,       2021,                             'The report year comes from the log args' );
    is( $second_log->report_month,      10,                               'The report month comes from the log args' );
    is( $second_log->background_job_id, $job->id,                         'The job id comes from the log args' );
    is( $second_log->decoded_logdetails->{exceptions}->[0]->{code}, 3040, 'logdetails come from the log args' );

    # Without a userenv the log has no user
    C4::Context->unset_userenv;
    my $third_file = Koha::ERM::EUsage::CounterFile->new(
        {
            usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content           => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
            date_uploaded          => $now_time,
            filename               => $usage_data_provider->name . "_" . $usage_data_provider->{report_type},
        }
    )->store;
    is( $third_file->counter_logs->next->borrowernumber, undef, 'A store without userenv does not die' );

    $schema->storage->txn_rollback;

    #TODO: Test yop
    #TODO: acccess_type

};

subtest 'header helpers' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $header = sub {
        my ( $reporting_period, $exceptions ) = @_;
        return join(
            "\r\n",
            'Report_Name,"Journal Requests (Excluding OA_Gold)"',
            'Report_ID,TR_J1',
            'Release,5',
            'Institution_Name,"Test Institution"',
            'Institution_ID,',
            'Metric_Types,"Total_Item_Requests; Unique_Item_Requests"',
            'Report_Filters,',
            'Report_Attributes,',
            'Exceptions,"' .       ( $exceptions       // '' ) . '"',
            'Reporting_Period,"' . ( $reporting_period // '' ) . '"',
            'Created,2023-06-19T02:13:31Z',
            'Created_By,"Test Systems Inc."',
            '',
            'Title,Publisher,Metric_Type,Reporting_Period_Total,"Jun 2023"',
            '"A Title",Publisher,Total_Item_Requests,1,1',
            ''
        );
    };

    my $file = Koha::ERM::EUsage::CounterFile->new(
        { file_content => $header->( 'Begin_Date=2023-06-01; End_Date=2023-06-30', '' ) } );

    is( $file->_header_value('Report_ID'), 'TR_J1', '_header_value reads a header row' );
    is( $file->_header_value('Not_A_Key'), undef,   '_header_value returns undef for a missing row' );
    is_deeply(
        $file->_report_period_from_file, { report_year => 2023, report_month => 6 },
        'A reporting period inside one month gives that year and month'
    );
    is_deeply( [ $file->_header_exceptions ], [], 'An empty Exceptions row gives no exception' );

    $file->file_content( $header->( 'Begin_Date=2022-01-01; End_Date=2023-06-01', '' ) );
    is_deeply(
        $file->_report_period_from_file, { report_year => undef, report_month => undef },
        'A reporting period over several months gives no period'
    );

    $file->file_content( $header->( undef, '' ) );
    is_deeply(
        $file->_report_period_from_file, { report_year => undef, report_month => undef },
        'An empty reporting period gives no period'
    );

    $file->file_content(
        $header->(
            'Begin_Date=2023-06-01; End_Date=2023-06-30',
            '3031: Usage Not Ready for Requested Dates (Requested data between 2023-06-01 and 2023-06-30); 3040: Partial Data Returned'
        )
    );
    is_deeply(
        [ $file->_header_exceptions ],
        [
            {
                code    => 3031,
                message => 'Usage Not Ready for Requested Dates (Requested data between 2023-06-01 and 2023-06-30)'
            },
            { code => 3040, message => 'Partial Data Returned' },
        ],
        'Coded exceptions are split and parsed'
    );

    $file->file_content( $header->( 'Begin_Date=2023-06-01; End_Date=2023-06-30', 'Some vendor note' ) );
    is_deeply(
        [ $file->_header_exceptions ], [ { code => undef, message => 'Some vendor note' } ],
        'An exception without a code keeps its text'
    );

    # The header exceptions set the status of an uploaded file
    my $usage_data_provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );
    my $stored              = Koha::ERM::EUsage::CounterFile->new(
        {
            usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content           =>
                $header->( 'Begin_Date=2023-06-01; End_Date=2023-06-30', '3031: Usage Not Ready for Requested Dates' ),
            date_uploaded => POSIX::strftime( "%Y%m%d%H%M%S", localtime ),
            filename      => 'upload',
        }
    )->store;
    my $log = $stored->counter_logs->next;
    is_deeply(
        [ $log->status, $log->report_year, $log->report_month, $log->decoded_logdetails->{exceptions}->[0]->{code} ],
        [ 'retry',      2023,              6,                  3031 ],
        'An uploaded file with a 3031 header exception is logged as a retry for its month'
    );

    my $no_usage = Koha::ERM::EUsage::CounterFile->new(
        {
            usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id,
            file_content           => $header->(
                'Begin_Date=2023-07-01; End_Date=2023-07-31', '3030: No Usage Available for Requested Dates'
            ),
            date_uploaded => POSIX::strftime( "%Y%m%d%H%M%S", localtime ),
            filename      => 'upload_no_usage',
        }
    )->store;
    is(
        $no_usage->counter_logs->next->status, 'no_usage',
        'An uploaded file with a 3030 header exception is logged as no_usage'
    );

    $schema->storage->txn_rollback;
};

subtest '_get_rows_from_COUNTER_file' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $usage_data_provider = $builder->build_object(
        { class => 'Koha::ERM::EUsage::UsageDataProviders', value => { name => 'TestProvider' } } );
    $usage_data_provider->{report_type} = 'TR_J1';

    my $now_time = POSIX::strftime( "%Y%m%d%H%M%S", localtime );

    my $counter_file = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::CounterFiles',
            value => {
                usage_data_provider_id => $usage_data_provider->erm_usage_data_provider_id,
                file_content           => $sushi_counter_report_TR_J1->get_COUNTER_from_SUSHI,
                date_uploaded          => $now_time,
                filename               => $usage_data_provider->name . "_" . $usage_data_provider->{report_type},
            }
        }
    );

    my $counter_file_rows = $counter_file->_get_rows_from_COUNTER_file;

    is( ref $counter_file_rows, 'ARRAY', '_get_rows_from_COUNTER_file returns array' );
    is(
        scalar @{$counter_file_rows}, 4,
        '_get_rows_from_COUNTER_file returns correct number of rows'
    );
    is(
        @{$counter_file_rows}[0]->{Title}, 'Education and Training',
        'first and second report row is about the same title'
    );
    is(
        @{$counter_file_rows}[1]->{Title}, 'Education and Training',
        'first and second report row is about the same title'
    );

    $schema->storage->txn_rollback;

};
