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
use Test::More tests => 11;

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

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
