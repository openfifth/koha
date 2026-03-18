#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2023 PTFS Europe Ltd
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

=head1 NAME

marc_ordering_process.pl - cron script to retrieve MARC files and create order lines

=head1 SYNOPSIS

./marc_ordering_process.pl [-c|--confirm] [-v|--verbose] [-d|--delete] [-r|--rename ext]

or, in crontab:
# Once every day
0 3 * * * marc_ordering_process.pl -c

=head1 DESCRIPTION

This script searches for new MARC files via configured file transports,
stages those files, adds biblios/items and creates order lines.

=head1 OPTIONS

=over

=item B<-v|--verbose>

Print report to standard out.

=item B<-c|--confirm>

Without this parameter no changes will be made

=item B<-d|--delete>

Delete the remote source file once it has been processed

=item B<-r|--rename ext>

Rename the remote source file once it has been processed, adding the given file extension

=item B<-a|--archive dir>

Copy downloaded files into the specified local archive directory after processing

=back

=cut

use Modern::Perl;
use Pod::Usage   qw( pod2usage );
use Getopt::Long qw( GetOptions );
use File::Copy   qw( copy );
use File::Temp   qw( tempdir );

use Koha::Script -cron;
use Koha::MarcOrder;
use Koha::MarcOrderAccounts;

use C4::Log qw( cronlogaction );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

my ( $help, $verbose, $confirm, $delete, $rename_ext, $archive_dir );
GetOptions(
    'h|help'      => \$help,
    'v|verbose'   => \$verbose,
    'c|confirm'   => \$confirm,
    'd|delete'    => \$delete,
    'r|rename=s'  => \$rename_ext,
    'a|archive=s' => \$archive_dir,
) || pod2usage(1);

pod2usage(0) if $help;

$verbose = 1            unless $verbose or $confirm;
print "Test run only\n" unless $confirm;

print "Fetching MARC ordering accounts\n" if $verbose;
my @accounts = Koha::MarcOrderAccounts->search(
    {},
    { join => [ 'vendor', 'budget' ] }
)->as_list;

if ( scalar(@accounts) == 0 ) {
    print "No accounts found - you must create a MARC order account for this cronjob to run\n" if $verbose;
}

my $valid_file_extensions = qr/\.(mrc|marcxml|mrk)$/i;

foreach my $acct (@accounts) {
    my $file_transport = $acct->file_transport;
    unless ($file_transport) {
        say "No file transport configured for account: " . $acct->description if $verbose;
        next;
    }

    my $working_dir = $file_transport->download_directory;
    unless ($working_dir) {
        say "No download directory configured for file transport: " . $file_transport->id if $verbose;
        next;
    }

    if ($verbose) {
        say sprintf "Starting MARC ordering process for %s", $acct->vendor->name;
        say sprintf "Looking for new files in %s",           $working_dir;
    }

    unless ( $file_transport->connect() ) {
        say "Failed to connect to file transport: " . $file_transport->id;
        next;
    }

    my $success = $file_transport->change_directory($working_dir);
    if ( !$success ) {
        say "Failed to change to download directory: $working_dir";
        next;
    }

    # Get file list
    my $file_list = $file_transport->list_files();
    unless ($file_list) {
        say "Failed to get file list from transport";
        next;
    }

    my @files;
    foreach my $file ( @{$file_list} ) {
        my $filename = $file->{filename};
        next unless $filename =~ $valid_file_extensions;
        push @files, $filename;
    }

    print "No new files found\n" if scalar(@files) == 0;

    my $files_processed = 0;
    my $local_dir       = tempdir( CLEANUP => 1 );

    foreach my $filename (@files) {
        my $local_file = "$local_dir/$filename";

        unless ( $file_transport->download_file( $filename, $local_file ) ) {
            say "Failed to download file: $filename";
            next;
        }

        my $args = {
            filename => $filename,
            filepath => $local_file,
            profile  => $acct,
            agent    => 'cron'
        };
        if ( $acct->match_field && $acct->match_value ) {
            my $file_match = Koha::MarcOrder->match_file_to_account($args);
            next if !$file_match;
        }
        if ($confirm) {
            say sprintf "Creating order lines from file %s", $filename if $verbose;

            my $result = Koha::MarcOrder->create_order_lines_from_file($args);
            if ( $result->{success} ) {
                $files_processed++;
                say sprintf "Successfully processed file: %s", $filename if $verbose;
                if ($archive_dir) {
                    mkdir $archive_dir unless -d $archive_dir;
                    say sprintf "Archiving file: %s to %s", $filename, $archive_dir if $verbose;
                    copy( $local_file, "$archive_dir/$filename" );
                }
                if ($delete) {
                    say sprintf "Deleting file: %s", $filename if $verbose;
                    $file_transport->delete_file($filename);
                } elsif ($rename_ext) {
                    say sprintf "Renaming file: %s to %s.%s", $filename, $filename, $rename_ext if $verbose;
                    $file_transport->rename_file( $filename, "$filename.$rename_ext" );
                }
            } else {
                say sprintf "Error processing file: %s", $filename        if $verbose;
                say sprintf "Error message: %s",         $result->{error} if $verbose;
            }
        }
    }
    say sprintf "%s file(s) processed", $files_processed unless $files_processed == 0;
    print "Moving to next account\n\n";
}
print "Process complete\n";
cronlogaction( { action => 'End', info => "COMPLETED" } );
