#!/usr/bin/perl

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

use Getopt::Long qw( GetOptions );
use Pod::Usage   qw( pod2usage );

use C4::Context;
use Koha::ERM::EUsage::YearlyUsages;
use Koha::Script;

=head1 NAME

erm_migrate_counter_data.pl - Migrate the ERM usage statistics data written before Bug 41307

=head1 SYNOPSIS

erm_migrate_counter_data.pl [--confirm] [--verbose] [--logs] [--usage]

 Options:
   -c|--confirm     Apply the changes. Without it the script only reports what it would do
   -v|--verbose     Report each counter log and each monthly usage row
   --logs           Only backfill the period of the counter logs
   --usage          Only remove the duplicated monthly usage rows and rebuild the yearly usage
   -h|--help        Print this help

=head1 OPTIONS

=over 8

=item B<-c|--confirm>

Apply the changes. Without this option the script is a dry run: it reads the
database, reports what it would change and writes nothing.

=item B<-v|--verbose>

Report each counter log that is changed or skipped, and each monthly usage row
that is removed.

=item B<--logs>

Only backfill the report type and the period of the counter logs.

=item B<--usage>

Only remove the duplicated monthly usage rows and rebuild the yearly usage.

=item B<-h|--help>

Print this help and exit.

=back

Without C<--logs> and C<--usage> the script runs both parts.

=head1 DESCRIPTION

Run this script once after the upgrade that adds the report type, the report period
and the status to C<erm_counter_logs> (Bug 41307). The upgrade changes the tables only.

The summary page of the usage data providers (Bug 38822) reads counter logs that have a
period. It skips the logs written before the upgrade until this script has run.

=head2 Counter logs (--logs)

A counter log written before the upgrade has no report type and no period. The script
reads them from the file of the log:

=over

=item * The report type is the one of the counter file.

=item * The months are the ones of the C<Reporting_Period> header row of the file, or
the month columns of the file when it has no such row. Only the first 4000 bytes of the
file are read.

=item * Before Bug 41294 one harvest covered several months. A log that covers more than
one month becomes one log for each month. All of them point at the same file and keep the
import date, the user and the status of the first.

=item * Every month gets the status C<success>. The old code wrote a log only after a
file was imported.

=item * The background job is not linked.

=back

A log whose file has no reporting period is reported and left without a period. A log
with a report type of more than 10 characters is reported and left as it is.

=head2 Monthly usage (--usage)

Re-harvests before Bug 42217 left duplicated rows in C<erm_usage_mus>, which double the
yearly totals. Two rows are the same when every column except C<usage_count> is the same.
The newest row of each group is kept: it holds the last count the provider sent.

The yearly usage in C<erm_usage_yus> is then rebuilt from the monthly usage, so its totals follow the
cleaned rows. This runs even when no duplicate is found, which also repairs a yearly total that is out of date.

=head2 Running again

The script can run again. A log that already has a period is not read again, and a second
run finds no duplicated usage. Logs that were left without a period are reported again.

=cut

my ( $confirm, $verbose, $logs, $usage, $help );

GetOptions(
    'c|confirm' => \$confirm,
    'v|verbose' => \$verbose,
    'logs'      => \$logs,
    'usage'     => \$usage,
    'h|help'    => \$help,
) or pod2usage(2);

pod2usage( -verbose => 2 ) if $help;

# Keep the warnings and the report in order
$| = 1;

# No part chosen: run both
$logs = $usage = 1 unless $logs || $usage;

warn "Running in dry-run mode, provide --confirm to apply the changes\n"
    unless $confirm;

my $dbh = C4::Context->dbh;

foreach my $column (qw( report_type report_year report_month status )) {
    my ($exists) = $dbh->selectrow_array(
        q{
            SELECT COUNT(*)
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
              AND table_name = 'erm_counter_logs'
              AND column_name = ?
        }, undef, $column
    );
    die "The column erm_counter_logs.$column does not exist, run updatedatabase first\n"
        unless $exists;
}

in_transaction( sub { backfill_counter_logs() } )   if $logs;
in_transaction( sub { remove_duplicated_usage() } ) if $usage;

if ( $usage && $confirm ) {
    my $rows = Koha::ERM::EUsage::YearlyUsages->rebuild;
    say sprintf "Rebuilt the yearly usage: %d rows", $rows;
}

=head1 INTERNAL METHODS

=head2 in_transaction

    in_transaction( sub { ... } );

Runs the code in one transaction when the changes are applied, and rolls it back if the
code dies. A dry run writes nothing, so it runs the code as it is.

=cut

sub in_transaction {
    my ($code) = @_;

    return $code->() unless $confirm;

    $dbh->begin_work;
    my @result = eval { $code->() };
    if ( my $error = $@ ) {
        $dbh->rollback;
        die $error;
    }
    $dbh->commit;

    return @result;
}

=head2 months_of_header

    my @months = months_of_header($header);

Returns the C<[ year, month ]> of each month the beginning of a COUNTER file reports.
They are the months from C<Begin_Date> to C<End_Date> of the C<Reporting_Period> row, or,
when the file has no such row, the month columns (C<Mmm-yyyy>, or C<Mmm yyyy> in files
generated by older releases). Returns an empty list when there is none.

=cut

sub months_of_header {
    my ($header) = @_;

    return () unless defined $header;

    my %month_number = (
        Jan => 1, Feb => 2, Mar => 3, Apr => 4,  May => 5,  Jun => 6,
        Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12
    );

    my @lines = split /\r?\n/, $header;
    my $top   = join "\n", @lines[ 0 .. ( $#lines < 15 ? $#lines : 15 ) ];

    if ( $top =~ /Reporting_Period\W+Begin_Date=(\d{4})-(\d{2})(?:-\d{2})?;\s*End_Date=(\d{4})-(\d{2})/ ) {
        my ( $year, $month, $end_year, $end_month ) = ( $1, $2 + 0, $3, $4 + 0 );
        my @months;
        while ( $year * 12 + $month <= $end_year * 12 + $end_month ) {
            push @months, [ $year, $month ];
            if ( ++$month > 12 ) {
                $month = 1;
                $year++;
            }
        }
        return @months;
    }

    my ( %seen, @months );
    while ( $top =~ /\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[ -](\d{4})\b/g ) {
        my ( $year, $month ) = ( $2, $month_number{$1} );
        push @months, [ $year, $month ] unless $seen{"$year-$month"}++;
    }

    return @months;
}

=head2 backfill_counter_logs

Gives the counter logs that have no period a report type and a period. See L</DESCRIPTION>.

=cut

sub backfill_counter_logs {

    my $counter_logs = $dbh->selectall_arrayref(
        q{
            SELECT l.erm_counter_log_id, l.borrowernumber, l.counter_files_id,
                   l.usage_data_provider_id, l.importdate, l.filename, l.logdetails,
                   l.status, l.report_type, f.type AS file_type,
                   SUBSTRING(f.file_content, 1, 4000) AS header
              FROM erm_counter_logs l
              LEFT JOIN erm_counter_files f ON f.erm_counter_files_id = l.counter_files_id
             WHERE l.report_year IS NULL AND l.report_month IS NULL
             ORDER BY l.erm_counter_log_id
        },
        { Slice => {} }
    );

    unless ( @{$counter_logs} ) {
        say "No counter logs without a reporting period";
        return;
    }

    my $update = $dbh->prepare(
        q{UPDATE erm_counter_logs SET report_type = ?, report_year = ?, report_month = ? WHERE erm_counter_log_id = ?});
    my $insert = $dbh->prepare(
        q{INSERT INTO erm_counter_logs (borrowernumber, counter_files_id, usage_data_provider_id, importdate, filename, logdetails, report_type, report_year, report_month, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}
    );

    my ( $updated, $added, $skipped ) = ( 0, 0, 0 );
    foreach my $log ( @{$counter_logs} ) {
        my $name        = sprintf "Counter log %s (%s)", $log->{erm_counter_log_id}, $log->{filename} // '';
        my $report_type = $log->{report_type} // $log->{file_type};

        if ( defined $report_type && length $report_type > 10 ) {
            warn "$name: report type '$report_type' is too long, row left as it is\n";
            $skipped++;
            next;
        }

        my @months = months_of_header( $log->{header} );
        unless (@months) {
            $update->execute( $report_type, undef, undef, $log->{erm_counter_log_id} )
                if $confirm && defined $report_type && !defined $log->{report_type};
            warn "$name: no reporting period found in the file, row left without a period\n";
            $skipped++;
            next;
        }

        my $first = shift @months;
        $update->execute( $report_type, @{$first}, $log->{erm_counter_log_id} ) if $confirm;
        $updated++;
        say sprintf "%s: %s %d-%02d", $name, $confirm ? 'period set to' : 'period would be set to', @{$first}
            if $verbose;

        foreach my $month (@months) {
            $insert->execute(
                @{$log}{qw(borrowernumber counter_files_id usage_data_provider_id importdate filename logdetails)},
                $report_type, @{$month}, $log->{status}
            ) if $confirm;
            $added++;
            say sprintf "%s: %s %d-%02d", $name, $confirm ? 'log added for' : 'log would be added for', @{$month}
                if $verbose;
        }
    }

    if ($confirm) {
        say sprintf
            "Backfilled the reporting period of %d counter logs, added %d rows for further months, %d rows skipped",
            $updated, $added, $skipped;
    } else {
        say sprintf
            "Would backfill the reporting period of %d counter logs, add %d rows for further months, skip %d rows",
            $updated, $added, $skipped;
    }
}

=head2 remove_duplicated_usage

Removes the duplicated rows of C<erm_usage_mus> and keeps the newest of each group.
See L</DESCRIPTION>.

=cut

sub remove_duplicated_usage {

    my $same_usage = q{
          FROM erm_usage_mus older
          JOIN erm_usage_mus newer
            ON older.title_id <=> newer.title_id
           AND older.platform_id <=> newer.platform_id
           AND older.database_id <=> newer.database_id
           AND older.item_id <=> newer.item_id
           AND older.usage_data_provider_id <=> newer.usage_data_provider_id
           AND older.year <=> newer.year
           AND older.month <=> newer.month
           AND older.metric_type <=> newer.metric_type
           AND older.access_type <=> newer.access_type
           AND older.yop <=> newer.yop
           AND older.report_type <=> newer.report_type
           AND older.monthly_usage_summary_id < newer.monthly_usage_summary_id
    };

    my $older_ids = $dbh->selectcol_arrayref(
        qq{SELECT DISTINCT older.monthly_usage_summary_id $same_usage ORDER BY older.monthly_usage_summary_id});

    unless ( @{$older_ids} ) {
        say "No duplicated monthly usage rows";
        return;
    }

    if ($verbose) {
        say sprintf "Monthly usage row %d: %s", $_, $confirm ? 'removed' : 'would be removed' for @{$older_ids};
    }

    my $removed = scalar @{$older_ids};
    $removed = $dbh->do(qq{DELETE older $same_usage}) + 0 if $confirm;

    if ($confirm) {
        say sprintf "Removed %d duplicated monthly usage rows, the newest row of each is kept", $removed;
    } else {
        say sprintf "Would remove %d duplicated monthly usage rows, the newest row of each is kept", $removed;
    }
}
