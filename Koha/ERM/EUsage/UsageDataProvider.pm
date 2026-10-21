package Koha::ERM::EUsage::UsageDataProvider;

# Copyright 2023 PTFS Europe

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

use HTTP::Request;
use JSON qw( decode_json );
use LWP::UserAgent;
use Scalar::Util qw( blessed );

use C4::Context;
use Koha::DateUtils qw( dt_from_string );
use Koha::Exceptions;
use Koha::Logger;

use Try::Tiny qw( catch try );

use base qw(Koha::Object);

use Koha;
use Koha::ERM::EUsage::CounterFile;
use Koha::ERM::EUsage::CounterFiles;
use Koha::ERM::EUsage::CounterLog;
use Koha::ERM::EUsage::CounterLogs;
use Koha::ERM::EUsage::UsageTitles;
use Koha::ERM::EUsage::UsageItems;
use Koha::ERM::EUsage::UsagePlatforms;
use Koha::ERM::EUsage::UsageDatabases;
use Koha::ERM::EUsage::MonthlyUsages;
use Koha::ERM::EUsage::SushiCounter;
use Koha::BackgroundJob::ErmSushiHarvester;

=head1 NAME

Koha::ERM::EUsage::UsageDataProvider - Koha ErmUsageDataProvider Object class

=head1 API

=head2 Class Methods

=head3 counter_files

    my $counter_files = $ud_provider->counter_files;
    $ud_provider->counter_files( \@counter_files, $log_args );

Getter/setter for counter_files for this usage data provider.

When C<$counter_files> is passed, each file is stored. The optional C<$log_args>
hashref is passed to C<Koha::ERM::EUsage::CounterFile::store> and fills the
counter log row of each file (C<background_job_id>, C<report_type>, C<report_year>,
C<report_month>, C<status>, C<logdetails>).

=cut

sub counter_files {
    my ( $self, $counter_files, $log_args ) = @_;

    if ($counter_files) {
        for my $counter_file (@$counter_files) {
            Koha::ERM::EUsage::CounterFile->new($counter_file)->store( $self->{job_callbacks}, $log_args );
        }
    }
    my $counter_files_rs = $self->_result->erm_counter_files;
    return Koha::ERM::EUsage::CounterFiles->_new_from_dbic($counter_files_rs);
}

=head3 enqueue_counter_file_processing_job

Enqueues a background job to process a COUNTER file that has been uploaded

=cut

sub enqueue_counter_file_processing_job {
    my ( $self, $args ) = @_;

    my @jobs;
    my $job_id = Koha::BackgroundJob::ErmSushiHarvester->new->enqueue(
        {
            ud_provider_id => $self->erm_usage_data_provider_id,
            file_content   => $args->{file_content},
        }
    );

    push(
        @jobs,
        { job_id => $job_id }
    );

    return \@jobs;
}

=head3 harvest_periods

    my $periods = $ud_provider->harvest_periods(
        {
            begin_date => '2023-08-15',
            end_date   => '2023-10-02',
        }
    );

Splits a date range into one period per calendar month. Returns an arrayref of
hashrefs with C<begin_date> and C<end_date> in C<YYYY-MM-DD> format:

    [
        { begin_date => '2023-08-15', end_date => '2023-08-31' },
        { begin_date => '2023-09-01', end_date => '2023-09-30' },
        { begin_date => '2023-10-01', end_date => '2023-10-02' },
    ]

The first period starts on the given begin date and the last period ends on the
given end date. Months in between run from the first to the last day. Equal
begin and end dates give one period of one day.

The dates are calendar days without a time zone. An end date after today is
reduced to today, so no job is enqueued for a month that has not happened yet.

Throws C<Koha::Exceptions::MissingParameter> if a date is missing and
C<Koha::Exceptions::BadParameter> if the begin date is after the end date or
after today.

=cut

sub harvest_periods {
    my ( $self, $args ) = @_;

    for my $param (qw( begin_date end_date )) {
        Koha::Exceptions::MissingParameter->throw( parameter => $param )
            unless $args->{$param};
    }

    my $begin = dt_from_string( $args->{begin_date}, undef, 'floating' )->truncate( to => 'day' );
    my $end   = dt_from_string( $args->{end_date},   undef, 'floating' )->truncate( to => 'day' );
    my $today = dt_from_string( undef,               undef, 'floating' )->truncate( to => 'day' );

    Koha::Exceptions::BadParameter->throw(
        parameter => 'begin_date',
        error     => 'begin_date must not be after end_date'
    ) if $begin > $end;

    Koha::Exceptions::BadParameter->throw(
        parameter => 'begin_date',
        error     => 'begin_date must not be in the future'
    ) if $begin > $today;

    $end = $today if $end > $today;

    my @periods;
    my $cursor = $begin->clone;
    while ( $cursor <= $end ) {
        my $last_day_of_month = $cursor->clone->set_day( $cursor->month_length );
        my $period_end        = $last_day_of_month > $end ? $end : $last_day_of_month;

        push @periods, { begin_date => $cursor->ymd, end_date => $period_end->ymd };

        $cursor = $last_day_of_month->add( days => 1 );
    }

    return \@periods;
}

=head3 enqueue_sushi_harvest_jobs

    my $jobs = $ud_provider->enqueue_sushi_harvest_jobs(
        {
            begin_date => '2023-08-15',
            end_date   => '2023-10-02',
        }
    );

Enqueues one harvest background job for each report type of this usage data
provider and each calendar month in the date range, see L</harvest_periods>.

Returns an arrayref with one hashref per job, ordered by report type and then
by month:

    { report_type => 'TR_J1', job_id => 12, begin_date => '2023-08-15', end_date => '2023-08-31' }

=cut

sub enqueue_sushi_harvest_jobs {
    my ( $self, $args ) = @_;

    my @report_types = split( /;/, $self->report_types );
    my $periods      = $self->harvest_periods($args);

    my @jobs;
    foreach my $report_type (@report_types) {
        foreach my $period ( @{$periods} ) {

            my $job_id = Koha::BackgroundJob::ErmSushiHarvester->new->enqueue(
                {
                    ud_provider_id   => $self->erm_usage_data_provider_id,
                    report_type      => $report_type,
                    begin_date       => $period->{begin_date},
                    end_date         => $period->{end_date},
                    ud_provider_name => $self->name,
                }
            );

            push(
                @jobs,
                {
                    report_type => $report_type,
                    job_id      => $job_id,
                    begin_date  => $period->{begin_date},
                    end_date    => $period->{end_date},
                }
            );
        }
    }

    return \@jobs;
}

=head3 harvest_sushi

    $ud_provider->harvest_sushi(
        {
            begin_date        => $args->{begin_date},
            end_date          => $args->{end_date},
            report_type       => $args->{report_type},
            background_job_id => $job->id,
        }
    );

Runs this usage data provider's SUSHI harvester
Builds the URL query and requests the COUNTER 5 SUSHI service

Every harvest attempt writes one C<Koha::ERM::EUsage::CounterLog> row. When the
response holds report items, the COUNTER file is stored and the log row is created by
C<Koha::ERM::EUsage::CounterFile::store>. Otherwise the log row is created here with
no counter file and no file name. A report that carries an error exception is not
imported, even when it holds items: the row is logged as C<error>. The row's C<status> is one of C<success>, C<no_usage>, C<no_data>, C<retry> or
C<error> (see C<_classify_harvest>) and C<logdetails> holds the HTTP status and the
SUSHI exceptions as JSON.

COUNTER SUSHI api spec:
https://app.swaggerhub.com/apis/COUNTER/counter-sushi_5_0_api/5.0.2

=over

=item begin_date

Begin date of the SUSHI harvest

=back

=over

=item end_date

End date of the SUSHI harvest

=back

=over

=item report_type

Report type to run this harvest on

=back

=over

=item background_job_id

Optional. Id of the background job that runs this harvest, stored on the counter log

=back

=cut

sub harvest_sushi {
    my ( $self, $args ) = @_;

    # Set class wide vars
    $self->{report_type}       = $args->{report_type};
    $self->{begin_date}        = $args->{begin_date};
    $self->{end_date}          = $args->{end_date};
    $self->{background_job_id} = $args->{background_job_id};
    $self->{harvest_outcome}   = { exceptions => [] };

    my $url      = $self->_build_url_query;
    my $response = _handle_sushi_request($url);
    my $outcome  = $self->{harvest_outcome};
    $outcome->{http_status} = $response->code;

    my $content = $response->decoded_content // q{};
    my $result  = try { decode_json($content) } catch { undef };
    if ( !defined $result && length $content ) {
        $outcome->{message} = 'Invalid SUSHI response: ' . substr( $content, 0, 500 );
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type    => 'error',
                code    => 'invalid_response',
                message => $outcome->{message},
            }
        ) if $self->{job_callbacks};
    }

    $self->_collect_sushi_exceptions($result);

    my $report_items = ref($result) eq 'HASH' ? $result->{Report_Items} : undef;
    my $has_items    = ref($report_items) eq 'ARRAY' && scalar @{$report_items} > 0;
    $outcome->{counter_release} = $result->{Report_Header}->{Release}
        if ref($result) eq 'HASH' && ref( $result->{Report_Header} ) eq 'HASH';

    if ( $response->code >= 400 ) {
        $self->_add_harvest_log( $self->_classify_harvest( { has_items => 0 } ) );

        # A COUNTER exception explains the failure: the job finishes with its messages
        return if grep { defined $_->{code} } @{ $outcome->{exceptions} };

        my $message = $self->_harvest_outcome_message;
        Koha::Logger->get->warn(
            sprintf "SUSHI service for usage data provider %s returned HTTP %s - %s",
            $self->erm_usage_data_provider_id, $response->code, $message
        );
        if ( $response->code == 404 ) {
            Koha::Exceptions::ObjectNotFound->throw($message);
        } elsif ( $response->code == 401 ) {
            Koha::Exceptions::Authorization::Unauthorized->throw($message);
        } else {
            die sprintf "ERROR requesting SUSHI service\ncode %s: %s\n", $response->code, $message;
        }
    }

    unless ($has_items) {
        my $status = $self->_classify_harvest( { has_items => 0 } );
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type => 'warning',
                code => 'no_items',
            }
        ) if $self->{job_callbacks} && !@{ $outcome->{exceptions} } && !defined $outcome->{message};
        $self->_add_harvest_log($status);
        return;
    }

    # An error exception next to items: the report is suspect, it is logged, not imported
    my $status = $self->_classify_harvest( { has_items => 1 } );
    if ( $status eq 'error' ) {
        $self->_add_harvest_log($status);
        return;
    }

    # Parse the SUSHI response
    try {
        my $sushi_counter = Koha::ERM::EUsage::SushiCounter->new( { response => $result } );
        my $counter_file  = $sushi_counter->get_COUNTER_from_SUSHI;

        if ( $self->_counter_file_size_too_large($counter_file) ) {
            $outcome->{message} = 'COUNTER file larger than max_allowed_packet';
            $self->_add_harvest_log('error');
            return;
        }

        $self->counter_files(
            [
                {
                    usage_data_provider_id => $self->erm_usage_data_provider_id,
                    file_content           => $counter_file,
                    date_uploaded          => POSIX::strftime( "%Y%m%d%H%M%S", localtime ),

                    #TODO: add ".csv" to end of filename here
                    filename => $self->_counter_filename,
                }
            ],
            $self->_harvest_log_args($status)
        );
    } catch {
        my $error = $_;
        if ( blessed($error) && $error->isa('Koha::Exceptions::ERM::EUsage::CounterFile::UnsupportedRelease') ) {
            $outcome->{message} = 'COUNTER release ' . $error->{message}->{counter_release} . ' not supported';
            $self->{job_callbacks}->{add_message_callback}->(
                {
                    type    => 'error',
                    message => $outcome->{message},
                }
            ) if $self->{job_callbacks};
            $self->_add_harvest_log('error');
            return;
        }

        # CounterFile::store writes the log row after the import, so a failure in the
        # import normally has no row yet. A row that exists is kept.
        $outcome->{message} = "$error";
        $self->_add_harvest_log('error') unless $self->_harvest_logged;
        die $error;
    };
}

=head3 harvest_outcome

    my $outcome = $ud_provider->harvest_outcome;

Returns the outcome of the last C<harvest_sushi> call as a hashref with
C<status>, C<http_status>, C<exceptions> (arrayref of C<code>, C<severity>,
C<message>, C<data>), optional C<message> and optional C<counter_release>.
Returns undef when no harvest ran on this object.

=cut

sub harvest_outcome {
    my ($self) = @_;

    return $self->{harvest_outcome};
}

=head3 set_background_job_callbacks

    $self->set_background_job_callbacks($background_job_callbacks);

Sets the background job callbacks

=over

=item background_job_callbacks

Background job callbacks

=back

=cut

sub set_background_job_callbacks {
    my ( $self, $background_job_callbacks ) = @_;

    $self->{job_callbacks} = $background_job_callbacks;
}

=head3 test_connection

Tests the connection of the harvester to the SUSHI service and returns any alerts of planned SUSHI outages

=cut

sub test_connection {
    my ($self) = @_;

    my $url = $self->_validate_url( $self->service_url, 'status' );
    $url .= 'status';
    $url .= '?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key           if $self->api_key;

    my $response = _handle_sushi_request($url);

    if ( $response->{_rc} >= 400 ) {
        my $message = $response->{_msg};
        if ( $response->{_rc} == 404 ) {
            Koha::Exceptions::ObjectNotFound->throw($message);
        } elsif ( $response->{_rc} == 401 ) {
            Koha::Exceptions::Authorization::Unauthorized->throw($message);
        } else {
            die sprintf "ERROR testing SUSHI service\n%s\ncode %s: %s\n",
                $url, $response->{_rc},
                $message;
        }
    }

    my $result = decode_json( $response->decoded_content );
    my $status;
    if ( ref($result) eq 'ARRAY' ) {
        for my $r (@$result) {
            $status = $r->{Service_Active} // $r->{ServiceActive};
        }
    } else {
        $status = $result->{Service_Active} // $result->{ServiceActive};
    }

    if ($status) {
        return 1;
    } else {
        return 0;
    }
}

=head3 erm_usage_titles

Method to embed erm_usage_titles to titles for report formatting

=cut

sub erm_usage_titles {
    my ($self) = @_;
    my $usage_title_rs = $self->_result->erm_usage_titles;
    return Koha::ERM::EUsage::UsageTitles->_new_from_dbic($usage_title_rs);
}

=head3 erm_usage_muses

Method to embed erm_usage_muses to titles for report formatting

=cut

sub erm_usage_muses {
    my ($self) = @_;
    my $usage_mus_rs = $self->_result->erm_usage_muses;
    return Koha::ERM::EUsage::MonthlyUsages->_new_from_dbic($usage_mus_rs);
}

=head3 erm_usage_platforms

Method to embed erm_usage_platforms to platforms for report formatting

=cut

sub erm_usage_platforms {
    my ($self) = @_;
    my $usage_platform_rs = $self->_result->erm_usage_platforms;
    return Koha::ERM::EUsage::UsagePlatforms->_new_from_dbic($usage_platform_rs);
}

=head3 erm_usage_items

Method to embed erm_usage_items to items for report formatting

=cut

sub erm_usage_items {
    my ($self) = @_;
    my $usage_item_rs = $self->_result->erm_usage_items;
    return Koha::ERM::EUsage::UsageItems->_new_from_dbic($usage_item_rs);
}

=head3 erm_usage_databases

Method to embed erm_usage_databases to databases for report formatting

=cut

sub erm_usage_databases {
    my ($self) = @_;
    my $usage_database_rs = $self->_result->erm_usage_databases;
    return Koha::ERM::EUsage::UsageDatabases->_new_from_dbic($usage_database_rs);
}

=head2 Internal methods

=head3 _build_url_query

Build the URL query params for COUNTER 5 SUSHI request

=cut

sub _build_url_query {
    my ($self) = @_;

    unless ( $self->service_url && $self->customer_id ) {
        die sprintf
            "SUSHI Harvesting config for usage data provider %d is missing service_url or customer_id\n",
            $self->erm_usage_data_provider_id;
    }

    my $url = $self->_validate_url( $self->service_url, 'harvest' );

    $url .= lc $self->{report_type};
    $url .= '?customer_id=' . $self->customer_id;
    $url .= '&requestor_id=' . $self->requestor_id if $self->requestor_id;
    $url .= '&api_key=' . $self->api_key           if $self->api_key;
    $url .= '&begin_date=' . substr $self->{begin_date}, 0, 7 if $self->{begin_date};
    $url .= '&end_date=' . substr $self->{end_date},     0, 7 if $self->{end_date};
    $url .= '&platform=' . $self->service_platform if $self->service_platform;

    return $url;
}

=head3 _counter_filename

    my $filename = $self->_counter_filename;

Builds the filename of a harvested COUNTER file: provider name, report type and,
when the harvest has a begin date, the harvested month (C<YYYY-MM>).

=cut

sub _counter_filename {
    my ($self) = @_;

    my $filename = $self->name . "_" . $self->{report_type};
    $filename .= "_" . substr( $self->{begin_date}, 0, 7 ) if $self->{begin_date};

    return $filename;
}

=head3 _validate_url

Checks whether the url ends in a trailing "/" and adds one if not

my $url = $self->_validate_url($url, 'harvest')

$caller is either the harvest_sushi function ("harvest") or the test_connection function ("status")

=cut

sub _validate_url {
    my ( $self, $url, $caller ) = @_;

    if ( $caller eq 'harvest' ) {

        $url = _check_trailing_character($url);

        # Default to 5.1 if anything other than '5'
        my $report_release = $self->report_release eq '5' ? $self->report_release : '5.1';

        if ( $report_release eq '5.1' ) {
            my $reports_param = substr $url, -4;
            $url .= 'r51/' if $reports_param ne 'r51/';
        }

        my $reports_param = substr $url, -8;
        $url .= 'reports/' if $reports_param ne 'reports/';
    } else {
        $url = _check_trailing_character($url);
    }

    return $url;
}

=head3 _check_trailing_character

Checks whether a url string ends in a "/" before we concatenate further params to the end of the url

=cut

sub _check_trailing_character {
    my ($url) = @_;

    my $trailing_char = substr $url, -1;
    if ( $trailing_char ne '/' ) {
        $url .= '/';
    }

    return $url;
}

=head3 _collect_sushi_exceptions

    my @exceptions = $self->_collect_sushi_exceptions($decoded_response);

Collects the exceptions of a decoded SUSHI response into
C<< $self->{harvest_outcome}->{exceptions} >> and adds one background job message
per exception, with the exception message and data; the severity is kept in the
exception only. Docs at:
https://cop5.projectcounter.org/en/5.0.2/appendices/f-handling-errors-and-exceptions.html

Exceptions are read, in order, from a top level exception object (C<Code>,
C<Message>, C<Severity>, C<Data>, any case), a top level C<Exceptions> array, the
C<Report_Header.Exceptions> array, and from non-COUNTER vendor bodies (C<errors>
array or C<message>, stored with an undefined code). An array response is read as a
list of exception objects.

=cut

sub _collect_sushi_exceptions {
    my ( $self, $decoded_response ) = @_;

    my $outcome = $self->{harvest_outcome};
    return unless defined $decoded_response;

    my @raw;
    if ( ref($decoded_response) eq 'ARRAY' ) {
        push @raw, grep { ref($_) eq 'HASH' } @{$decoded_response};
    } elsif ( ref($decoded_response) eq 'HASH' ) {
        my $response = $decoded_response;
        push @raw, $response
            if exists $response->{Code} || exists $response->{code} || exists $response->{Severity};
        push @raw, @{ $response->{Exceptions} } if ref( $response->{Exceptions} ) eq 'ARRAY';
        push @raw, @{ $response->{Report_Header}->{Exceptions} }
            if ref( $response->{Report_Header} ) eq 'HASH'
            && ref( $response->{Report_Header}->{Exceptions} ) eq 'ARRAY';
        push @raw, @{ $response->{errors} } if ref( $response->{errors} ) eq 'ARRAY';
        push @raw, { message => $response->{message} }
            if !@raw && defined $response->{message} && !ref( $response->{message} );
    }

    for my $raw (@raw) {
        next unless ref($raw) eq 'HASH';
        my $exception = {
            code     => $raw->{Code}     // $raw->{code},
            severity => $raw->{Severity} // $raw->{severity},
            message  => $raw->{Message}  // $raw->{message},
            data     => $raw->{Data}     // $raw->{data},
        };
        next unless defined $exception->{code} || defined $exception->{message};

        push @{ $outcome->{exceptions} }, $exception;

        my $code_status = Koha::ERM::EUsage::CounterLog->sushi_code_status( $exception->{code} );
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type    => $code_status eq 'error' ? 'error' : 'warning',
                code    => $exception->{code},
                message => join(
                    ' - ',
                    grep { defined $_ && length $_ } $exception->{message}, $exception->{data}
                ),
            }
        ) if $self->{job_callbacks};
    }

    return @{ $outcome->{exceptions} };
}

=head3 _classify_harvest

    my $status = $self->_classify_harvest( { has_items => 1 } );

Returns the counter log status of the current harvest from the HTTP status and the
collected exceptions:

=over

=item C<error>: a SUSHI error code (authorization, unsupported report, bad request),
an HTTP 4xx response without a retry condition, or a response that is not JSON.
A retry gives the same result.

=item C<retry>: a SUSHI retry code (1000, 1010, 1011, 1020, 3031, 3040) or an HTTP
202, 429 or 5xx response. The same report type and period must be harvested again.

=item C<success>: report items were stored and no condition above applies.

=item C<no_usage>: no report items and the provider answered 3030 No Usage Available.
The month is complete, the usage is zero.

=item C<no_data>: no report items and no condition above applies (3032, HTTP 204,
an empty report).

=back

=cut

sub _classify_harvest {
    my ( $self, $args ) = @_;

    my $outcome = $self->{harvest_outcome};
    my $http    = $outcome->{http_status} // 0;
    my @statuses =
        map { Koha::ERM::EUsage::CounterLog->sushi_code_status( $_->{code} ) } @{ $outcome->{exceptions} };

    return 'error'    if grep { $_ eq 'error' } @statuses;
    return 'retry'    if grep { $_ eq 'retry' } @statuses;
    return 'retry'    if $http == 202 || $http == 429 || $http >= 500;
    return 'error'    if $http >= 400;
    return 'error'    if defined $outcome->{message};
    return 'success'  if $args->{has_items};
    return 'no_usage' if grep { $_ eq 'no_usage' } @statuses;
    return 'no_data';
}

=head3 _harvest_outcome_message

Joins the messages of the collected exceptions and the free text message of the
current harvest into one string for warnings and thrown exceptions.

=cut

sub _harvest_outcome_message {
    my ($self) = @_;

    my $outcome = $self->{harvest_outcome};
    my @parts   = map {
        join( ': ', grep { defined $_ && length $_ } $_->{code}, $_->{message} )
    } @{ $outcome->{exceptions} };
    push @parts, $outcome->{message} if defined $outcome->{message};

    return join( '; ', @parts );
}

=head3 _harvest_report_period

    my $period = $self->_harvest_report_period;

Returns a hashref with the C<report_year> and C<report_month> of the harvested month
when the begin and end dates of the current harvest are in the same calendar month.
Both values are undef when the harvest covers more than one month or has no dates.

=cut

sub _harvest_report_period {
    my ($self) = @_;

    my %period = ( report_year => undef, report_month => undef );
    if ( $self->{begin_date} && $self->{end_date} ) {
        my ( $begin_year, $begin_month ) = $self->{begin_date} =~ /^(\d{4})-(\d{2})/;
        my ( $end_year,   $end_month )   = $self->{end_date}   =~ /^(\d{4})-(\d{2})/;
        if ( $begin_year && $end_year && $begin_year == $end_year && $begin_month == $end_month ) {
            $period{report_year}  = int $begin_year;
            $period{report_month} = int $begin_month;
        }
    }

    return \%period;
}

=head3 _harvest_log_args

    my $log_args = $self->_harvest_log_args($status);

Sets the status of the current harvest outcome and returns the counter log fields
that describe it: C<background_job_id>, C<report_type>, C<report_year>,
C<report_month>, C<status> and C<logdetails> (JSON). The request URL is never stored, it holds credentials.

=cut

sub _harvest_log_args {
    my ( $self, $status ) = @_;

    my $outcome = $self->{harvest_outcome};
    $outcome->{status} = $status;

    my %logdetails;
    for my $key ( grep { $_ ne 'status' && defined $outcome->{$_} } keys %{$outcome} ) {
        $logdetails{$key} = $outcome->{$key};
    }

    return {
        background_job_id => $self->{background_job_id},
        report_type       => $self->{report_type},
        %{ $self->_harvest_report_period },
        status     => $status,
        logdetails => JSON->new->canonical->encode( \%logdetails ),
    };
}

=head3 _add_harvest_log

    $self->_add_harvest_log($status);

Creates the counter log row of a harvest that stored no counter file.

=cut

sub _add_harvest_log {
    my ( $self, $status ) = @_;

    my $userenv = C4::Context->userenv;

    return Koha::ERM::EUsage::CounterLog->new(
        {
            borrowernumber         => $userenv ? $userenv->{number} : undef,
            usage_data_provider_id => $self->erm_usage_data_provider_id,
            counter_files_id       => undef,
            importdate             => dt_from_string,
            filename               => undef,
            %{ $self->_harvest_log_args($status) },
        }
    )->store;
}

=head3 _harvest_logged

    my $logged = $self->_harvest_logged;

Returns true when a counter log row exists for the background job of this
harvest. Without a background job id nothing can be matched and it returns false.

=cut

sub _harvest_logged {
    my ($self) = @_;

    return 0 unless $self->{background_job_id};
    return Koha::ERM::EUsage::CounterLogs->search( { background_job_id => $self->{background_job_id} } )->count ? 1 : 0;
}

=head3 _counter_file_size_too_large

Checks whether a counter file size exceeds the size allowed by the database or not
Additionally, adds a background job report message if that is the case

=cut

sub _counter_file_size_too_large {
    my ( $self, $counter_file ) = @_;

    my $max_allowed_packet = C4::Context->dbh->selectrow_array(q{SELECT @@max_allowed_packet});
    if ( length($counter_file) > $max_allowed_packet ) {
        $self->{job_callbacks}->{add_message_callback}->(
            {
                type    => 'error',
                code    => 'payload_too_large',
                message => $max_allowed_packet / 1024 / 1024,
            }
        ) if $self->{job_callbacks};
        return 1;
    }
    return 0;
}

=head3 _handle_sushi_request

Creates and sends the request based on a provided url
Also handles any redirects

=cut

sub _handle_sushi_request {
    my ($url) = @_;

    my $request = HTTP::Request->new( 'GET' => $url );
    my $ua      = LWP::UserAgent->new;
    $ua->agent( 'Koha/' . Koha::version() );
    my $response = $ua->simple_request($request);

    if ( $response->is_redirect ) {
        my $redirect_url = $response->header('Location');
        $redirect_url = URI->new_abs( $redirect_url, $url );
        $response     = $ua->get($redirect_url);
    }

    return $response;
}

=head3 _type

=cut

sub _type {
    return 'ErmUsageDataProvider';
}

1;
