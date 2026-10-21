#!/usr/bin/env perl

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

use Test::NoWarnings;
use Test::More tests => 4;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::EUsage::CounterLogs;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 23;

    $schema->storage->txn_begin;

    Koha::ERM::EUsage::CounterLogs->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    ## Authorized user tests
    # No counter logs, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs")->status_is(200)->json_is( [] );

    my $counter_log =
        $builder->build_object( { class => 'Koha::ERM::EUsage::CounterLogs', value => { status => 'success' } } );

    # One counter_log created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs")->status_is(200)->json_is( [ $counter_log->to_api ] );

    my $another_counter_log = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::CounterLogs',
            value => { status => 'success' },
        }
    );

    # Two counter_logs created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs")
        ->status_is(200)
        ->json_is( [ $counter_log->to_api, $another_counter_log->to_api, ] );

    # Return 2 counter logs with patron embedded
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs/" => { 'x-koha-embed' => 'patron' } )
        ->status_is(200)
        ->json_is(
        [
            { %{ $counter_log->to_api }, patron => $counter_log->patron->to_api( { user => $librarian } ) },
            {
                %{ $another_counter_log->to_api },
                patron => $another_counter_log->patron->to_api( { user => $librarian } )
            }
        ]
        );

    # Filter on status to find the harvests that need a retry
    my $job = $builder->build_object(
        {
            class => 'Koha::BackgroundJobs',
            value => { type => 'erm_sushi_harvester', context => '{}', data => '{}' },
        }
    );
    my $retry_counter_log = $builder->build_object(
        {
            class => 'Koha::ERM::EUsage::CounterLogs',
            value => {
                status            => 'retry',
                background_job_id => $job->id,
                logdetails        => '{"http_status":200,"exceptions":[{"code":3031,"message":"Usage Not Ready"}]}',
            },
        }
    );
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs?q=" . '{"status":"retry"}' )
        ->status_is(200)
        ->json_is( [ $retry_counter_log->to_api ] );

    # Embed the background job that created the log
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs?q="
            . '{"erm_counter_log_id":'
            . $retry_counter_log->erm_counter_log_id
            . '}' => { 'x-koha-embed' => 'background_job' } )
        ->status_is(200)
        ->json_is( '/0/background_job/job_id' => $retry_counter_log->background_job_id );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs?blah=blah")
        ->status_is(400)
        ->json_is( [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/counter_logs")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $counter_log = $builder->build_object( { class => 'Koha::ERM::EUsage::CounterLogs' } );
    my $librarian   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # This get method is not implemented should return 404
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs/" . $counter_log->erm_counter_log_id )->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $counter_log_id = $builder->build_object( { class => 'Koha::ERM::EUsage::CounterLogs' } )->erm_counter_log_id;

    # Attempt to delete fails (route does not exist)
    $t->delete_ok("//$unauth_userid:$password@/api/v1/erm/counter_logs/$counter_log_id")->status_is(404);

    # Attempt to delete non-existent counter_log
    $t->delete_ok("//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id")->status_is(404);

    $schema->storage->txn_rollback;
};
