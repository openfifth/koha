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
use Test::More tests => 3;

use Koha::Overdues::ActionExecutor;

use t::lib::Mocks;

subtest 'new initialises empty queues' => sub {
    plan tests => 2;

    my $executor = Koha::Overdues::ActionExecutor->new;
    isa_ok( $executor, 'Koha::Overdues::ActionExecutor' );
    is_deeply( $executor->{action_batch_queue}, [], 'action_batch_queue starts empty' );
};

subtest 'route_item_actions_to_queue batches actions' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $effective_rule_sets = {
        'LIB|PC|IT|7' => {
            actions => [
                { type => 'lost',     value => 1 },
                { type => 'charge',   value => 1 },
                { type => 'restrict', value => '' },    # empty → ignored
            ],
        },
    };

    my $overdue_item = {
        borrowernumber   => 42,
        itemnumber       => 7,
        categorycode     => 'PC',
        itemtype         => 'IT',
        patronhomebranch => 'LIB',
        days_overdue     => 7,
    };

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->route_item_actions_to_queue( $effective_rule_sets, $overdue_item );

    is( scalar @{ $executor->{action_batch_queue} }, 1, 'one action batch enqueued' );
    my $batch = $executor->{action_batch_queue}->[0];
    is( $batch->{delay}, 7, 'batch carries the delay' );
    is_deeply(
        $batch->{actions},
        { lost => 1, charge => 1 },
        'lost + charge present, empty-string restrict dropped'
    );

    # No rule set for the context → noop.
    my $other = { %$overdue_item, days_overdue => 99 };
    $executor->route_item_actions_to_queue( $effective_rule_sets, $other );
    is( scalar @{ $executor->{action_batch_queue} }, 1, 'unmatched context does not enqueue' );
};
