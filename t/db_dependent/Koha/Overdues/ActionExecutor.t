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

use Test::MockModule;
use Test::NoWarnings;
use Test::More tests => 20;
use Test::Warn;

use Koha::Account;
use Koha::Account::Lines;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Items;
use Koha::Notice::Message;
use Koha::Notice::Messages;
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

subtest 'route_item_actions_to_queue: itemlost suppresses a bare reminder, never an escalation notice' => sub {
    plan tests => 4;

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

    my $lost_item = {
        borrowernumber   => 42,
        itemnumber       => 7,
        categorycode     => 'PC',
        itemtype         => 'IT',
        patronhomebranch => 'LIB',
        days_overdue     => 7,
        itemlost         => 1,
    };

    # Bare reminder on a lost item → suppressed.
    my $reminder_run = Koha::Overdues::ActionExecutor->new;
    $reminder_run->route_item_actions_to_queue( $reminder_only, $lost_item );
    ok(
        !exists $reminder_run->{notice_queue}{42},
        'lost item, notice-only trigger → no notice queued'
    );

    # Same lost item, but the trigger also charges → event notification, notice sent.
    my $escalation_run = Koha::Overdues::ActionExecutor->new;
    $escalation_run->route_item_actions_to_queue( $escalation, $lost_item );
    ok(
        exists $escalation_run->{notice_queue}{42}{OD1}{email}{7},
        'lost item, charge+notice trigger → notice queued (event notification)'
    );
    is(
        scalar @{ $escalation_run->{action_batch_queue} }, 1,
        'the charge action is still batched for the lost item'
    );

    # Control: a non-lost item on the notice-only trigger still notifies.
    my $not_lost_run = Koha::Overdues::ActionExecutor->new;
    $not_lost_run->route_item_actions_to_queue( $reminder_only, { %$lost_item, itemlost => 0 } );
    ok(
        exists $not_lost_run->{notice_queue}{42}{OD1}{email}{7},
        'non-lost item, notice-only trigger → notice queued'
    );
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

subtest 'process_notice_queue: digest entry enqueues one Koha::Notice::Message with repeated items' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $item_a  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $item_b  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue_a = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item_a->itemnumber }
        }
    );
    my $issue_b = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item_b->itemnumber }
        }
    );

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD1',
                branchcode             => q{},
                message_transport_type => 'email',
                name                   => 'OD1',
                title                  => 'Overdue notice for [% borrower.firstname %]',
                content                => "You have [% count %] overdue item(s): <item><<items.barcode>> </item>",
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    my $base_item = {
        borrowernumber    => $patron->borrowernumber,
        categorycode      => $patron->categorycode,
        itemtype          => $item_a->itype,
        patronhomebranch  => $library->branchcode,
        itemhomebranch    => $library->branchcode,
        itemholdingbranch => $library->branchcode,
        days_overdue      => 7,
    };

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'OD1', 'email', 7,
        [
            {
                item   => { %$base_item, itemnumber => $item_a->itemnumber, issue_id => $issue_a->issue_id },
                action => { type => 'notice', notice_code => 'OD1', mtt => 'email' },
                delay  => 7,
            },
            {
                item   => { %$base_item, itemnumber => $item_b->itemnumber, issue_id => $issue_b->issue_id },
                action => { type => 'notice', notice_code => 'OD1', mtt => 'email' },
                delay  => 7,
            },
        ],
    );

    $executor->process_notice_queue;

    my $messages =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } );
    is( $messages->count, 1, 'one Koha::Notice::Message row created for the digest key' );

    my $message = $messages->next;
    is( $message->message_transport_type, 'email',   'mtt copied from action' );
    is( $message->status,                 'pending', 'status pending — waiting for SendQueuedMessages' );
    like(
        $message->content, qr/2 overdue item/,
        'count substitution reflects aggregated item count'
    );
    like(
        $message->content, qr/\Q@{ [ $item_a->barcode ] }\E.*\Q@{ [ $item_b->barcode ] }\E/s,
        'both items appear in the repeat loop'
    );

    $schema->storage->txn_rollback;
};

subtest 'process_notice_queue: two items at the same trigger render one row' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $item_a  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $item_b  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue_a = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item_a->itemnumber }
        }
    );
    my $issue_b = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item_b->itemnumber }
        }
    );

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD2',
                branchcode             => q{},
                message_transport_type => 'email',
                name                   => 'OD2',
                title                  => 'Overdue',
                content                => 'You have [% count %] overdue item(s)',
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    my $base_item = {
        borrowernumber    => $patron->borrowernumber,
        categorycode      => $patron->categorycode,
        itemtype          => $item_a->itype,
        patronhomebranch  => $library->branchcode,
        itemhomebranch    => $library->branchcode,
        itemholdingbranch => $library->branchcode,
        days_overdue      => 3,
    };

    my $effective_rule_sets = {
        join( '|', $library->branchcode, $patron->categorycode, $item_a->itype, 3 ) => {
            actions => [ { type => 'notice', notice_code => 'OD2', mtts => ['email'] } ],
        },
    };

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->route_item_actions_to_queue(
        $effective_rule_sets,
        { %$base_item, itemnumber => $item_a->itemnumber, issue_id => $issue_a->issue_id }
    );
    $executor->route_item_actions_to_queue(
        $effective_rule_sets,
        { %$base_item, itemnumber => $item_b->itemnumber, issue_id => $issue_b->issue_id }
    );

    is(
        scalar @{ $executor->{notice_queue}{ $patron->borrowernumber }{OD2}{email}{3} }, 2,
        'two items collapse to one notice_queue bucket pre-process'
    );

    $executor->process_notice_queue;

    my $messages =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD2' } );
    is( $messages->count, 1, 'two items at the same trigger render exactly one row' );

    $schema->storage->txn_rollback;
};

subtest 'process_notice_queue: missing patron warns and skips' => sub {
    plan tests => 2;

    my $logger = t::lib::Mocks::Logger->new();

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        999999999, 'OD1', 'email', 7,
        [
            {
                item   => { borrowernumber => 999999999, itemnumber  => 1,     patronhomebranch => 'X' },
                action => { type           => 'notice',  notice_code => 'OD1', mtt              => 'email' },
                delay  => 7,
            },
        ],
    );

    $executor->process_notice_queue;

    $logger->warn_like( qr/borrower 999999999 not found/, 'warns on missing patron' );
    is(
        Koha::Notice::Messages->search( { borrowernumber => 999999999 } )->count,
        0, 'no Koha::Notice::Message row created'
    );
};

subtest 'process_notice_queue: missing letter template warns and skips' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    my $logger = t::lib::Mocks::Logger->new();

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'NO_SUCH_CODE', 'email', 7,
        [
            {
                item => {
                    borrowernumber    => $patron->borrowernumber,
                    itemnumber        => $item->itemnumber,
                    issue_id          => $issue->issue_id,
                    patronhomebranch  => $library->branchcode,
                    itemhomebranch    => $library->branchcode,
                    itemholdingbranch => $library->branchcode,
                },
                action => { type => 'notice', notice_code => 'NO_SUCH_CODE', mtt => 'email' },
                delay  => 7,
            },
        ],
    );

    warning_like { $executor->process_notice_queue }
    qr/No circulation NO_SUCH_CODE letter transported by email/,
        'C4::Letters warns when the template is missing';

    $logger->warn_like( qr/no letter for/, 'ActionExecutor logs "no letter for" via Koha::Logger' );
    is(
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'NO_SUCH_CODE' } )
            ->count,
        0, 'no Koha::Notice::Message row created'
    );

    $schema->storage->txn_rollback;
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

subtest 'process_notice_queue: email -> print fallback when patron has no email' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode => $library->branchcode,
                email      => q{},
                emailpro   => q{},
                B_email    => q{},
            }
        }
    );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD1',
                branchcode             => q{},
                message_transport_type => 'print',
                name                   => 'OD1 print',
                title                  => 'OD1',
                content                => 'print body',
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'OD1', 'email', 7,
        [
            {
                item => {
                    borrowernumber    => $patron->borrowernumber,
                    itemnumber        => $item->itemnumber,
                    issue_id          => $issue->issue_id,
                    patronhomebranch  => $library->branchcode,
                    itemhomebranch    => $library->branchcode,
                    itemholdingbranch => $library->branchcode,
                },
                action => { type => 'notice', notice_code => 'OD1', mtt => 'email' },
                delay  => 7,
            },
        ],
    );

    $executor->process_notice_queue;

    my $messages =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } );
    is( $messages->count, 1, 'exactly one Koha::Notice::Message row created' );
    is(
        $messages->next->message_transport_type, 'print',
        'mtt is print (synthesised fallback)'
    );

    $schema->storage->txn_rollback;
};

subtest 'process_notice_queue: sms -> print fallback when patron has no smsalertnumber' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode     => $library->branchcode,
                smsalertnumber => q{},
            }
        }
    );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD1',
                branchcode             => q{},
                message_transport_type => 'print',
                name                   => 'OD1 print',
                title                  => 'OD1',
                content                => 'print body',
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'OD1', 'sms', 7,
        [
            {
                item => {
                    borrowernumber    => $patron->borrowernumber,
                    itemnumber        => $item->itemnumber,
                    issue_id          => $issue->issue_id,
                    patronhomebranch  => $library->branchcode,
                    itemhomebranch    => $library->branchcode,
                    itemholdingbranch => $library->branchcode,
                },
                action => { type => 'notice', notice_code => 'OD1', mtt => 'sms' },
                delay  => 7,
            },
        ],
    );

    $executor->process_notice_queue;

    my $messages =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } );
    is( $messages->count, 1, 'exactly one Koha::Notice::Message row created' );
    is(
        $messages->next->message_transport_type, 'print',
        'mtt is print (synthesised fallback)'
    );

    $schema->storage->txn_rollback;
};

subtest 'process_notice_queue: pending print in message_queue blocks fallback synthesis' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode => $library->branchcode,
                email      => q{},
                emailpro   => q{},
                B_email    => q{},
            }
        }
    );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    # Pre-seed a pending print row from a notional prior run.
    Koha::Notice::Message->new(
        {
            borrowernumber         => $patron->borrowernumber,
            letter_code            => 'OD1',
            message_transport_type => 'print',
            status                 => 'pending',
            subject                => 'OD1',
            content                => 'prior body',
            time_queued            => dt_from_string,
        }
    )->store;

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'OD1', 'email', 7,
        [
            {
                item => {
                    borrowernumber    => $patron->borrowernumber,
                    itemnumber        => $item->itemnumber,
                    issue_id          => $issue->issue_id,
                    patronhomebranch  => $library->branchcode,
                    itemhomebranch    => $library->branchcode,
                    itemholdingbranch => $library->branchcode,
                },
                action => { type => 'notice', notice_code => 'OD1', mtt => 'email' },
                delay  => 7,
            },
        ],
    );

    $executor->process_notice_queue;

    my $count =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } )->count;
    is( $count, 1, 'pre-existing pending print blocks synthesis — still just one row' );

    $schema->storage->txn_rollback;
};

subtest 'process_notice_queue: existing print entry blocks fallback synthesis' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode => $library->branchcode,
                email      => q{},
                emailpro   => q{},
                B_email    => q{},
            }
        }
    );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD1',
                branchcode             => q{},
                message_transport_type => 'print',
                name                   => 'OD1 print',
                title                  => 'OD1',
                content                => 'print body',
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    my $item_payload = {
        borrowernumber    => $patron->borrowernumber,
        itemnumber        => $item->itemnumber,
        issue_id          => $issue->issue_id,
        patronhomebranch  => $library->branchcode,
        itemhomebranch    => $library->branchcode,
        itemholdingbranch => $library->branchcode,
    };

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'OD1', 'email', 7,
        [
            {
                item   => $item_payload,
                action => { type => 'notice', notice_code => 'OD1', mtt => 'email' },
                delay  => 7,
            },
        ],
    );
    $executor->add_to_notice_queue(
        $patron->borrowernumber, 'OD1', 'print', 7,
        [
            {
                item   => $item_payload,
                action => { type => 'notice', notice_code => 'OD1', mtt => 'print' },
                delay  => 7,
            },
        ],
    );

    $executor->process_notice_queue;

    my $messages =
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } );
    is( $messages->count,                        1,       'exactly one print row — explicit print blocks synthesis' );
    is( $messages->next->message_transport_type, 'print', 'the row is print, no email row' );

    $schema->storage->txn_rollback;
};

subtest 'process_notice_queue: processes print -> sms -> email order' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                branchcode     => $library->branchcode,
                email          => 'test@example.com',
                smsalertnumber => '0123456789',
            }
        }
    );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    for my $mtt (qw( email sms print )) {
        $builder->build(
            {
                source => 'Letter',
                value  => {
                    module                 => 'circulation',
                    code                   => 'OD1',
                    branchcode             => q{},
                    message_transport_type => $mtt,
                    name                   => "OD1 $mtt",
                    title                  => 'OD1',
                    content                => 'body',
                    is_html                => 0,
                    lang                   => 'default',
                },
            }
        );
    }

    my $item_payload = {
        borrowernumber    => $patron->borrowernumber,
        itemnumber        => $item->itemnumber,
        issue_id          => $issue->issue_id,
        patronhomebranch  => $library->branchcode,
        itemhomebranch    => $library->branchcode,
        itemholdingbranch => $library->branchcode,
    };

    my $executor = Koha::Overdues::ActionExecutor->new;

    # Add in email/sms/print order — passes should reorder enactment to print/sms/email.
    for my $mtt (qw( email sms print )) {
        $executor->add_to_notice_queue(
            $patron->borrowernumber, 'OD1', $mtt, 7,
            [
                {
                    item   => $item_payload,
                    action => { type => 'notice', notice_code => 'OD1', mtt => $mtt },
                    delay  => 7,
                },
            ],
        );
    }

    $executor->process_notice_queue;

    my @rows = Koha::Notice::Messages->search(
        { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' },
        { order_by       => 'message_id' }
    )->as_list;
    is( scalar @rows, 3, 'three rows enqueued' );
    is_deeply(
        [ map { $_->message_transport_type } @rows ],
        [ 'print', 'sms', 'email' ],
        'rows enqueued in print -> sms -> email order'
    );

    $schema->storage->txn_rollback;
};

subtest 'process_action_queue: enacts actions in a fixed order' => sub {
    plan tests => 1;

    my $mock = Test::MockModule->new('Koha::Overdues::ActionExecutor');

    my @order;
    for my $action (qw( enact_restrict enact_forgive_fine enact_lost enact_charge enact_mark_returned )) {
        $mock->mock( $action, sub { push @order, $action } );
    }

    my $executor = Koha::Overdues::ActionExecutor->new;

    # Insert the action keys in an order that differs from the enactment order
    # to prove the ordering comes from process_action_queue, not the hash.
    $executor->add_to_action_batch_queue(
        {
            item    => { borrowernumber => 1, itemnumber => 1 },
            delay   => 7,
            actions => { mark_returned => 1, charge => 1, lost => 2, forgive_fine => 1, restrict => 1 },
        }
    );

    $executor->process_action_queue;

    is_deeply(
        \@order,
        [qw( enact_restrict enact_forgive_fine enact_lost enact_charge enact_mark_returned )],
        'actions enacted in restrict -> forgive_fine -> lost -> charge -> mark_returned order'
    );
};

subtest 'process_notice_queue: re-run skips a notice already queued today' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode, email => 'patron@example.com' },
        }
    );
    my $item  = $builder->build_sample_item( { homebranch => $library->branchcode } );
    my $issue = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => { borrowernumber => $patron->borrowernumber, itemnumber => $item->itemnumber }
        }
    );

    $builder->build(
        {
            source => 'Letter',
            value  => {
                module                 => 'circulation',
                code                   => 'OD1',
                branchcode             => q{},
                message_transport_type => 'email',
                name                   => 'OD1 email',
                title                  => 'OD1',
                content                => 'body',
                is_html                => 0,
                lang                   => 'default',
            },
        }
    );

    my $notice_entry = {
        item => {
            borrowernumber    => $patron->borrowernumber,
            itemnumber        => $item->itemnumber,
            issue_id          => $issue->issue_id,
            patronhomebranch  => $library->branchcode,
            itemhomebranch    => $library->branchcode,
            itemholdingbranch => $library->branchcode,
        },
        action => { type => 'notice', notice_code => 'OD1', mtt => 'email' },
        delay  => 7,
    };

    # A notice already SENT to this patron today (queue drained by
    # SendQueuedMessages) must block a re-run from enqueuing a duplicate.
    Koha::Notice::Message->new(
        {
            borrowernumber         => $patron->borrowernumber,
            letter_code            => 'OD1',
            message_transport_type => 'email',
            status                 => 'sent',
            subject                => 'OD1',
            content                => 'already sent today',
            time_queued            => dt_from_string,
        }
    )->store;

    my $executor = Koha::Overdues::ActionExecutor->new;
    $executor->add_to_notice_queue( $patron->borrowernumber, 'OD1', 'email', 7, [$notice_entry] );
    $executor->process_notice_queue;

    is(
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } )->count,
        1, 'sent notice from today blocks re-enqueue — no duplicate row'
    );

    # The same notice queued on an earlier day must NOT block — a later overdue
    # episode still notifies (the same-day bound in _notice_exists).
    Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber } )
        ->update( { time_queued => dt_from_string->subtract( days => 1 ) } );

    my $next_run = Koha::Overdues::ActionExecutor->new;
    $next_run->add_to_notice_queue( $patron->borrowernumber, 'OD1', 'email', 7, [$notice_entry] );
    $next_run->process_notice_queue;

    is(
        Koha::Notice::Messages->search( { borrowernumber => $patron->borrowernumber, letter_code => 'OD1' } )->count,
        2, 'notice queued on an earlier day does not block — fresh episode enqueues'
    );

    $schema->storage->txn_rollback;
};
