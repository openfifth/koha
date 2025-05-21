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
use Test::More tests => 7;
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
    plan tests => 4;

    my $restorer = Koha::RestoreRecords->new;
    my $deleted_biblio = $schema->resultset('Deletedbiblio')->find($biblionumber);
    ok( $deleted_biblio, 'Deleted biblio exists' );
    my $result = $restorer->restore_biblio($biblionumber);
    is( $result->{success}, 1, 'Biblio was successfully restored' );
    my $restored_biblio = Koha::Biblios->find($biblionumber);
    ok( $restored_biblio && $restored_biblio->title eq 'Test biblio for restoration',
        'Biblio was restored with correct title' );
    ok( !Koha::Items->find($itemnumber), 'Item was not automatically restored' );
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

# Test restoring item when biblio is deleted
subtest 'restore_item_with_deleted_biblio' => sub {
    plan tests => 5;

    # Create a new biblio and item
    my $biblio3 = $builder->build_sample_biblio({
        title  => 'Test biblio for deletion',
        author => 'Test Author'
    });

    my $item3 = $builder->build_sample_item({
        biblionumber => $biblio3->biblionumber,
        barcode      => 'RESTORE_TEST_789',
        homebranch   => 'CPL',
        holdingbranch => 'CPL'
    });

    # Delete both item and biblio
    $item3->safe_delete;
    C4::Biblio::DelBiblio($biblio3->biblionumber);

    # Verify both are deleted
    ok( !Koha::Biblios->find($biblio3->biblionumber), 'Biblio successfully deleted' );
    ok( !Koha::Items->find($item3->itemnumber), 'Item successfully deleted' );

    # Try to restore the item
    my $restorer = Koha::RestoreRecords->new;
    my $result = $restorer->restore_item($item3->itemnumber);
    is( $result->{success}, 0, 'Item restore should fail when biblio is deleted' );
    like( $result->{error}, qr/associated bibliographic record does not exist/, 
        'Error message indicates biblio does not exist' );

    # Verify item is still in deleted items table
    my $deleted_item = $schema->resultset('Deleteditem')->find($item3->itemnumber);
    ok( $deleted_item, 'Item still exists in deleted items table after failed restore' );
};

# Rollback the transaction
$schema->storage->txn_rollback;