#!/usr/bin/perl

# Copyright Koha Community 2026
#
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

use Koha::Auth::Hostname;
use Koha::Auth::Hostnames;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'sync_from_syspref() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    Koha::Auth::Hostnames->search->delete;

    # OPACBaseURL maps to hostname_id=1
    t::lib::Mocks::mock_preference( 'OPACBaseURL', 'https://opac.example.com' );
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', 'https://opac.example.com' );

    my $opac = Koha::Auth::Hostnames->find(1);
    ok( $opac, 'OPACBaseURL creates hostname_id=1' );
    is( $opac->hostname, 'opac.example.com', 'hostname_id=1 has correct hostname' );

    # staffClientBaseURL maps to hostname_id=2
    Koha::Auth::Hostname->sync_from_syspref( 'staffClientBaseURL', 'https://staff.example.com' );

    my $staff = Koha::Auth::Hostnames->find(2);
    ok( $staff, 'staffClientBaseURL creates hostname_id=2' );
    is( $staff->hostname, 'staff.example.com', 'hostname_id=2 has correct hostname' );

    # Updating the URL changes the stored hostname in-place
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', 'https://newopac.example.com' );
    $opac->discard_changes;
    is( $opac->hostname, 'newopac.example.com', 'hostname_id=1 updated when OPACBaseURL changes' );
    is( Koha::Auth::Hostnames->search( { hostname_id => 1 } )->count, 1, 'Still only one row for hostname_id=1' );

    # Idempotent: calling again with the same value is a no-op
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', 'https://newopac.example.com' );
    is(
        Koha::Auth::Hostnames->search( { hostname => 'newopac.example.com' } )->count, 1,
        'Idempotent: no duplicate created'
    );

    # Unencrypted URLs are also supported (hostname is extracted, protocol is discarded)
    my $unencrypted_url = 'http' . '://opac.example.org';
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', $unencrypted_url );
    $opac->discard_changes;
    is( $opac->hostname, 'opac.example.org', 'Unencrypted URL hostname extracted correctly' );

    # Port numbers are stripped
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', 'https://opac.example.net:8080/path' );
    $opac->discard_changes;
    is( $opac->hostname, 'opac.example.net', 'Port number stripped from hostname' );

    # Empty value is a no-op
    my $hostname_before = $opac->hostname;
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', '' );
    $opac->discard_changes;
    is( $opac->hostname, $hostname_before, 'Empty value leaves existing hostname unchanged' );

    # Malformed URL (no protocol) is a no-op
    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', 'not-a-valid-url' );
    $opac->discard_changes;
    is( $opac->hostname, $hostname_before, 'Malformed URL leaves existing hostname unchanged' );

    # Unknown preference name is ignored
    Koha::Auth::Hostname->sync_from_syspref( 'SomeOtherPref', 'https://other.example.com' );
    is(
        Koha::Auth::Hostnames->search( { hostname => 'other.example.com' } )->count,
        0, 'Unknown syspref name is ignored'
    );

    $schema->storage->txn_rollback;
};

subtest 'sync_from_sysprefs() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    Koha::Auth::Hostnames->search->delete;

    t::lib::Mocks::mock_preference( 'OPACBaseURL',        'https://opac.example.com' );
    t::lib::Mocks::mock_preference( 'staffClientBaseURL', 'https://staff.example.com' );

    Koha::Auth::Hostname->sync_from_sysprefs;

    my $opac  = Koha::Auth::Hostnames->find(1);
    my $staff = Koha::Auth::Hostnames->find(2);

    ok( $opac, 'hostname_id=1 exists after sync_from_sysprefs' );
    is( $opac->hostname, 'opac.example.com', 'hostname_id=1 has OPAC hostname' );

    ok( $staff, 'hostname_id=2 exists after sync_from_sysprefs' );
    is( $staff->hostname, 'staff.example.com', 'hostname_id=2 has staff hostname' );

    $schema->storage->txn_rollback;
};

subtest 'Koha::Auth::Hostnames type tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $hostname = $builder->build_object( { class => 'Koha::Auth::Hostnames' } );
    is( ref($hostname), 'Koha::Auth::Hostname', 'build_object returns correct object type' );

    my $hostnames = Koha::Auth::Hostnames->search( { hostname_id => $hostname->hostname_id } );
    is( ref($hostnames), 'Koha::Auth::Hostnames', 'search returns correct collection type' );

    $schema->storage->txn_rollback;
};
