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
use Test::More tests => 6;

use Koha::Overdues::ActionExecutor;

use t::lib::Mocks;

subtest 'new initialises empty queues' => sub {
    plan tests => 3;

    my $executor = Koha::Overdues::ActionExecutor->new;
    isa_ok( $executor, 'Koha::Overdues::ActionExecutor' );
    is_deeply( $executor->{action_batch_queue}, [], 'action_batch_queue starts empty' );
    is_deeply( $executor->{notice_queue},       {}, 'notice_queue starts empty' );
};

subtest 'route_item_actions_to_queue splits notice vs action batch' => sub {
    plan tests => 5;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $effective_rule_sets = {
        'LIB|PC|IT|7' => {
            actions => [
                { type => 'notice',   notice_code => 'OD1', mtts => ['email'] },
                { type => 'lost',     value       => 1 },
                { type => 'charge',   value       => 1 },
                { type => 'restrict', value       => '' },    # empty → ignored
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

    ok(
        exists $executor->{notice_queue}{42}{OD1}{email}{7},
        'notice routed under {borrowernumber}{notice_code}{mtt}{delay}'
    );

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

subtest 'route_item_actions_to_queue: an open return claim suppresses a bare reminder, never an escalation notice' =>
    sub {
    plan tests => 5;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $reminder_only = {
        'LIB|PC|IT|7' => {
            actions => [ { type => 'notice', notice_code => 'OD1', mtts => ['email'] } ],
        },
    };
    my $escalation = {
        'LIB|PC|IT|7' => {
            actions => [
                { type => 'notice', notice_code => 'OD1', mtts => ['email'] },
                { type => 'charge', value => 1 },
            ],
        },
    };

    my $claimed_item = {
        borrowernumber    => 42,
        itemnumber        => 7,
        categorycode      => 'PC',
        itemtype          => 'IT',
        patronhomebranch  => 'LIB',
        days_overdue      => 7,
        open_return_claim => 1,
    };

    # Bare reminder on a loan under an open return claim → suppressed.
    my $reminder_run = Koha::Overdues::ActionExecutor->new;
    $reminder_run->route_item_actions_to_queue( $reminder_only, $claimed_item );
    ok(
        !exists $reminder_run->{notice_queue}{42},
        'open return claim, notice-only trigger → no notice queued'
    );

    # Same claimed loan, but the trigger also charges → event notification, notice sent.
    my $escalation_run = Koha::Overdues::ActionExecutor->new;
    $escalation_run->route_item_actions_to_queue( $escalation, $claimed_item );
    ok(
        exists $escalation_run->{notice_queue}{42}{OD1}{email}{7},
        'open return claim, charge+notice trigger → notice queued (event notification)'
    );
    is(
        scalar @{ $escalation_run->{action_batch_queue} }, 1,
        'the charge action is still batched for the claimed loan'
    );

    # Control: an unclaimed loan on the notice-only trigger still notifies.
    my $unclaimed_run = Koha::Overdues::ActionExecutor->new;
    $unclaimed_run->route_item_actions_to_queue( $reminder_only, { %$claimed_item, open_return_claim => 0 } );
    ok(
        exists $unclaimed_run->{notice_queue}{42}{OD1}{email}{7},
        'unclaimed loan, notice-only trigger → notice queued'
    );

    # A lost item with no claim follows its triggers: a configured flow that sets
    # lost and later informs the patron is honoured.
    my $lost_run = Koha::Overdues::ActionExecutor->new;
    $lost_run->route_item_actions_to_queue( $reminder_only, { %$claimed_item, open_return_claim => 0, itemlost => 1 } );
    ok(
        exists $lost_run->{notice_queue}{42}{OD1}{email}{7},
        'lost item without a return claim, notice-only trigger → notice queued'
    );
    };

subtest 'route_item_actions_to_queue: aggregates multiple items under (borrower|code|mtt|delay) key' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $effective_rule_sets = {
        'LIB|PC|IT|7' => {
            actions => [ { type => 'notice', notice_code => 'OD1', mtts => ['email'] } ],
        },
        'LIB|PC|IT|14' => {
            actions => [ { type => 'notice', notice_code => 'OD1', mtts => ['email'] } ],
        },
    };

    my $base_item = {
        borrowernumber   => 42,
        categorycode     => 'PC',
        itemtype         => 'IT',
        patronhomebranch => 'LIB',
    };

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->route_item_actions_to_queue(
        $effective_rule_sets,
        { %$base_item, itemnumber => 7, days_overdue => 7 },
    );
    $executor->route_item_actions_to_queue(
        $effective_rule_sets,
        { %$base_item, itemnumber => 8, days_overdue => 7 },
    );
    $executor->route_item_actions_to_queue(
        $effective_rule_sets,
        { %$base_item, itemnumber => 9, days_overdue => 14 },
    );

    is(
        scalar keys %{ $executor->{notice_queue}{42}{OD1}{email} }, 2,
        'two delay buckets exist under (42, OD1, email)'
    );
    ok(
        exists $executor->{notice_queue}{42}{OD1}{email}{7},
        'delay=7 bucket routed'
    );
    is(
        scalar @{ $executor->{notice_queue}{42}{OD1}{email}{7} }, 2,
        'two items at delay 7 collapse into one bucket with two entries'
    );
    is(
        scalar @{ $executor->{notice_queue}{42}{OD1}{email}{14} }, 1,
        'distinct delay routes to its own bucket, one entry'
    );
};

subtest 'route_item_actions_to_queue: multi-MTT fans out per-MTT queue entries' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $effective_rule_sets = {
        'LIB|PC|IT|7' => {
            actions => [
                { type => 'notice', notice_code => 'OD1', mtts => [ 'email', 'print' ] },
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

    is(
        scalar keys %{ $executor->{notice_queue}{42}{OD1} }, 2,
        'two mtt sub-buckets for (42, OD1)'
    );
    ok( exists $executor->{notice_queue}{42}{OD1}{email}{7}, 'email bucket routed' );
    ok( exists $executor->{notice_queue}{42}{OD1}{print}{7}, 'print bucket routed' );
    is(
        $executor->{notice_queue}{42}{OD1}{print}{7}->[0]->{action}->{mtt},
        'print',
        'per-entry action carries the split mtt'
    );
};
