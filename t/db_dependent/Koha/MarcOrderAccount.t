#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2025 Koha Development team
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

use Test::More tests => 5;
use Test::NoWarnings;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::MarcOrderAccounts;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'vendor() relationship' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $vendor  = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $account = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { vendor_id => $vendor->id }
        }
    );

    is(
        ref( $account->vendor ),
        'Koha::Acquisition::Bookseller',
        '->vendor should return a Koha::Acquisition::Bookseller object'
    );

    is(
        $account->vendor->id,
        $vendor->id,
        'Vendor relationship returns the correct vendor'
    );

    $schema->storage->txn_rollback;
};

subtest 'budget() relationship' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $budget  = $builder->build_object( { class => 'Koha::Acquisition::Funds' } );
    my $account = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { budget_id => $budget->budget_id }
        }
    );

    is(
        ref( $account->budget ),
        'Koha::Acquisition::Fund',
        '->budget should return a Koha::Acquisition::Fund object'
    );

    is(
        $account->budget->budget_id,
        $budget->budget_id,
        'Budget relationship returns the correct budget'
    );

    $schema->storage->txn_rollback;
};

subtest 'file_transport() relationship' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    # Test with no file transport (NULL foreign key)
    my $account_no_transport = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { file_transport_id => undef }
        }
    );

    is(
        $account_no_transport->file_transport,
        undef,
        '->file_transport should return undef when no transport is configured'
    );

    # Test with SFTP transport
    my $sftp_transport = $builder->build_object(
        {
            class => 'Koha::File::Transports',
            value => {
                transport => 'sftp',
                name      => 'Test SFTP',
                host      => 'test.example.com',
            }
        }
    );

    my $account_sftp = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { file_transport_id => $sftp_transport->id }
        }
    );

    my $transport = $account_sftp->file_transport;

    is(
        ref($transport),
        'Koha::File::Transport::SFTP',
        '->file_transport should return polymorphic SFTP object for SFTP transport'
    );

    is(
        $transport->id,
        $sftp_transport->id,
        'Transport relationship returns the correct transport ID'
    );

    can_ok( $transport, 'connect' );

    # Test with FTP transport
    my $ftp_transport = $builder->build_object(
        {
            class => 'Koha::File::Transports',
            value => {
                transport => 'ftp',
                name      => 'Test FTP',
                host      => 'ftp.example.com',
            }
        }
    );

    my $account_ftp = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { file_transport_id => $ftp_transport->id }
        }
    );

    my $ftp = $account_ftp->file_transport;

    is(
        ref($ftp),
        'Koha::File::Transport::FTP',
        '->file_transport should return polymorphic FTP object for FTP transport'
    );

    # Test with Local transport
    my $local_transport = $builder->build_object(
        {
            class => 'Koha::File::Transports',
            value => {
                transport => 'local',
                name      => 'Test Local',
                host      => 'localhost',
            }
        }
    );

    my $account_local = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { file_transport_id => $local_transport->id }
        }
    );

    my $local = $account_local->file_transport;

    is(
        ref($local),
        'Koha::File::Transport::Local',
        '->file_transport should return polymorphic Local object for local transport'
    );

    can_ok( $local, 'download_file' );
    can_ok( $local, 'delete_file' );

    $schema->storage->txn_rollback;
};

subtest 'file_transport() respects prefetched relationships' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    # Create a transport and account
    my $sftp_transport = $builder->build_object(
        {
            class => 'Koha::File::Transports',
            value => {
                transport => 'sftp',
                name      => 'Test SFTP Prefetch',
                host      => 'prefetch.example.com',
            }
        }
    );

    my $account = $builder->build_object(
        {
            class => 'Koha::MarcOrderAccounts',
            value => { file_transport_id => $sftp_transport->id }
        }
    );

    # Search with prefetch to load the relationship
    my $account_with_prefetch = Koha::MarcOrderAccounts->search(
        { id       => $account->id },
        { prefetch => 'file_transport' }
    )->next;

    # Enable query logging to count queries
    my @queries;
    my $original_debug = $schema->storage->debug;
    $schema->storage->debugcb(
        sub {
            my ( $op, $info ) = @_;
            push @queries, $info if $op eq 'SELECT';
        }
    );
    $schema->storage->debug(1);

    # Access the prefetched relationship
    my $transport = $account_with_prefetch->file_transport;

    # Disable query logging
    $schema->storage->debug($original_debug);

    is( scalar @queries, 0, 'No additional queries when accessing prefetched file_transport' );

    is(
        ref($transport),
        'Koha::File::Transport::SFTP',
        'Prefetched transport returns correct polymorphic class'
    );

    is( $transport->id, $sftp_transport->id, 'Prefetched transport has correct ID' );

    is( $transport->name, 'Test SFTP Prefetch', 'Prefetched transport has correct data' );

    $schema->storage->txn_rollback;
};
