#!/usr/bin/env perl

# Copyright 2026 Open Fifth

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
use Test::More tests => 2;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::EUsage::CounterLogs;
use Koha::ERM::EUsage::CounterLogSummaries;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 21;

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

    my $add_log = sub {
        my ( $provider, $values ) = @_;
        return $builder->build_object(
            {
                class => 'Koha::ERM::EUsage::CounterLogs',
                value => {
                    usage_data_provider_id => $provider->erm_usage_data_provider_id,
                    counter_files_id       => undef,
                    background_job_id      => undef,
                    report_type            => 'TR_J1',
                    %{$values},
                },
            }
        );
    };

    ## Authorized user tests
    # No counter logs, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs/summary")->status_is(200)->json_is( [] );

    my $provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );
    $add_log->( $provider, { report_year => 2026, report_month => 1, status => 'success' } );
    $add_log->( $provider, { report_year => 2026, report_month => 2, status => 'retry' } );

    my $summary = Koha::ERM::EUsage::CounterLogSummaries->search->next;

    # One provider, one report type and one year give one row
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs/summary")->status_is(200)->json_is( [ $summary->to_api ] );

    # A second provider with an older year gives a second row, ordered by year
    my $other_provider = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageDataProviders' } );
    $add_log->( $other_provider, { report_year => 2025, report_month => 12, status => 'no_data' } );

    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs/summary?_order_by=-report_year")
        ->status_is(200)
        ->json_is( '/0/report_year' => 2026 )
        ->json_is( '/1/report_year' => 2025 );

    # Filter on the provider name
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs/summary?q="
            . '{"provider_name":"'
            . $other_provider->name
            . '"}' )->status_is(200)->json_is( '/0/month_12' => 'no_data' );

    # Filter on the year
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs/summary?q=" . '{"report_year":2026}' )
        ->status_is(200)
        ->json_is( '/0/month_2' => 'retry' );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs/summary?blah=blah")
        ->status_is(400)
        ->json_is( [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/counter_logs/summary")->status_is(403);

    $schema->storage->txn_rollback;
};
