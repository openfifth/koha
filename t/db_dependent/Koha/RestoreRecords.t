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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::More tests => 6;
use Test::Warn;
use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Biblios;
use Koha::Items;
use Koha::Old::Items;
use Koha::Old::Biblios;
use Koha::RestoreRecords;
use C4::Biblio;  # We need this for DelBiblio

# Load the module first
BEGIN {
    use_ok('Koha::RestoreRecords');
}

# Start a transaction
my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

# --- BIBLIO RESTORE TEST ---
# Create test data
my $biblio = $builder->build_sample_biblio({
    title  => 'Test biblio for restoration',
    author => 'Test Author'
});

my $item = $builder->build_sample_item({
    biblionumber => $biblio->biblionumber,
    barcode      => 'RESTORE_TEST_123',
    homebranch   => 'CPL',
    holdingbranch => 'CPL'
});

# Store the important IDs
my $biblionumber = $biblio->biblionumber;
my $itemnumber = $item->itemnumber;

# Delete the item first, then the biblio
$item->safe_delete;
C4::Biblio::DelBiblio($biblionumber);

# Verify the records are gone from the original tables
ok( !Koha::Biblios->find($biblionumber), 'Biblio successfully deleted' );
ok( !Koha::Items->find($itemnumber), 'Item successfully deleted' );

# Test restore_biblio
subtest 'restore_biblio' => sub {
    plan tests => 3;

    my $restorer = Koha::RestoreRecords->new;
    my $deleted_biblio = $schema->resultset('Deletedbiblio')->find($biblionumber);
    ok( $deleted_biblio, 'Deleted biblio exists' );
    my $result = $restorer->restore_biblio($biblionumber);
    is( $result->{success}, 1, 'Biblio was successfully restored' );
    my $restored_biblio = Koha::Biblios->find($biblionumber);
    ok( $restored_biblio && $restored_biblio->title eq 'Test biblio for restoration',
        'Biblio was restored with correct title' );
};

# --- ITEM RESTORE TEST ---
# Create a new biblio and item for the item restore test
my $biblio2 = $builder->build_sample_biblio({
    title  => 'Another test biblio',
    author => 'Test Author'
});

my $item2 = $builder->build_sample_item({
    biblionumber => $biblio2->biblionumber,
    barcode      => 'RESTORE_TEST_456',
    homebranch   => 'CPL',
    holdingbranch => 'CPL'
});

my $biblionumber2 = $biblio2->biblionumber;
my $itemnumber2 = $item2->itemnumber;

# Delete just the item (biblio remains)
$item2->safe_delete;

# Verify the item is gone from items table
ok( !Koha::Items->find($itemnumber2), 'Item successfully deleted' );

# Test restore_item
subtest 'restore_item' => sub {
    plan tests => 3;

    my $restorer = Koha::RestoreRecords->new;
    my $deleted_item = $schema->resultset('Deleteditem')->find($itemnumber2);
    ok( $deleted_item, 'Deleted item exists' );
    my $result = $restorer->restore_item($itemnumber2);
    is( $result->{success}, 1, 'Item was successfully restored' );
    my $restored_item = Koha::Items->find($itemnumber2);
    ok( $restored_item && $restored_item->barcode eq 'RESTORE_TEST_456',
        'Item was restored with correct barcode' );
};

# Rollback the transaction
$schema->storage->txn_rollback;