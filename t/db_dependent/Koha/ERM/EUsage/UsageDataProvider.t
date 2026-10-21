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
use Test::More tests => 7;
use Test::Exception;
use Time::Fake;
use DateTime;

use File::Basename qw( dirname );
use File::Slurp    qw( read_file );
use JSON           qw( decode_json encode_json );

use Koha::BackgroundJobs;
use Koha::BackgroundJob::ErmSushiHarvester;
use Koha::ERM::EUsage::CounterLogs;
use Koha::ERM::EUsage::UsageDataProvider;
use Koha::ERM::EUsage::CounterFiles;
use Koha::Database;
use Test::MockModule;
use Test::MockObject;

use t::lib::Mocks;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest '_build_url_query' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $service_url  = 'https://service_url.com';
    my $api_key      = 'APIKEY';
    my $requestor_id = 'REQID123';
    my $customer_id  = 'ID123';
    my $name         = 'TestProvider';

    my $usage_data_provider = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::UsageDataProviders',
            value => {
                service_url => $service_url, api_key => $api_key, requestor_id     => $requestor_id,
                customer_id => $customer_id, name    => $name,    service_platform => undef, report_release => 5
            }
        }
    );

    $usage_data_provider->{report_type} = 'TR_J1';
    $usage_data_provider->{begin_date}  = '2023-08-01';
    $usage_data_provider->{end_date}    = '2023-09-30';

    is(
        $usage_data_provider->_build_url_query,
        $service_url
            . '/reports/'
            . lc( $usage_data_provider->{report_type} )
            . '?customer_id='
            . $customer_id
            . '&requestor_id='
            . $requestor_id
            . '&api_key='
            . $api_key
            . '&begin_date='
            . substr( $usage_data_provider->{begin_date}, 0, 7 )
            . '&end_date='
            . substr( $usage_data_provider->{end_date}, 0, 7 )
    );

    my $test_platform = 'www.whatever.com';

    my $usage_data_provider_with_platform = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::UsageDataProviders',
            value => {
                service_url => $service_url, api_key => $api_key, requestor_id  => $requestor_id,
                customer_id => $customer_id, name    => $name, service_platform => $test_platform, report_release => 5
            }
        }
    );

    $usage_data_provider_with_platform->{report_type} = 'TR_J1';
    $usage_data_provider_with_platform->{begin_date}  = '2023-08-01';
    $usage_data_provider_with_platform->{end_date}    = '2023-09-30';

    is(
        $usage_data_provider_with_platform->_build_url_query,
        $service_url
            . '/reports/'
            . lc( $usage_data_provider->{report_type} )
            . '?customer_id='
            . $customer_id
            . '&requestor_id='
            . $requestor_id
            . '&api_key='
            . $api_key
            . '&begin_date='
            . substr( $usage_data_provider->{begin_date}, 0, 7 )
            . '&end_date='
            . substr( $usage_data_provider->{end_date}, 0, 7 )
            . '&platform='
            . $test_platform
    );

    my $usage_data_provider_51 = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::UsageDataProviders',
            value => {
                service_url => $service_url, api_key => $api_key, requestor_id => $requestor_id,
                customer_id => $customer_id, name => $name, service_platform => $test_platform, report_release => '5.1'
            }
        }
    );

    $usage_data_provider_51->{report_type} = 'TR_J1';
    $usage_data_provider_51->{begin_date}  = '2023-08-01';
    $usage_data_provider_51->{end_date}    = '2023-09-30';

    is(
        $usage_data_provider_51->_build_url_query,
        $service_url
            . '/r51/reports/'
            . lc( $usage_data_provider->{report_type} )
            . '?customer_id='
            . $customer_id
            . '&requestor_id='
            . $requestor_id
            . '&api_key='
            . $api_key
            . '&begin_date='
            . substr( $usage_data_provider->{begin_date}, 0, 7 )
            . '&end_date='
            . substr( $usage_data_provider->{end_date}, 0, 7 )
            . '&platform='
            . $test_platform
    );

    $schema->storage->txn_rollback;

};

subtest 'test_connection() tests' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

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
                    return
                        '{"Description":"COUNTER Usage Reports for Test platform.","ServiceActive":true,"RegistryURL":"https://www.whatever.com"}';
                }
            );
            $response->{_rc} = 200;
            return $response;
        }
    );

    my $usage_data_provider = $builder->build_object(
        { class => 'Koha::ERM::EUsage::UsageDataProviders', value => { name => 'TestProvider' } } );

    is( $usage_data_provider->test_connection, 1 );

    $schema->storage->txn_rollback;
};

subtest 'harvest_periods() tests' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $usage_data_provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );

    is_deeply(
        $usage_data_provider->harvest_periods( { begin_date => '2023-08-05', end_date => '2023-08-20' } ),
        [ { begin_date => '2023-08-05', end_date => '2023-08-20' } ],
        'A range inside one month gives one period with the exact dates'
    );

    is_deeply(
        $usage_data_provider->harvest_periods( { begin_date => '2023-11-15', end_date => '2024-02-02' } ),
        [
            { begin_date => '2023-11-15', end_date => '2023-11-30' },
            { begin_date => '2023-12-01', end_date => '2023-12-31' },
            { begin_date => '2024-01-01', end_date => '2024-01-31' },
            { begin_date => '2024-02-01', end_date => '2024-02-02' },
        ],
        'A range across a year boundary is split into months, keeping the exact first and last dates'
    );

    is_deeply(
        $usage_data_provider->harvest_periods( { begin_date => '2024-01-01', end_date => '2024-03-31' } ),
        [
            { begin_date => '2024-01-01', end_date => '2024-01-31' },
            { begin_date => '2024-02-01', end_date => '2024-02-29' },
            { begin_date => '2024-03-01', end_date => '2024-03-31' },
        ],
        'Month-aligned dates and a leap year are handled'
    );

    is_deeply(
        $usage_data_provider->harvest_periods( { begin_date => '2023-08-15', end_date => '2023-08-15' } ),
        [ { begin_date => '2023-08-15', end_date => '2023-08-15' } ],
        'Equal begin and end dates give one period'
    );

    throws_ok {
        $usage_data_provider->harvest_periods( { begin_date => '2023-08-01' } );
    }
    'Koha::Exceptions::MissingParameter', 'A missing end_date throws MissingParameter';

    throws_ok {
        $usage_data_provider->harvest_periods( { begin_date => '2023-09-01', end_date => '2023-08-31' } );
    }
    'Koha::Exceptions::BadParameter', 'A begin_date after the end_date throws BadParameter';

    # Today is 2024-06-15 for the next cases
    Time::Fake->offset( DateTime->new( year => 2024, month => 6, day => 15, hour => 12 )->epoch );

    is_deeply(
        $usage_data_provider->harvest_periods( { begin_date => '2024-05-20', end_date => '2024-08-01' } ),
        [
            { begin_date => '2024-05-20', end_date => '2024-05-31' },
            { begin_date => '2024-06-01', end_date => '2024-06-15' },
        ],
        'An end date in the future is reduced to today'
    );

    is_deeply(
        $usage_data_provider->harvest_periods( { begin_date => '2024-06-01', end_date => '2024-06-15' } ),
        [ { begin_date => '2024-06-01', end_date => '2024-06-15' } ],
        'An end date of today is kept'
    );

    throws_ok {
        $usage_data_provider->harvest_periods( { begin_date => '2024-07-01', end_date => '2024-08-01' } );
    }
    'Koha::Exceptions::BadParameter', 'A begin_date in the future throws BadParameter';

    Time::Fake->reset;

    $schema->storage->txn_rollback;
};

subtest '_harvest_report_period() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $usage_data_provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );

    $usage_data_provider->{begin_date} = '2023-08-15';
    $usage_data_provider->{end_date}   = '2023-08-31';
    my $no_period = { report_year => undef, report_month => undef };
    is_deeply(
        $usage_data_provider->_harvest_report_period, { report_year => 2023, report_month => 8 },
        'A harvest inside one month gives that year and month'
    );

    $usage_data_provider->{end_date} = '2023-10-02';
    is_deeply(
        $usage_data_provider->_harvest_report_period, $no_period,
        'A harvest over several months gives no period'
    );

    $usage_data_provider->{end_date} = undef;
    is_deeply( $usage_data_provider->_harvest_report_period, $no_period, 'A missing end date gives no period' );

    $usage_data_provider->{begin_date} = undef;
    is_deeply( $usage_data_provider->_harvest_report_period, $no_period, 'Missing dates give no period' );

    $schema->storage->txn_rollback;
};

subtest 'harvest_sushi() counter log tests' => sub {

    plan tests => 68;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $sushi_response = read_file( dirname(__FILE__) . "/../../../data/erm/eusage/COUNTER_5/TR_J1.json" );

    my ( $mock_code, $mock_content ) = ( 200, $sushi_response );
    my $ua = Test::MockModule->new('LWP::UserAgent');
    $ua->mock(
        'simple_request',
        sub {
            my $response = Test::MockObject->new();
            $response->mock( 'code',            sub { return $mock_code; } );
            $response->mock( 'is_error',        sub { return $mock_code >= 400; } );
            $response->mock( 'is_redirect',     sub { return 0; } );
            $response->mock( 'decoded_content', sub { return $mock_content; } );
            return $response;
        }
    );

    my $usage_data_provider = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::UsageDataProviders',
            value => {
                name        => 'TestProvider',
                service_url => 'https://sushi.example.org/',
                customer_id => 'CUSTOMER',
            }
        }
    );
    my $provider_id = $usage_data_provider->erm_usage_data_provider_id;

    my $job = Koha::BackgroundJob::ErmSushiHarvester->new(
        {
            status => 'new',
            size   => 1,
            type   => 'erm_sushi_harvester'
        }
    )->store;

    my @messages;
    $usage_data_provider->set_background_job_callbacks(
        {
            report_info_callback => sub { },
            step_callback        => sub { },
            set_size_callback    => sub { },
            add_message_callback => sub { push @messages, shift; },
        }
    );

    my $harvest = sub {
        my ($args) = @_;
        @messages = ();
        $usage_data_provider->harvest_sushi(
            {
                report_type       => 'TR_J1',
                begin_date        => '2021-10-01',
                end_date          => '2021-10-31',
                background_job_id => $job->id,
                %{ $args // {} },
            }
        );
    };
    my $last_log = sub {
        return Koha::ERM::EUsage::CounterLogs->search(
            { usage_data_provider_id => $provider_id },
            { order_by               => { -desc => 'erm_counter_log_id' } }
        )->next;
    };

    # The file import adds object_added messages, only the SUSHI messages are checked
    my $sushi_messages = sub {
        return grep { ( $_->{code} // q{} ) !~ /^object_/ } @messages;
    };

    # A report with items and no exception
    $harvest->();
    my $log = $last_log->();
    is( $log->status,            'success',                    'A report with items is a success' );
    is( $log->report_type,       'TR_J1',                      'The log holds the report type' );
    is( $log->report_year,       2021,                         'The log holds the harvested year' );
    is( $log->report_month,      10,                           'The log holds the harvested month' );
    is( $log->background_job_id, $job->id,                     'The log holds the job id' );
    is( $log->borrowernumber,    $patron->borrowernumber,      'The log holds the user' );
    is( $log->filename,          'TestProvider_TR_J1_2021-10', 'The log holds the counter file name' );
    ok( $log->counter_files_id, 'The counter file was stored' );
    my $details = $log->decoded_logdetails;
    is( $details->{http_status},     200, 'logdetails hold the HTTP status' );
    is( $details->{counter_release}, '5', 'logdetails hold the COUNTER release' );
    is_deeply( $details->{exceptions}, [], 'logdetails hold no exception' );
    ok( !exists $details->{status}, 'The status is not duplicated in logdetails' );
    is( $usage_data_provider->harvest_outcome->{status}, 'success', 'harvest_outcome holds the status' );
    is( scalar $sushi_messages->(),                      0,         'No SUSHI job message was added' );

    # A harvest over several months has no report period
    $harvest->( { begin_date => '2021-10-01', end_date => '2021-12-31' } );
    $log = $last_log->();
    is( $log->status,       'success', 'A multi-month report with items is a success' );
    is( $log->report_year,  undef,     'A multi-month harvest has no report year' );
    is( $log->report_month, undef,     'A multi-month harvest has no report month' );

    # 3040 Partial Data Returned with items: stored and flagged for a retry
    my $decoded = decode_json($sushi_response);
    $decoded->{Report_Header}->{Exceptions} = [
        {
            Code     => 3040,
            Severity => 'Warning',
            Message  => 'Partial Data Returned',
            Data     => 'Usage for 2021-10 is incomplete'
        }
    ];
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status, 'retry', '3040 with items needs a retry' );
    ok( $log->counter_files_id, 'The partial report was stored' );
    is_deeply(
        $log->decoded_logdetails->{exceptions},
        [
            {
                code     => 3040,
                severity => 'Warning',
                message  => 'Partial Data Returned',
                data     => 'Usage for 2021-10 is incomplete'
            }
        ],
        'logdetails hold the exception'
    );
    my @sushi_messages = $sushi_messages->();
    is( scalar @sushi_messages,     1,         'One SUSHI job message was added' );
    is( $sushi_messages[0]->{type}, 'warning', 'A retry code gives a warning message' );
    is( $sushi_messages[0]->{code}, 3040,      'The message holds the code' );
    is(
        $sushi_messages[0]->{message}, 'Partial Data Returned - Usage for 2021-10 is incomplete',
        'The message holds message and data'
    );

    # 3032 Usage No Longer Available with items: stored, no action needed
    $decoded->{Report_Header}->{Exceptions} =
        [ { Code => 3032, Message => 'Usage No Longer Available for Requested Dates' } ];
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status, 'success', '3032 with items is a success' );
    ok( $log->counter_files_id, 'The report was stored' );

    # 3030 No Usage Available with items: the items win
    $decoded->{Report_Header}->{Exceptions} = [ { Code => 3030, Message => 'No Usage Available for Requested Dates' } ];
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status, 'success', '3030 with items is a success' );
    ok( $log->counter_files_id, 'The report was stored' );

    # An error exception next to items: logged as an error, the report is not imported
    my $files_before = Koha::ERM::EUsage::CounterFiles->search( { usage_data_provider_id => $provider_id } )->count;
    $decoded->{Report_Header}->{Exceptions} =
        [ { Code => 3000, Severity => 'Error', Message => 'Report Not Supported' } ];
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status,           'error', '3000 with items is an error' );
    is( $log->counter_files_id, undef,   'The suspect report was not stored' );
    is(
        Koha::ERM::EUsage::CounterFiles->search( { usage_data_provider_id => $provider_id } )->count, $files_before,
        'No counter file was added'
    );

    # A request parameter warning next to items: the report is complete
    $decoded->{Report_Header}->{Exceptions} =
        [ { Code => 3050, Severity => 'Warning', Message => 'Parameter Not Recognized in this Context' } ];
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status, 'success', '3050 with items is a success' );
    ok( $log->counter_files_id, 'The complete report was stored' );
    is( ( $sushi_messages->() )[0]->{type}, 'warning', 'A parameter warning gives a warning message' );

    # 3030 No Usage Available, no items
    $decoded->{Report_Header}->{Exceptions} = [ { Code => 3030, Message => 'No Usage Available for Requested Dates' } ];
    $decoded->{Report_Items}                = [];
    $mock_content                           = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status,                                        'no_usage', '3030 without items is no_usage' );
    is( $log->counter_files_id,                              undef,      'No counter file was stored' );
    is( $log->report_type,                                   'TR_J1',    'The log holds the report type' );
    is( $log->report_year,                                   2021,       'The log holds the harvested year' );
    is( $log->report_month,                                  10,         'The log holds the harvested month' );
    is( $log->background_job_id,                             $job->id,   'The log holds the job id' );
    is( $log->filename,                                      undef,      'A harvest without a file has no file name' );
    is( $log->decoded_logdetails->{exceptions}->[0]->{code}, 3030,       'logdetails hold the exception' );
    is( scalar @messages, 1, 'The exception message was added, no no_items message' );

    # 3031 Usage Not Ready, no items
    $decoded->{Report_Header}->{Exceptions} = [ { Code => 3031, Message => 'Usage Not Ready for Requested Dates' } ];
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status,           'retry', '3031 without items needs a retry' );
    is( $log->counter_files_id, undef,   'No counter file was stored' );

    # An empty report without exception
    delete $decoded->{Report_Header}->{Exceptions};
    $mock_content = encode_json($decoded);
    $harvest->();
    $log = $last_log->();
    is( $log->status,         'no_data',  'An empty report is no_data' );
    is( scalar @messages,     1,          'One job message was added' );
    is( $messages[0]->{code}, 'no_items', 'The no_items message was added' );

    # HTTP 204 No Content
    ( $mock_code, $mock_content ) = ( 204, '' );
    $harvest->();
    $log = $last_log->();
    is( $log->status,                            'no_data', 'HTTP 204 is no_data' );
    is( $log->decoded_logdetails->{http_status}, 204,       'logdetails hold the HTTP status' );
    ok( !exists $log->decoded_logdetails->{message}, 'An empty body gives no message' );

    # HTTP 503 with a COUNTER exception: the job finishes, the month needs a retry
    ( $mock_code, $mock_content ) = ( 503, '{"Code":1000,"Severity":"Fatal","Message":"Service Not Available"}' );
    lives_ok { $harvest->() } 'A COUNTER exception on an HTTP error does not die';
    $log = $last_log->();
    is( $log->status,                            'retry',   'HTTP 503 with code 1000 needs a retry' );
    is( $log->decoded_logdetails->{http_status}, 503,       'logdetails hold the HTTP status' );
    is( $messages[0]->{type},                    'warning', 'A retry code gives a warning message' );

    # HTTP 401 with a COUNTER exception
    ( $mock_code, $mock_content ) =
        ( 401, '{"Code":2000,"Severity":"Error","Message":"Requestor Not Authorized to Access Service"}' );
    lives_ok { $harvest->() } 'A COUNTER exception on an HTTP error does not die';
    $log = $last_log->();
    is( $log->status,         'error', 'HTTP 401 with code 2000 is an error' );
    is( $messages[0]->{type}, 'error', 'An error code gives an error message' );

    # HTTP 400 with a COUNTER exception
    ( $mock_code, $mock_content ) = ( 400, '{"Code":3020,"Message":"Invalid Date Arguments"}' );
    $harvest->();
    is( $last_log->()->status, 'error', 'HTTP 400 with code 3020 is an error' );

    # HTTP 401 without a COUNTER exception: the log is written, then the exception is thrown
    ( $mock_code, $mock_content ) = ( 401, '{"message":"Invalid credentials"}' );
    eval { $harvest->() };
    my $error = $@;
    isa_ok( $error, 'Koha::Exceptions::Authorization::Unauthorized', 'HTTP 401 without a COUNTER exception' );
    $log = $last_log->();
    is( $log->status, 'error', 'The log was written before the exception was thrown' );
    is( $log->decoded_logdetails->{exceptions}->[0]->{message}, 'Invalid credentials', 'The vendor message is kept' );
    is( $log->decoded_logdetails->{exceptions}->[0]->{code},    undef, 'The vendor message has no code' );

    # HTTP 500 without a COUNTER exception
    ( $mock_code, $mock_content ) = ( 500, '{"errors":[{"message":"Database down"}]}' );
    eval { $harvest->() };
    $error = $@;
    like( $error, qr/ERROR requesting SUSHI service/, 'HTTP 500 without a COUNTER exception dies' );
    is( $last_log->()->status, 'retry', 'HTTP 500 needs a retry' );

    # HTTP 200 with a body that is not JSON
    ( $mock_code, $mock_content ) = ( 200, '<html>Maintenance</html>' );
    $harvest->();
    $log = $last_log->();
    is( $log->status, 'error', 'A response that is not JSON is an error' );
    like( $log->decoded_logdetails->{message}, qr/^Invalid SUSHI response: <html>/, 'logdetails hold the body' );
    is( $messages[0]->{code}, 'invalid_response', 'The invalid_response message was added' );

    $schema->storage->txn_rollback;
};

subtest 'enqueue_sushi_harvest_jobs() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $usage_data_provider = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::UsageDataProviders',
            value => { name => 'TestProvider', report_types => 'TR_J1;PR' }
        }
    );

    my $jobs_before = Koha::BackgroundJobs->search( { type => 'erm_sushi_harvester' } )->count;

    my $jobs = $usage_data_provider->enqueue_sushi_harvest_jobs(
        {
            begin_date => '2023-08-15',
            end_date   => '2023-10-02',
        }
    );

    is( scalar @{$jobs}, 6, 'One job per report type and per month is enqueued' );
    is(
        Koha::BackgroundJobs->search( { type => 'erm_sushi_harvester' } )->count, $jobs_before + 6,
        '6 background jobs were created'
    );

    is_deeply(
        [ map { $_->{report_type} } @{$jobs} ],
        [ 'TR_J1', 'TR_J1', 'TR_J1', 'PR', 'PR', 'PR' ],
        'Jobs are ordered by report type'
    );
    is_deeply(
        [ map { [ $_->{begin_date}, $_->{end_date} ] } @{$jobs} ],
        [
            [ '2023-08-15', '2023-08-31' ],
            [ '2023-09-01', '2023-09-30' ],
            [ '2023-10-01', '2023-10-02' ],
            [ '2023-08-15', '2023-08-31' ],
            [ '2023-09-01', '2023-09-30' ],
            [ '2023-10-01', '2023-10-02' ],
        ],
        'Each job covers one month and the first and last keep the exact dates'
    );

    my @job_ids = map { $_->{job_id} } @{$jobs};
    is( scalar( keys %{ { map { $_ => 1 } @job_ids } } ), 6, 'Every job has its own job_id' );

    my $second_job = Koha::BackgroundJobs->find( $jobs->[1]->{job_id} );
    my $job_args   = $second_job->decoded_data;
    is(
        $job_args->{ud_provider_id}, $usage_data_provider->erm_usage_data_provider_id,
        'Job args hold the provider id'
    );
    is( $job_args->{ud_provider_name}, 'TestProvider', 'Job args hold the provider name' );
    is( $job_args->{report_type},      'TR_J1',        'Job args hold the report type' );
    is( $job_args->{begin_date},       '2023-09-01',   'Job args hold the monthly begin date' );
    is( $job_args->{end_date},         '2023-09-30',   'Job args hold the monthly end date' );

    throws_ok {
        $usage_data_provider->enqueue_sushi_harvest_jobs( { begin_date => '2023-08-01' } );
    }
    'Koha::Exceptions::MissingParameter', 'A missing date is rejected before any job is enqueued';

    $schema->storage->txn_rollback;
};
