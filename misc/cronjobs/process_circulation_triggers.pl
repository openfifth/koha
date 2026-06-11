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

process_circulation_triggers.pl [ --dry-run ]

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

GetOptions( 'dry-run' => \$dry_run );

my $schema = Koha::Database->new->schema;
if ($dry_run) {
    $schema->storage->txn_begin;
    print "Dry run: changes will be rolled back\n";
}

my $triggerProcessor = Koha::Overdues::TriggerProcessor->new();
$triggerProcessor->ProcessOverdues();

if ($dry_run) {
    $schema->storage->txn_rollback;
}

cronlogaction( { action => 'End', info => "COMPLETED" } );
