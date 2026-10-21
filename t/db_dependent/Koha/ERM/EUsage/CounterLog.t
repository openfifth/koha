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
use Test::More tests => 5;

use Koha::BackgroundJobs;
use Koha::Database;
use Koha::ERM::EUsage::CounterLog;

use t::lib::Mocks;
use t::lib::TestBuilder;
use Test::MockModule;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'sushi_code_status() tests' => sub {
    plan tests => 16;

    my $class = 'Koha::ERM::EUsage::CounterLog';

    is( $class->sushi_code_status(1000),  'retry',    '1000 Service Not Available needs a retry' );
    is( $class->sushi_code_status(1011),  'retry',    '1011 Report Queued needs a retry' );
    is( $class->sushi_code_status(1020),  'retry',    '1020 Too Many Requests needs a retry' );
    is( $class->sushi_code_status(3031),  'retry',    '3031 Usage Not Ready needs a retry' );
    is( $class->sushi_code_status(3040),  'retry',    '3040 Partial Data needs a retry' );
    is( $class->sushi_code_status(3030),  'no_usage', '3030 No Usage Available is no_usage' );
    is( $class->sushi_code_status(3032),  'no_data',  '3032 Usage No Longer Available is no_data' );
    is( $class->sushi_code_status(2000),  'error',    '2000 Requestor Not Authorized is an error' );
    is( $class->sushi_code_status(3020),  'error',    '3020 Invalid Date Arguments is an error' );
    is( $class->sushi_code_status(3050),  'info',     '3050 Parameter Not Recognized is informational' );
    is( $class->sushi_code_status(3062),  'info',     '3062 Invalid ReportAttribute Value is informational' );
    is( $class->sushi_code_status(3070),  'error',    '3070 Required ReportFilter Missing is an error' );
    is( $class->sushi_code_status(9999),  'error',    'An unknown code of 1000 or above is an error' );
    is( $class->sushi_code_status(0),     'info',     'Code 0 is informational' );
    is( $class->sushi_code_status(undef), 'info',     'An undefined code is informational' );
    is( $class->sushi_code_status('abc'), 'info',     'A non numeric code is informational' );
};

subtest 'decoded_logdetails() tests' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $log = Koha::ERM::EUsage::CounterLog->new( { logdetails => undef } )->store;
    is_deeply( $log->decoded_logdetails, {}, 'Empty logdetails decode to an empty hashref' );

    $log->logdetails('not json')->store;
    is_deeply( $log->decoded_logdetails, {}, 'Invalid JSON decodes to an empty hashref' );

    $log->logdetails('{"http_status":503,"exceptions":[{"code":1000,"message":"Service Not Available"}]}')->store;
    is_deeply(
        $log->decoded_logdetails,
        { http_status => 503, exceptions => [ { code => 1000, message => 'Service Not Available' } ] },
        'Valid JSON is decoded'
    );

    $schema->storage->txn_rollback;
};

subtest 'background_job() tests' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $job = $builder->build_object( { class => 'Koha::BackgroundJobs' } );

    my $log       = Koha::ERM::EUsage::CounterLog->new( { background_job_id => $job->id } )->store;
    my $found_job = $log->background_job;
    is( ref($found_job), 'Koha::BackgroundJob', 'background_job returns a Koha::BackgroundJob' );
    is( $found_job->id,  $job->id,              'background_job returns the job that created the log' );

    my $orphan_log = Koha::ERM::EUsage::CounterLog->new( { background_job_id => undef } )->store;
    is( $orphan_log->background_job, undef, 'A log without a job returns undef' );

    $schema->storage->txn_rollback;
};

subtest 'patron' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build( { source => 'Branch' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->{branchcode} }
        }
    );

    my $counterlog = Koha::ERM::EUsage::CounterLog->new(
        {
            borrowernumber => $patron->borrowernumber,
        }
    )->store;

    my $p = $counterlog->patron;
    is(
        ref($p), 'Koha::Patron',
        'Koha::ERM::EUsage::CounterLog->patron should return a Koha::Patron'
    );
    is(
        $p->borrowernumber, $patron->borrowernumber,
        'Koha::ERM::EUsage::CounterLog->patron should return the correct patron'
    );

    $schema->storage->txn_rollback;

};
