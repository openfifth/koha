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

process_circulation_triggers.pl [ --dry-run ] [ --verbose ] [ --debug ]

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

=back

=cut

use strict;
use warnings;
use Getopt::Long qw( GetOptions );
use Koha::Database;
use Koha::Overdues::TriggerProcessor;
use C4::Log qw( cronlogaction );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

my $dry_run = 0;
my $verbose = 0;
my $debug   = 0;

GetOptions(
    'dry-run' => \$dry_run,
    'verbose' => \$verbose,
    'debug'   => \$debug,
);

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

my $triggerProcessor =
    Koha::Overdues::TriggerProcessor->new( { verbose => $verbose, debug => $debug, dry_run => $dry_run } );
$triggerProcessor->ProcessOverdues();

if ($dry_run) {
    $schema->storage->txn_rollback;
}

cronlogaction( { action => 'End', info => "COMPLETED" } );
