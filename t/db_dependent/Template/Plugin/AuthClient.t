#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 4;
use Test::Exception;
use Test::MockModule;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;
use t::lib::Mocks::Logger;

BEGIN {
    use_ok('Koha::Template::Plugin::AuthClient');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $logger  = t::lib::Mocks::Logger->new();

subtest 'get_providers() tests' => sub {

    plan tests => 2;

    subtest 'Normal operation' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my $plugin = Koha::Template::Plugin::AuthClient->new();
        my $providers;

        lives_ok {
            $providers = $plugin->get_providers('staff');
        }
        'get_providers executes without error';

        is( ref($providers), 'ARRAY', 'Returns array reference' );

        $schema->storage->txn_rollback;
    };

    subtest 'Database error handling' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;
        $logger->clear();

        # Mock search to simulate database schema mismatch
        my $mock = Test::MockModule->new('Koha::Auth::Identity::Providers');
        $mock->mock(
            'search',
            sub {
                die "DBD::mysql::st execute failed: Unknown column 'domains.auto_register_opac' in 'field list'";
            }
        );
        $mock->mock( 'find_exclusive_provider', sub { return } );

        my $plugin = Koha::Template::Plugin::AuthClient->new();
        my $providers;

        lives_ok {
            $providers = $plugin->get_providers('staff');
        }
        'get_providers handles database errors gracefully';

        $logger->warn_like( qr/AuthClient: Unable to load identity providers/, 'Logs warning about database issue' );

        $schema->storage->txn_rollback;
    };
};

subtest 'hostname_candidates() tests' => sub {

    plan tests => 5;

    my @candidates;

    @candidates = Koha::Auth::Identity::Providers->hostname_candidates('example.com');
    is_deeply( \@candidates, [ 'example.com', '*' ], 'No port: returns hostname and wildcard (deduplicated)' );

    @candidates = Koha::Auth::Identity::Providers->hostname_candidates('example.com:8080');
    is_deeply(
        \@candidates, [ 'example.com:8080', 'example.com', '*' ],
        'With port: returns host:port, bare hostname, and wildcard'
    );

    @candidates = Koha::Auth::Identity::Providers->hostname_candidates('localhost:8081');
    is_deeply( \@candidates, [ 'localhost:8081', 'localhost', '*' ], 'localhost with port works correctly' );

    @candidates = Koha::Auth::Identity::Providers->hostname_candidates('*');
    is_deeply( \@candidates, ['*'], 'Wildcard input returns only wildcard (deduplicated)' );

    @candidates = Koha::Auth::Identity::Providers->hostname_candidates(undef);
    is_deeply( \@candidates, ['*'], 'Undef hostname returns only wildcard' );
};
