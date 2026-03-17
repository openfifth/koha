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

./marc_ordering_process.pl [-c|--confirm] [-v|--verbose] [--dr|--delete-remote] [--rr|--rename-remote ext]

or, in crontab:
# Once every day
0 3 * * * marc_ordering_process.pl -c

=head1 DESCRIPTION

This script searches for new MARC files in a configured location (local, FTP, or SFTP).
If there are new files, it stages those files, adds bibliographic records/items and creates order lines.

=head1 OPTIONS

=over

=item B<-v|--verbose>

Print report to standard out.

=item B<-c|--confirm>

Without this parameter no changes will be made

=item B<-d|--delete>

Delete the file once it has been processed

=item B<--dr|--delete-remote>

Delete the remote file once it has been downloaded

=item B<--rr|--rename-remote ext>

Rename the remote file once it has been downloaded, adding the given file extension

=back

=cut

use Modern::Perl;
use Pod::Usage   qw( pod2usage );
use Getopt::Long qw( GetOptions );
use File::Copy   qw( copy move );

use Koha::Script -cron;
use Koha::MarcOrder;
use Koha::MarcOrderAccounts;

use C4::Log qw( cronlogaction );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

my ( $help, $verbose, $confirm, $delete, $rename_ext, $delete_remote );
GetOptions(
    'h|help'             => \$help,
    'v|verbose'          => \$verbose,
    'c|confirm'          => \$confirm,
    'd|delete'           => \$delete,
    'dr|delete-remote'   => \$delete_remote,
    'rr|rename-remote=s' => \$rename_ext,
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
    if ($verbose) {
        say sprintf "Starting MARC ordering process for %s", $acct->vendor->name;
        say sprintf "Looking for new files in %s",           $acct->download_directory;
    }

    my $working_dir = $acct->download_directory;

    my $file_transport = $acct->file_transport;
    if ( $file_transport && $confirm ) {
        if ( $file_transport->connect() ) {
            my $download_dir = $file_transport->download_directory;

            my $success = $download_dir ? $file_transport->change_directory($download_dir) : 1;
            if ( $download_dir && !$success ) {
                say "Failed to change to download directory: $download_dir" if $verbose;
            } else {

                # Get file list
                my $file_list = $file_transport->list_files();
                if ($file_list) {

                    # Process files matching our criteria
                    foreach my $file ( @{$file_list} ) {
                        my $filename = $file->{filename};

                        if ( $filename =~ $valid_file_extensions ) {

                            my $local_file = "$working_dir/$filename";

                            # Download the file
                            if ( $file_transport->download_file( $filename, $local_file ) ) {
                                if ($rename_ext) {
                                    $file_transport->rename_file( $filename, "$filename.$rename_ext" );
                                } elsif ($delete_remote) {
                                    $file_transport->delete_file($filename);
                                }
                            } else {
                                say "Failed to download file: $filename" if $verbose;
                            }
                        }
                    }

                } else {
                    say "Failed to get file list from transport" if $verbose;
                }

            }
        } else {
            say "Failed to connect to file transport: " . $file_transport->id if $verbose;
        }
    }

    opendir my $dir, $working_dir or die "Can't open filepath";
    my @files = grep { /$valid_file_extensions/ } readdir $dir;
    closedir $dir;
    print "No new files found\n" if scalar(@files) == 0;

    my $files_processed = 0;

    foreach my $filename (@files) {
        my $full_path = "$working_dir/$filename";
        my $args      = {
            filename => $filename,
            filepath => $full_path,
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
                if ($delete) {
                    say sprintf "Deleting processed file: %s", $filename if $verbose;
                    unlink $full_path;
                } else {
                    mkdir "$working_dir/archive" unless -d "$working_dir/archive";
                    say sprintf "Moving file to archive: %s", $filename if $verbose;
                    move( $full_path, "$working_dir/archive/$filename" );
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
