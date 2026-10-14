#!/usr/bin/perl

# Copyright Open Fifth 2025
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

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 2;

use Koha::CirculationRules;
use Koha::Database;
use Koha::Overdues::TriggerProcessor;

use t::lib::Mocks;

my $schema = Koha::Database->new->schema;

subtest 'no overdue delay rules → early return' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar', 0 );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue%delay' } } )->delete;

    my $tp = Koha::Overdues::TriggerProcessor->new;
    is( $tp->process_overdues, undef, 'returns early when no overdue delay rules exist' );

    # A run that never reaches _dispatch_overdues reports nothing matched and no
    # action counts, rather than an empty-looking summary indistinguishable from
    # a run that matched rows and did nothing with them.
    is_deeply( $tp->summary, { matched => 0 }, 'summary reports matched 0 with no action counts' );

    $schema->storage->txn_rollback;
};
