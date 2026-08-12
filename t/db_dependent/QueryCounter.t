#!/usr/bin/env perl

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

use Test::More tests => 4;
use Test::NoWarnings;

use t::lib::QueryCounter;
use t::lib::TestBuilder;

use C4::Context;
use Koha::Database;
use Koha::Patrons;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'measure() reports the query count, the time and the trace' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my ( $result, $stats ) = t::lib::QueryCounter->measure(
        sub {
            return Koha::Patrons->find( $patron->borrowernumber );
        }
    );

    is( $result->borrowernumber, $patron->borrowernumber, 'The first return value of the block comes back' );
    is( $stats->{queries},       1,                       'A single find() counts as one query' );
    ok( $stats->{elapsed_ms} >= 0, 'The elapsed time is set' );
    like( $stats->{trace}, qr/^SELECT/m, 'The raw trace is available to the caller' );

    my ( undef, $empty_stats ) = t::lib::QueryCounter->measure( sub { return 'no queries here' } );

    is( $empty_stats->{queries}, 0, 'A block that issues no query counts as zero queries' );

    $schema->storage->txn_rollback;
};

subtest 'measure() also counts SQL issued through the raw DBI handle' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my ( undef, $stats ) = t::lib::QueryCounter->measure(
        sub {
            my ($count) = C4::Context->dbh->selectrow_array(
                'SELECT COUNT(*) FROM borrowers WHERE borrowernumber = ?',
                undef, $patron->borrowernumber
            );
            return $count;
        }
    );

    is( $stats->{queries}, 1, 'A raw dbh->selectrow_array() call is counted too' );
    like(
        $stats->{trace}, qr/^SELECT COUNT\(\*\) FROM borrowers/m,
        'Its SQL appears in the trace, normalised onto one line'
    );

    my ( undef, $mixed_stats ) = t::lib::QueryCounter->measure(
        sub {
            Koha::Patrons->find( $patron->borrowernumber );    # a DBIx::Class query
            C4::Context->dbh->do('SELECT 1');                  # a raw DBI query
        }
    );

    is( $mixed_stats->{queries}, 2, 'A DBIx::Class query and a raw DBI query in the same block both count' );

    $schema->storage->txn_rollback;
};

subtest 'measure() restores the trace settings' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    my $debug_before     = $schema->storage->debug;
    my $debugobj_before  = $schema->storage->debugobj;
    my $callbacks_before = $schema->storage->dbh->{Callbacks};

    t::lib::QueryCounter->measure( sub { return Koha::Patrons->search( {} )->count } );

    is( $schema->storage->debug,        $debug_before,     'The debug flag is restored' );
    is( $schema->storage->debugobj,     $debugobj_before,  'The statistics object is restored' );
    is( $schema->storage->dbh->{Callbacks}, $callbacks_before, 'The DBI callbacks are restored' );

    # A block that throws must not leave the trace on.
    my $error;
    unless (
        eval {
            t::lib::QueryCounter->measure( sub { die "the block failed\n" } );
            1;
        }
        )
    {
        $error = $@;
    }

    is( $error,                     "the block failed\n", 'The exception from the block is rethrown' );
    is( $schema->storage->debug,    $debug_before,        'The debug flag is restored after an exception' );
    is( $schema->storage->debugobj, $debugobj_before,     'The statistics object is restored after an exception' );
    is(
        $schema->storage->dbh->{Callbacks}, $callbacks_before,
        'The DBI callbacks are restored after an exception'
    );

    $schema->storage->txn_rollback;
};
