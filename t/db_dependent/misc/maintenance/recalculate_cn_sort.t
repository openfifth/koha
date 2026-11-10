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

use Test::More tests => 10;
use Test::NoWarnings;

use FindBin qw($Bin);

use Koha::ClassSources;
use Koha::Items;

use t::lib::TestBuilder;

# The script runs in its own process, so nothing here can be rolled back:
# build, run and clean up explicitly.
my $builder = t::lib::TestBuilder->new;
my $script  = "$Bin/../../../../misc/maintenance/recalculate_cn_sort.pl";

my $source_code = 'TSTLCC';
my $other_code  = 'TSTGEN';
Koha::ClassSources->search( { cn_source => [ $source_code, $other_code ] } )->delete;
Koha::ClassSource->new(
    { cn_source => $source_code, description => 'Test LCC', class_sort_rule => 'lcc', class_split_rule => 'generic' } )
    ->store;
Koha::ClassSource->new(
    {
        cn_source        => $other_code, description => 'Test generic', class_sort_rule => 'generic',
        class_split_rule => 'generic'
    }
)->store;

my $library = $builder->build_object( { class => 'Koha::Libraries' } );
my $biblio  = $builder->build_sample_biblio;

my @items = map {
    $builder->build_sample_item(
        {
            biblionumber   => $biblio->biblionumber,
            library        => $library->branchcode,
            itemcallnumber => $_,
            cn_source      => $source_code,
        }
    )
} ( 'QA 4', 'QA 90', 'QA 100' );

my $generic_item = $builder->build_sample_item(
    {
        biblionumber   => $biblio->biblionumber,
        library        => $library->branchcode,
        itemcallnumber => 'QA 90',
        cn_source      => $other_code,
    }
);

my @itemnumbers = map { $_->itemnumber } ( @items, $generic_item );
my $where       = 'itemnumber IN (' . join( ',', @itemnumbers ) . ')';

my @expected        = map { $_->cn_sort } @items;
my $generic_cn_sort = $generic_item->cn_sort;
is( $generic_cn_sort, 'QA_90', 'Generic rule gives an unpadded key' );
isnt( $expected[1], 'QA_90', 'LCC rule gives a padded key' );

# Simulate items created before the filing rule changed
Koha::Items->search( { itemnumber => \@itemnumbers } )->update( { cn_sort => 'QA_STALE' } );

sub run_script {
    my @args = @_;
    return scalar `$^X $script @args 2>&1`;
}

sub cn_sort_of {
    my $item = shift;
    return Koha::Items->find( $item->itemnumber )->cn_sort;
}

my $output = run_script( '--dry-run', '--skip-indexing', "--where '$where'" );
like( $output, qr/Dry run/,    'Dry run says so' );
like( $output, qr/changed: 4/, 'Dry run reports the stale items' );
is( cn_sort_of( $items[1] ), 'QA_STALE', 'Dry run does not modify cn_sort' );

$output = run_script( '--confirm', '--skip-indexing', "--cn_source $source_code", "--where '$where'" );
is_deeply(
    [ map { cn_sort_of($_) } @items ], \@expected,
    'Items of the selected source are recalculated with the current rule'
);
is( cn_sort_of($generic_item), 'QA_STALE', 'Items of other sources are left alone' );

$output = run_script( '--confirm', '--skip-indexing', "--where '$where'" );
is( cn_sort_of($generic_item), $generic_cn_sort, 'Without --cn_source every matching item is recalculated' );

$output = run_script( '--confirm', '--skip-indexing', "--where '$where'" );
like( $output, qr/changed: 0/, 'A second run has nothing to change' );

# Clean up
Koha::Items->search( { itemnumber => \@itemnumbers } )->delete;
$biblio->delete;
Koha::ClassSources->search( { cn_source => [ $source_code, $other_code ] } )->delete;
$library->delete;
