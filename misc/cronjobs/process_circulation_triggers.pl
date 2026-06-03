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

=head1 DESCRIPTION

This script is designed to update item lost and/or returned statuses,
borrower restrictions, and charge item lost fees. Depending on system
preferences and circulation triggers, it may also alert patrons and
administrators of overdue items.

When the C<OverdueTriggersCalendar> system preference is enabled, trigger
delays are measured in open days using each branch's calendar; otherwise
delays are measured in calendar days.

=cut

use strict;
use warnings;
use Koha::Overdues::TriggerProcessor;
use C4::Log qw( cronlogaction );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

my $triggerProcessor = Koha::Overdues::TriggerProcessor->new();
$triggerProcessor->ProcessOverdues();

cronlogaction( { action => 'End', info => "COMPLETED" } );
