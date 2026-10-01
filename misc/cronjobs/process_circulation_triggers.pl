#!/usr/bin/perl
#-----------------------------------
# Copyright 2025 Open Fifth
#
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.
#-----------------------------------

=head1 NAME

process_circulation_triggers.pl  daily cron script to process overdue materials.

=head1 SYNOPSIS

process_circulation_triggers.pl [ --date <yyyy-mm-dd> ] [ --dry-run ] [ --verbose ] [ --debug ] [ --quiet ]

=head1 DESCRIPTION

This script is designed to update item lost and/or returned statuses,
borrower restrictions, and charge item lost fees. Depending on system
preferences and circulation triggers, it may also alert patrons and
administrators of overdue items.

When the C<OverdueTriggersCalendar> system preference is enabled, trigger
delays are measured in open days using each branch's calendar; otherwise
delays are measured in calendar days.

=head1 OPTIONS

=over

=item B<--date>

Process the triggers that fall due on this date rather than today. Format:
YYYY-MM-DD.

Actions fire only on the exact day a delay comes due, so a run that does not
happen drops that day's triggers permanently. Passing the missed date replays
it: every delay is measured backward from that date, and the once-per-day guard
on synthesised print notices is scoped to it as well.

=item B<--dry-run>

Run the full pipeline inside a transaction that is rolled back at the end,
producing no permanent changes (no debarments, lost flags, charges, returns,
or queued notices).

The rollback covers database effects. The search index update and holds queue
job reached from C<Koha::Item::store> publish to a message broker and would
survive it, so a dry run suppresses both.

=item B<--verbose>

Print one line per action as it is enacted and per letter as it is queued, so
the reported sequence is the sequence that ran. Composes with C<--dry-run>.

=item B<--debug>

In addition to C<--verbose> output, dump the matched overdue rows and the
effective rule-set entries used to route them. Composes with C<--dry-run>.

=item B<--quiet>

Suppress the end-of-run summary, which is otherwise printed on every run: the
number of overdue checkouts matched, followed by one line per kind of thing the
run did, in the order it did them. Lines with nothing to report are omitted, so
a run that only queued notices prints one.

The summary reports counts, not amounts. What a charge came to belongs with the
accountlines it created, which carry the library and item the global figure would
have flattened away.

=back

=cut

use strict;
use warnings;
use Getopt::Long qw( GetOptions );
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Overdues::TriggerProcessor;
use C4::Log qw( cronlogaction );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

my $date_input;
my $dry_run = 0;
my $verbose = 0;
my $debug   = 0;
my $quiet   = 0;

GetOptions(
    'date=s'  => \$date_input,
    'dry-run' => \$dry_run,
    'verbose' => \$verbose,
    'debug'   => \$debug,
    'quiet'   => \$quiet,
);

# Summary lines, in the order process_action_queue enacts them, so the summary
# reads as a transcript of the run. Notices precede them all, being drained
# first, and the restriction lifting pass closes it.
my @SUMMARY_LINES = (
    [ 'restricted', 'restrict',            'patrons' ],
    [ 'forgiven',   'forgive_fine',        'fines' ],
    [ 'lost',       'lost',                'items' ],
    [ 'charged',    'charge',              'items' ],
    [ 'returned',   'mark_returned',       'items' ],
    [ 'lifted',     'restrictions_lifted', 'restrictions' ],
);

sub print_summary {
    my ( $summary, $date ) = @_;

    print "\n### CIRCULATION TRIGGERS SUMMARY ###\n";
    printf "Trigger date: %s\n",              $date->ymd;
    printf "Matched: %d overdue checkouts\n", $summary->{matched};
    print "\n";

    if ( $summary->{notices_queued} || $summary->{notices_suppressed} ) {
        printf "  %-12s %4d queued, %d suppressed\n", 'notices', $summary->{notices_queued},
            $summary->{notices_suppressed};
    }

    foreach my $line (@SUMMARY_LINES) {
        my ( $label, $key, $noun ) = @$line;

        if ( !$summary->{$key} ) {
            next;
        }

        printf "  %-12s %4d %s\n", $label, $summary->{$key}, $noun;
    }

    return;
}

my $trigger_date;
if ($date_input) {
    eval { $trigger_date = dt_from_string( $date_input, 'iso' ); };
    if ( $@ || !$trigger_date ) {
        die "$date_input is not a valid date, aborting! Use a date in format YYYY-MM-DD.\n";
    }
} else {
    $trigger_date = dt_from_string();
}

# --debug dumps full hashrefs and would balloon cron mail / log files at
# realistic data volumes. If STDOUT isn't a terminal (cron), silently
# downgrade --debug so the run still completes — overdues processing has
# real financial impact (lost-item charges, account restrictions) and must
# not be skipped because of a misconfigured crontab flag.
if ( $debug && !-t STDOUT ) {
    warn "--debug suppressed: not running on an interactive terminal\n";
    $debug = 0;
}

my $schema = Koha::Database->new->schema;
if ($dry_run) {
    $schema->storage->txn_begin;
    print "DRY RUN: changes will be rolled back\n";
    print "Projected outcome: \n";
    print "--------------------------------------- \n";
}

my $triggerProcessor = Koha::Overdues::TriggerProcessor->new(
    { verbose => $verbose, debug => $debug, dry_run => $dry_run, trigger_date => $trigger_date } );
$triggerProcessor->ProcessOverdues();

if ( !$quiet ) {
    print_summary( $triggerProcessor->summary, $trigger_date );
}

if ($dry_run) {
    $schema->storage->txn_rollback;
}

my $summary = $triggerProcessor->summary;
my $outcome = $dry_run ? 'COMPLETED (dry run)' : 'COMPLETED';

cronlogaction(
    {
        action => 'End',
        info   => join( " ", $outcome, map { "$_=" . $summary->{$_} } sort keys %$summary ),
    }
);
