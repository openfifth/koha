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
use Test::More tests => 3;
use Test::MockModule;

use C4::Context;
use Koha::Database;
use Koha::Item::BiblioLink;

use t::lib::TestBuilder;
use t::lib::Mocks;

BEGIN {
    use_ok('Koha::UI::Table::Builder::Items');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'build_table() bound_with tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 1 );
    t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue',   0 );

    # Storing a link reindexes the records involved
    my $engine       = C4::Context->preference('SearchEngine') // 'Zebra';
    my $indexer_mock = Test::MockModule->new("Koha::SearchEngine::${engine}::Indexer");
    $indexer_mock->mock( 'index_records', sub { } );

    my $native_biblio = $builder->build_sample_biblio();
    my $bound_item    = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );
    my $plain_item    = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );

    my $second_biblio   = $builder->build_sample_biblio( { title => 'Second bound record' } );
    my $first_biblio    = $builder->build_sample_biblio( { title => 'First bound record' } );
    my $analytic_biblio = $builder->build_sample_biblio( { title => 'Analytic record' } );

    # Links stored out of display order, and one that is not a binding link
    Koha::Item::BiblioLink->new(
        {
            itemnumber    => $bound_item->itemnumber,
            biblionumber  => $second_biblio->biblionumber,
            link_type     => 'binding',
            display_order => 2,
        }
    )->store;
    Koha::Item::BiblioLink->new(
        {
            itemnumber    => $bound_item->itemnumber,
            biblionumber  => $first_biblio->biblionumber,
            link_type     => 'binding',
            display_order => 1,
        }
    )->store;
    Koha::Item::BiblioLink->new(
        {
            itemnumber   => $bound_item->itemnumber,
            biblionumber => $analytic_biblio->biblionumber,
            link_type    => 'analytic',
        }
    )->store;

    my $itemnumbers = [ $bound_item->itemnumber, $plain_item->itemnumber ];

    my $table = Koha::UI::Table::Builder::Items->new( { itemnumbers => $itemnumbers } )->build_table;
    my %rows  = map { $_->{itemnumber} => $_ } @{ $table->{items} };

    is( scalar @{ $table->{items} }, 2, 'One row per item' );

    my $bound_row = $rows{ $bound_item->itemnumber };
    is( ref( $bound_row->{bound_with} ),      'ARRAY', 'bound_with is an arrayref' );
    is( scalar @{ $bound_row->{bound_with} }, 2,       'Only binding links are listed' );
    is(
        ref( $bound_row->{bound_with}->[0] ), 'Koha::Biblio',
        'bound_with holds Koha::Biblio objects'
    );
    is(
        $bound_row->{bound_with}->[0]->biblionumber, $first_biblio->biblionumber,
        'Bound records are ordered by display_order (first)'
    );
    is(
        $bound_row->{bound_with}->[1]->biblionumber, $second_biblio->biblionumber,
        'Bound records are ordered by display_order (second)'
    );

    my $plain_row = $rows{ $plain_item->itemnumber };
    is_deeply( $plain_row->{bound_with}, [], 'An item without links has an empty bound_with' );

    ok(
        !( grep { $_->{attribute} && $_->{attribute} eq 'bound_with' } @{ $table->{headers} } ),
        'bound_with does not become a framework column'
    );

    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 0 );

    $table = Koha::UI::Table::Builder::Items->new( { itemnumbers => $itemnumbers } )->build_table;
    %rows  = map { $_->{itemnumber} => $_ } @{ $table->{items} };

    is_deeply(
        $rows{ $bound_item->itemnumber }->{bound_with}, [],
        'bound_with is empty when EnableBoundWithItems is off, even with links'
    );
    is_deeply(
        $rows{ $plain_item->itemnumber }->{bound_with}, [],
        'bound_with is empty for an unlinked item when the preference is off'
    );
    is( scalar @{ $table->{items} }, 2, 'Rows are still built when the preference is off' );

    $schema->storage->txn_rollback;
};
