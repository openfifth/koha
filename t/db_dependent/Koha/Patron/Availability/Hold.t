#!/usr/bin/perl

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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 14;

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use C4::Reserves qw( AddReserve );
use Koha::CirculationRules;
use Koha::Holds;
use Koha::HoldGroups;

BEGIN { use_ok('Koha::Patron::Availability::Hold'); }

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Eligible patron, no count context' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_preference( 'maxreserves', 0 );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( $result->available, 'Eligible patron passes without count context' );

    $schema->storage->txn_rollback;
};

subtest 'Expired patron' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { dateexpiry => '2000-01-01' } } );
    t::lib::Mocks::mock_preference( 'BlockExpiredPatronOpacActions', 'hold' );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( !$result->available,          'Expired patron blocked' );
    ok( $result->blockers->{expired}, 'Blocker is expired' );

    $schema->storage->txn_rollback;
};

subtest 'Debt limit' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_preference( 'maxoutstanding', 5 );

    $patron->account->add_debit( { amount => 10, type => 'MANUAL', interface => 'test' } );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( !$result->available,             'Patron with debt over limit blocked' );
    ok( $result->blockers->{debt_limit}, 'Blocker is debt_limit' );

    $schema->storage->txn_rollback;
};

subtest 'Bad address' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { gonenoaddress => 1 } } );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( !$result->available,              'Patron with bad address blocked' );
    ok( $result->blockers->{bad_address}, 'Blocker is bad_address' );

    $schema->storage->txn_rollback;
};

subtest 'Card lost' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { lost => 1 } } );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( !$result->available,            'Patron with lost card blocked' );
    ok( $result->blockers->{card_lost}, 'Blocker is card_lost' );

    $schema->storage->txn_rollback;
};

subtest 'Restricted' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { debarred => '9999-12-31' } } );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( !$result->available,             'Debarred patron blocked' );
    ok( $result->blockers->{restricted}, 'Blocker is restricted' );

    $schema->storage->txn_rollback;
};

subtest 'Global hold limit (maxreserves)' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_preference( 'maxreserves', 1 );

    $builder->build_object( { class => 'Koha::Holds', value => { borrowernumber => $patron->borrowernumber } } );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron } );
    ok( !$result->available,             'Patron at global hold limit blocked' );
    ok( $result->blockers->{hold_limit}, 'Blocker is hold_limit' );

    $schema->storage->txn_rollback;
};

subtest 'max_holds (per category)' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $item = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_preference( 'maxreserves',           0 );
    t::lib::Mocks::mock_preference( 'ReservesControlBranch', 'ItemHomeLibrary' );

    Koha::CirculationRules->set_rule(
        {
            categorycode => $patron->categorycode,
            branchcode   => $library->branchcode,
            rule_name    => 'max_holds',
            rule_value   => 1,
        }
    );

    $builder->build_object(
        {
            class => 'Koha::Holds',
            value => { borrowernumber => $patron->borrowernumber, biblionumber => $item->biblionumber }
        }
    );

    my $result = Koha::Patron::Availability::Hold->check(
        { patron => $patron, item_type_id => $item->effective_itemtype, library_id => $library->branchcode } );
    ok( !$result->available,                    'Patron at max_holds blocked' );
    ok( $result->blockers->{too_many_reserves}, 'Blocker is too_many_reserves' );

    $schema->storage->txn_rollback;
};

subtest 'no_short_circuit collects all blockers' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { gonenoaddress => 1, lost => 1 } } );

    my $result = Koha::Patron::Availability::Hold->check( { patron => $patron, no_short_circuit => 1 } );
    ok( !$result->available,              'Not available' );
    ok( $result->blockers->{bad_address}, 'bad_address collected' );
    ok( $result->blockers->{card_lost},   'card_lost collected' );

    $schema->storage->txn_rollback;
};

subtest 'Hold group counting in reservesallowed' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons',   value => { branchcode => $library->id } } );
    my @biblios = map { $builder->build_sample_biblio() } ( 1 .. 4 );
    my @items   = map { $builder->build_sample_item( { biblionumber => $_->id } ) } @biblios;

    Koha::CirculationRules->delete;
    Koha::CirculationRules->set_rules(
        {
            branchcode   => undef,
            categorycode => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 2, holds_per_record => 99, holds_per_day => 99 },
        }
    );

    # Place 2 holds and group them
    my $rid1 = C4::Reserves::AddReserve(
        { branchcode => $library->id, borrowernumber => $patron->id, biblionumber => $biblios[0]->id } );
    my $rid2 = C4::Reserves::AddReserve(
        { branchcode => $library->id, borrowernumber => $patron->id, biblionumber => $biblios[1]->id } );
    my $hg = $builder->build_object( { class => 'Koha::HoldGroups' } );
    Koha::Holds->find($rid1)->set( { hold_group_id => $hg->id } )->store;
    Koha::Holds->find($rid2)->set( { hold_group_id => $hg->id } )->store;

    # 2 grouped holds count as 1 — under limit of 2
    my $result = Koha::Patron::Availability::Hold->check(
        {
            patron    => $patron, library_id => $library->id, item_type_id => $items[2]->effective_itemtype,
            biblio_id => $biblios[2]->id
        }
    );
    ok( $result->available, 'Grouped holds count as 1, under limit' );

    # Add ungrouped hold — effective count = 2, at limit
    C4::Reserves::AddReserve(
        { branchcode => $library->id, borrowernumber => $patron->id, biblionumber => $biblios[2]->id } );
    $result = Koha::Patron::Availability::Hold->check(
        {
            patron    => $patron, library_id => $library->id, item_type_id => $items[3]->effective_itemtype,
            biblio_id => $biblios[3]->id
        }
    );
    ok( !$result->available,                    '1 group + 1 ungrouped = 2, at limit' );
    ok( $result->blockers->{too_many_reserves}, 'Blocker is too_many_reserves' );

    # Ungroup — 3 holds, over limit
    Koha::Holds->find($rid1)->set( { hold_group_id => undef } )->store;
    Koha::Holds->find($rid2)->set( { hold_group_id => undef } )->store;
    $result = Koha::Patron::Availability::Hold->check(
        {
            patron    => $patron, library_id => $library->id, item_type_id => $items[3]->effective_itemtype,
            biblio_id => $biblios[3]->id
        }
    );
    ok( !$result->available, '3 ungrouped holds over limit of 2' );

    $schema->storage->txn_rollback;
};

subtest 'reservesallowed filters by itemtype when rule is itemtype-specific' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons',   value => { branchcode => $library->id } } );

    my $itemtype_bk  = $builder->build_object( { class => 'Koha::ItemTypes' } );
    my $itemtype_dvd = $builder->build_object( { class => 'Koha::ItemTypes' } );

    t::lib::Mocks::mock_preference( 'maxreserves',           0 );
    t::lib::Mocks::mock_preference( 'ReservesControlBranch', 'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'item-level_itypes',     1 );

    Koha::CirculationRules->delete;

    # Per-itemtype rules: BK allows 2, DVD allows 1
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $library->id,
            categorycode => $patron->categorycode,
            itemtype     => $itemtype_bk->itemtype,
            rules        => { reservesallowed => 2, holds_per_record => 99, holds_per_day => 99 },
        }
    );
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $library->id,
            categorycode => $patron->categorycode,
            itemtype     => $itemtype_dvd->itemtype,
            rules        => { reservesallowed => 1, holds_per_record => 99, holds_per_day => 99 },
        }
    );

    # Create 2 BK items and 1 DVD item
    my $biblio_bk = $builder->build_sample_biblio();
    my $item_bk   = $builder->build_sample_item(
        { biblionumber => $biblio_bk->id, library => $library->id, itype => $itemtype_bk->itemtype } );
    my $biblio_bk2 = $builder->build_sample_biblio();
    my $item_bk2   = $builder->build_sample_item(
        { biblionumber => $biblio_bk2->id, library => $library->id, itype => $itemtype_bk->itemtype } );
    my $biblio_dvd = $builder->build_sample_biblio();
    my $item_dvd   = $builder->build_sample_item(
        { biblionumber => $biblio_dvd->id, library => $library->id, itype => $itemtype_dvd->itemtype } );

    # Place 1 hold on a BK item
    C4::Reserves::AddReserve(
        {
            branchcode     => $library->id,
            borrowernumber => $patron->id,
            biblionumber   => $biblio_bk->id,
            itemnumber     => $item_bk->id,
        }
    );

    # DVD hold should still be allowed (1 BK hold doesn't count against DVD limit of 1)
    my $result = Koha::Patron::Availability::Hold->check(
        {
            patron        => $patron,
            library_id    => $library->id,
            item_type_id  => $itemtype_dvd->itemtype,
            rule_itemtype => $itemtype_dvd->itemtype,
            biblio_id     => $biblio_dvd->id,
        }
    );
    ok( $result->available, 'DVD hold allowed: BK hold does not count against DVD limit' );

    # Second BK hold should be allowed (only 1 BK hold exists, limit is 2)
    $result = Koha::Patron::Availability::Hold->check(
        {
            patron        => $patron,
            library_id    => $library->id,
            item_type_id  => $itemtype_bk->itemtype,
            rule_itemtype => $itemtype_bk->itemtype,
            biblio_id     => $biblio_bk2->id,
        }
    );
    ok( $result->available, 'Second BK hold allowed: 1 of 2 used' );

    # Place second BK hold
    C4::Reserves::AddReserve(
        {
            branchcode     => $library->id,
            borrowernumber => $patron->id,
            biblionumber   => $biblio_bk2->id,
            itemnumber     => $item_bk2->id,
        }
    );

    # Third BK hold should be blocked (2 BK holds exist, limit is 2)
    my $biblio_bk3 = $builder->build_sample_biblio();
    $result = Koha::Patron::Availability::Hold->check(
        {
            patron        => $patron,
            library_id    => $library->id,
            item_type_id  => $itemtype_bk->itemtype,
            rule_itemtype => $itemtype_bk->itemtype,
            biblio_id     => $biblio_bk3->id,
        }
    );
    ok( !$result->available,                    'Third BK hold blocked: 2 of 2 used' );
    ok( $result->blockers->{too_many_reserves}, 'Blocker is too_many_reserves' );

    $schema->storage->txn_rollback;
};

subtest 'reservesallowed filters by branch when ReservesControlBranch is ItemHomeLibrary' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $library_a = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $library_b = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron    = $builder->build_object( { class => 'Koha::Patrons',   value => { branchcode => $library_a->id } } );

    t::lib::Mocks::mock_preference( 'maxreserves',           0 );
    t::lib::Mocks::mock_preference( 'ReservesControlBranch', 'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'item-level_itypes',     1 );

    Koha::CirculationRules->delete;

    # Rule at library_a: 1 hold allowed
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $library_a->id,
            categorycode => $patron->categorycode,
            itemtype     => undef,
            rules        => { reservesallowed => 1, holds_per_record => 99, holds_per_day => 99 },
        }
    );

    # Rule at library_b: 1 hold allowed
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $library_b->id,
            categorycode => $patron->categorycode,
            itemtype     => undef,
            rules        => { reservesallowed => 1, holds_per_record => 99, holds_per_day => 99 },
        }
    );

    # Create items at different branches
    my $biblio_a = $builder->build_sample_biblio();
    my $item_a   = $builder->build_sample_item( { biblionumber => $biblio_a->id, library => $library_a->id } );
    my $biblio_b = $builder->build_sample_biblio();
    my $item_b   = $builder->build_sample_item( { biblionumber => $biblio_b->id, library => $library_b->id } );

    # Place a hold on item at library_a
    C4::Reserves::AddReserve(
        {
            branchcode     => $library_a->id,
            borrowernumber => $patron->id,
            biblionumber   => $biblio_a->id,
            itemnumber     => $item_a->id,
        }
    );

    # Hold at library_b should be allowed (the existing hold is at library_a, doesn't count)
    my $result = Koha::Patron::Availability::Hold->check(
        {
            patron     => $patron,
            library_id => $library_b->id,
            biblio_id  => $biblio_b->id,
        }
    );
    ok( $result->available, 'Hold at library_b allowed: hold at library_a does not count' );

    # Second hold at library_a should be blocked
    my $biblio_a2 = $builder->build_sample_biblio();
    $builder->build_sample_item( { biblionumber => $biblio_a2->id, library => $library_a->id } );
    $result = Koha::Patron::Availability::Hold->check(
        {
            patron     => $patron,
            library_id => $library_a->id,
            biblio_id  => $biblio_a2->id,
        }
    );
    ok( !$result->available,                    'Second hold at library_a blocked: limit reached' );
    ok( $result->blockers->{too_many_reserves}, 'Blocker is too_many_reserves' );

    $schema->storage->txn_rollback;
};
