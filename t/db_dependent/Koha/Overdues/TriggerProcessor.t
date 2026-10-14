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
use Test::MockModule;
use Test::More tests => 3;

use Koha::Checkouts::ReturnClaim;
use Koha::CirculationRules;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Overdues::TriggerProcessor;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

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

subtest 'process_overdues flags loans under an open return claim' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OverdueTriggersCalendar', 0 );
    t::lib::Mocks::mock_preference( 'CircControl',             'PatronLibrary' );

    Koha::CirculationRules->search( { rule_name => { -like => 'overdue\_%' } } )->delete;
    Koha::CirculationRules->set_rule(
        {
            branchcode   => undef,
            categorycode => undef,
            itemtype     => undef,
            rule_name    => 'overdue_1_delay',
            rule_value   => 7,
        }
    );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $staff = $builder->build_object( { class => 'Koha::Patrons' } );

    my $today = dt_from_string;
    my %checkout;
    for my $which (qw( open resolved none )) {
        my $item = $builder->build_sample_item( { homebranch => $library->branchcode } );
        $checkout{$which} = $builder->build_object(
            {
                class => 'Koha::Checkouts',
                value => {
                    borrowernumber => $patron->borrowernumber,
                    itemnumber     => $item->itemnumber,
                    branchcode     => $library->branchcode,
                    date_due       => $today->clone->subtract( days => 7 )->strftime('%Y-%m-%d %H:%M:%S'),
                },
            }
        );
    }

    for my $which (qw( open resolved )) {
        Koha::Checkouts::ReturnClaim->new(
            {
                issue_id       => $checkout{$which}->issue_id,
                itemnumber     => $checkout{$which}->itemnumber,
                borrowernumber => $patron->borrowernumber,
                created_by     => $staff->borrowernumber,
                resolved_on    => $which eq 'resolved' ? $today->strftime('%Y-%m-%d %H:%M:%S') : undef,
            }
        )->store;
    }

    my %open_return_claim_by_issue_id;
    my $executor_mock = Test::MockModule->new('Koha::Overdues::ActionExecutor');
    $executor_mock->mock(
        'route_item_actions_to_queue',
        sub {
            my ( $self, $effective_rule_sets, $overdue_item ) = @_;
            $open_return_claim_by_issue_id{ $overdue_item->{issue_id} } = $overdue_item->{open_return_claim};
        }
    );

    Koha::Overdues::TriggerProcessor->new->process_overdues;

    is( $open_return_claim_by_issue_id{ $checkout{open}->issue_id },     1, 'unresolved claim flags the loan' );
    is( $open_return_claim_by_issue_id{ $checkout{resolved}->issue_id }, 0, 'resolved claim does not' );
    is( $open_return_claim_by_issue_id{ $checkout{none}->issue_id },     0, 'unclaimed loan is not flagged' );

    $schema->storage->txn_rollback;
};
