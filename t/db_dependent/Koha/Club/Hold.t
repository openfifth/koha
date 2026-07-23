#!/usr/bin/perl

# Copyright 2015 Koha Development team
#
# This file is part of Koha
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
use Test::More tests => 3;
use Test::Exception;
use Try::Tiny;

use Koha::Club::Hold;
use Koha::Club::Hold::PatronHolds;
use Koha::Holds;
use Koha::Database;
use Koha::DateUtils qw(dt_from_string);
use Scalar::Util    qw(blessed);

use t::lib::TestBuilder;

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->new->schema;

subtest 'add' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $club    = $builder->build_object( { class => 'Koha::Clubs' } );
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $item1   = $builder->build_sample_item( { library => $library->branchcode } );
    my $item2   = $builder->build_sample_item( { library => $library->branchcode } );

    throws_ok {
        Koha::Club::Hold::add( { club_id => $club->id } );
    }
    'Koha::Exceptions::MissingParameter',
        'Exception thrown when biblio_id is passed';

    like( "$@", qr/The biblio_id parameter is mandatory/ );

    throws_ok {
        Koha::Club::Hold::add( { biblio_id => $item1->biblionumber } );
    }
    'Koha::Exceptions::MissingParameter',
        'Exception thrown when club_id is passed';

    like( "$@", qr/The club_id parameter is mandatory/ );

    throws_ok {
        Koha::Club::Hold::add(
            {
                club_id           => $club->id,
                biblio_id         => $item1->biblionumber,
                pickup_library_id => $library->branchcode
            }
        );
    }
    'Koha::Exceptions::ClubHold::NoPatrons',
        'Exception thrown when no patron is enrolled in club';

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { branchcode => $library->branchcode }
        }
    );
    my $e = $builder->build_object(
        {
            class => 'Koha::Club::Enrollments',
            value => {
                club_id        => $club->id,
                borrowernumber => $patron->borrowernumber,
                date_canceled  => undef
            }
        }
    );

    my $club_hold = Koha::Club::Hold::add(
        {
            club_id           => $club->id,
            biblio_id         => $item1->biblionumber,
            pickup_library_id => $library->branchcode
        }
    );

    is( blessed($club_hold), 'Koha::Club::Hold', 'add returns a Koha::Club::Hold' );

    $e->date_canceled(dt_from_string)->store;

    throws_ok {
        Koha::Club::Hold::add(
            {
                club_id           => $club->id,
                biblio_id         => $item2->biblionumber,
                pickup_library_id => $library->branchcode
            }
        );
    }
    'Koha::Exceptions::ClubHold::NoPatrons',
        'Exception thrown when no patron is enrolled in club';

    my $patron_holds = Koha::Club::Hold::PatronHolds->search( { club_hold_id => $club_hold->id } );

    ok( $patron_holds->count, "There must be at least one patron_hold" );

    my $patron_hold = $patron_holds->next;

    my $hold = Koha::Holds->find( $patron_hold->hold_id );

    is( $patron_hold->patron_id, $hold->borrowernumber, 'Patron must be the same' );

    $schema->storage->txn_rollback;
};

subtest 'add reuses the item fetch across club members (bug 43124)' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $count_item_table_queries = sub {
        my ($n_members) = @_;

        my $club    = $builder->build_object( { class => 'Koha::Clubs' } );
        my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
        my $item    = $builder->build_sample_item( { library => $library->branchcode } );

        for ( 1 .. $n_members ) {
            my $patron =
                $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
            $builder->build_object(
                {
                    class => 'Koha::Club::Enrollments',
                    value => {
                        club_id        => $club->id,
                        borrowernumber => $patron->borrowernumber,
                        date_canceled  => undef
                    }
                }
            );
        }

        my $trace = q{};
        open my $fh, '>', \$trace or die $!;
        $schema->storage->debugfh($fh);
        $schema->storage->debug(1);

        Koha::Club::Hold::add(
            {
                club_id           => $club->id,
                biblio_id         => $item->biblionumber,
                pickup_library_id => $library->branchcode,
            }
        );

        $schema->storage->debug(0);

        # Match only the plain "all items of this biblio" query that
        # fetch_items/check issue (WHERE `me`.`biblionumber` = ? with no
        # other predicate) - other per-patron item lookups elsewhere in
        # AddReserve (e.g. filtered by notforloan) are out of this bug's
        # scope and would otherwise make this assertion too strict.
        return scalar( () = $trace =~ /FROM `items` `me` WHERE \( `me`\.`biblionumber` = \? \):/g );
    };

    my $queries_2 = $count_item_table_queries->(2);
    my $queries_8 = $count_item_table_queries->(8);

    # Without batching, each extra member adds its own item-list fetch: 6
    # extra members would add 6 extra `items` queries. A small delta proves
    # the fetch is shared rather than repeated per member.
    cmp_ok( $queries_8 - $queries_2, '<', 3, 'Item-table query count does not scale with club member count' );

    $schema->storage->txn_rollback;
};
