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
use Test::More tests => 7;
use Test::Warn;

use Koha::Account;
use Koha::Account::Lines;
use Koha::Database;
use Koha::Items;
use Koha::Old::Checkouts;
use Koha::Overdues::ActionExecutor;
use Koha::Patron::Restriction;

use t::lib::Mocks;
use t::lib::Mocks::Logger;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'new initialises empty queues' => sub {
    plan tests => 3;

    my $executor = Koha::Overdues::ActionExecutor->new;
    isa_ok( $executor, 'Koha::Overdues::ActionExecutor' );
    is_deeply( $executor->{action_batch_queue}, [], 'action_batch_queue starts empty' );
    is_deeply( $executor->{notice_queue},       {}, 'notice_queue starts empty' );
};

subtest '_resolve_rule_context_branchcode honours CircControl + HomeOrHoldingBranch' => sub {
    plan tests => 3;

    my $executor = Koha::Overdues::ActionExecutor->new;
    my $row      = {
        patronhomebranch  => 'PATRON_HB',
        itemhomebranch    => 'ITEM_HB',
        itemholdingbranch => 'ITEM_HD',
    };

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );
    is(
        $executor->_resolve_rule_context_branchcode($row),
        'PATRON_HB', 'CircControl=PatronLibrary → patron home'
    );

    t::lib::Mocks::mock_preference( 'CircControl',         'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'homebranch' );
    is(
        $executor->_resolve_rule_context_branchcode($row),
        'ITEM_HB', 'CircControl=ItemHomeLibrary + HomeOrHoldingBranch=homebranch → item home'
    );

    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'holdingbranch' );
    is(
        $executor->_resolve_rule_context_branchcode($row),
        'ITEM_HD', 'CircControl=ItemHomeLibrary + HomeOrHoldingBranch=holdingbranch → item holding'
    );
};

subtest 'route_item_actions_to_queue splits notice vs action batch' => sub {
    plan tests => 5;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $effective_rule_sets = {
        'LIB|PC|IT|7' => {
            actions => [
                { type => 'notice',   notice_code => 'OD1', mtt => 'email' },
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

    my $notice_key = '42|OD1|email|7';
    ok(
        exists $executor->{notice_queue}->{$notice_key},
        "notice routed under borrowernumber|notice_code|mtt|delay ($notice_key)"
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

subtest 'enact_restrict adds an OVERDUES debarment' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron   = $builder->build_object( { class => 'Koha::Patrons' } );
    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->enact_restrict( { borrowernumber => $patron->borrowernumber } );

    my $restrictions = $patron->restrictions->search( { type => 'OVERDUES' } );
    is( $restrictions->count,            1,          'one OVERDUES restriction added' );
    is( $restrictions->next->type->code, 'OVERDUES', 'restriction type is OVERDUES' );

    $schema->storage->txn_rollback;
};

subtest 'enact_lost / enact_forgive_fine / enact_mark_returned' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item    = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue   = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library->branchcode,
            },
        }
    );

    my $account      = Koha::Account->new( { patron_id => $patron->borrowernumber } );
    my $overdue_fine = $account->add_debit(
        {
            amount     => 4.50,
            interface  => 'commandline',
            type       => 'OVERDUE',
            item_id    => $item->itemnumber,
            issue_id   => $issue->issue_id,
            library_id => $library->branchcode,
        }
    );
    $overdue_fine->status('UNRETURNED')->store;

    my $overdue_item = {
        borrowernumber => $patron->borrowernumber,
        itemnumber     => $item->itemnumber,
        issue_id       => $issue->issue_id,
    };

    my $executor = Koha::Overdues::ActionExecutor->new;

    # enact_forgive_fine forgives the UNRETURNED OVERDUE accountline for this issue.
    $executor->enact_forgive_fine($overdue_item);
    $overdue_fine->discard_changes;
    is( $overdue_fine->amountoutstanding + 0, 0, 'enact_forgive_fine zeros the outstanding overdue' );

    # enact_lost flips status to LOST and sets itemlost.
    $executor->enact_lost( $overdue_item, 2 );
    $item->discard_changes;
    is( $item->itemlost, 2, 'enact_lost sets itemlost' );
    $overdue_fine->discard_changes;
    is( $overdue_fine->status, 'LOST', 'mark_lost flipped the OVERDUE accountline status to LOST' );

    # enact_mark_returned archives the checkout via MarkIssueReturned.
    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    $executor->enact_mark_returned($overdue_item);

    is(
        Koha::Checkouts->search( { issue_id => $issue->issue_id } )->count,
        0, 'checkout removed from issues'
    );
    is(
        Koha::Old::Checkouts->search( { issue_id => $issue->issue_id } )->count,
        1, 'checkout archived to old_issues'
    );

    $schema->storage->txn_rollback;
};

subtest 'enact_charge creates LOST debit with caller-resolved branch' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'LostChargesControl',        'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch',       'homebranch' );
    t::lib::Mocks::mock_preference( 'useDefaultReplacementCost', 0 );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item    = $builder->build_sample_item( { homebranch => $library->branchcode, replacementprice => 8.00 } );
    my $issue   = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->borrowernumber,
                itemnumber     => $item->itemnumber,
                branchcode     => $library->branchcode,
            },
        }
    );

    my $overdue_item = {
        borrowernumber => $patron->borrowernumber,
        itemnumber     => $item->itemnumber,
        issue_id       => $issue->issue_id,
        replacementfee => 8.00,
    };

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->enact_charge($overdue_item);

    my $lost = Koha::Account::Lines->search(
        {
            borrowernumber  => $patron->borrowernumber,
            itemnumber      => $item->itemnumber,
            debit_type_code => 'LOST',
        }
    );
    is( $lost->count, 1, 'one LOST debit created' );

    my $line = $lost->next;
    is( $line->amount + 0, 8.00, 'LOST debit amount comes from replacementfee' );
    is(
        $line->branchcode, $library->branchcode,
        'LOST debit stamped with item home library (LostChargesControl=ItemHomeLibrary)'
    );

    # No replacement fee → warn and skip.
    my $item_free    = $builder->build_sample_item( { homebranch => $library->branchcode, replacementprice => 0 } );
    my $overdue_free = {
        borrowernumber => $patron->borrowernumber,
        itemnumber     => $item_free->itemnumber,
        issue_id       => undef,
        replacementfee => 0,
    };

    # Construct before enact_charge so Koha::Logger->get is mocked when it fires
    my $logger = t::lib::Mocks::Logger->new();
    $executor->enact_charge($overdue_free);
    $logger->warn_like( qr/No replacement fee set/, 'warns and skips when replacementfee is zero' );

    $schema->storage->txn_rollback;
};
