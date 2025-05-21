#!/usr/bin/perl
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Test::More tests => 12;
use Test::Warn;
use t::lib::TestBuilder;
use t::lib::Mocks;
use Test::Mojo;

use Koha::Database;
use Koha::RestoreRecords;
use C4::Context;
use C4::Biblio qw( DelBiblio );

# Suppress DBIx::Class warnings about multiple rows
local $SIG{__WARN__} = sub {
    warn @_ unless $_[0] =~ /Query returned more than one row/;
};

BEGIN {
    use_ok('Koha::REST::V1::RestoreRecords');
}

# Mock RESTBasicAuth preference
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
my $dbh = C4::Context->dbh;

# Create test data
my $biblio = $builder->build_sample_biblio({
    title => 'Test Title',
    author => 'Test Author',
});

# Create biblioitem using build
my $biblioitem = $builder->build_object({
    class => 'Koha::Biblioitems',
    value => {
        biblionumber => $biblio->biblionumber,
        isbn => '1234567890',
        issn => '0987654321',
    }
});

# Verify biblioitem was created
ok($biblioitem, 'Biblioitem was created successfully');
ok($biblioitem->biblionumber == $biblio->biblionumber, 'Biblioitem has correct biblionumber');

my $item = $builder->build_sample_item({
    biblionumber => $biblio->biblionumber,
    barcode => '123456',
});

# Store IDs before deletion
my $biblioitemnumber = $biblioitem->biblioitemnumber;
my $itemnumber = $item->itemnumber;

# Mock userenv for safe_delete
t::lib::Mocks::mock_userenv({ branchcode => 'CPL', flags => 1, id => 1 });

# Delete the records in the correct order
ok($item->safe_delete(), 'Item was successfully deleted');
my $del_biblio_result = DelBiblio($biblio->biblionumber);
diag("DelBiblio result for biblionumber " . $biblio->biblionumber . ": " . ($del_biblio_result ? $del_biblio_result : 'undef'));
ok(!defined($del_biblio_result), 'Biblio was successfully deleted');

# Verify records exist in deleted tables
my $deleted_biblio_rs = $schema->resultset('Deletedbiblio')->search({ biblionumber => $biblio->biblionumber });
diag("Deletedbiblio rows for biblionumber " . $biblio->biblionumber . ":");
while (my $row = $deleted_biblio_rs->next) {
    diag("  - biblionumber: " . $row->biblionumber . ", title: " . $row->title);
}
my $deleted_biblio = $deleted_biblio_rs->reset->next;
ok($deleted_biblio, 'Deleted biblio exists');

my $deleted_biblioitem_rs = $schema->resultset('Deletedbiblioitem')->search({ biblioitemnumber => $biblioitemnumber });
diag("Deletedbiblioitem rows for biblioitemnumber $biblioitemnumber:");
while (my $row = $deleted_biblioitem_rs->next) {
    diag("  - biblioitemnumber: " . $row->biblioitemnumber . ", biblionumber: " . $row->biblionumber);
}
my $deleted_biblioitem = $deleted_biblioitem_rs->reset->next;
ok($deleted_biblioitem, 'Deleted biblioitem exists');

my $deleted_item_rs = $schema->resultset('Deleteditem')->search({ itemnumber => $itemnumber });
diag("Deleteditem rows for itemnumber $itemnumber:");
while (my $row = $deleted_item_rs->next) {
    diag("  - itemnumber: " . $row->itemnumber . ", biblionumber: " . $row->biblionumber . ", barcode: " . $row->barcode);
}
my $deleted_item = $deleted_item_rs->reset->next;
ok($deleted_item, 'Deleted item exists');

# Create a superlibrarian patron (with all permissions)
my $patron = $builder->build_object({
    class => 'Koha::Patrons',
    value => {
        flags => 1, # superlibrarian has all permissions
    }
});

# Set the password properly
my $password = 'thePassword123';
$patron->set_password({ password => $password, skip_validation => 1 });
my $userid = $patron->userid;

# Create a patron without permissions
my $patron_without_permissions = $builder->build_object({
    class => 'Koha::Patrons',
    value => {
        flags => 0,
    }
});
$patron_without_permissions->set_password({ password => $password, skip_validation => 1 });
my $unauthorized_userid = $patron_without_permissions->userid;

# Instantiate Test::Mojo for API testing
my $t = Test::Mojo->new('Koha::REST::V1');

# Test restore_biblio endpoint
subtest 'restore_biblio endpoint' => sub {
    plan tests => 23;

    # Test unauthorized access
    $t->post_ok('/api/v1/restore_records/biblio/' . $biblio->biblionumber)
      ->status_is(401);

    # Test forbidden access (authenticated but not authorized)
    $t->post_ok("//$unauthorized_userid:$password@/api/v1/restore_records/biblio/" . $biblio->biblionumber)
      ->status_is(403);

    # Store original biblio and biblioitem data for comparison
    my $deleted_biblio = $schema->resultset('Deletedbiblio')->find($biblio->biblionumber);
    my $deleted_biblioitem = $schema->resultset('Deletedbiblioitem')->find($biblioitemnumber);
    my $original_biblio_data = {
        title => $deleted_biblio->title,
        author => $deleted_biblio->author,
        copyrightdate => $deleted_biblio->copyrightdate,
        datecreated => $deleted_biblio->datecreated,
        frameworkcode => $deleted_biblio->frameworkcode
    };
    my $original_biblioitem_data = {
        isbn => $deleted_biblioitem->isbn,
        issn => $deleted_biblioitem->issn,
        publishercode => $deleted_biblioitem->publishercode,
        publicationyear => $deleted_biblioitem->publicationyear,
        pages => $deleted_biblioitem->pages,
        size => $deleted_biblioitem->size,
        place => $deleted_biblioitem->place
    };

    # Test successful restore
    my $res = $t->post_ok("//$userid:$password@/api/v1/restore_records/biblio/" . $biblio->biblionumber);
    $res->status_is(200)
      ->json_is('/success', 1);

    # Verify biblio was restored
    my $restored_biblio_rs = $schema->resultset('Biblio')->search({ biblionumber => $biblio->biblionumber });
    diag("Restored biblio rows for biblionumber " . $biblio->biblionumber . ":");
    while (my $row = $restored_biblio_rs->next) {
        diag("  - biblionumber: " . $row->biblionumber . ", title: " . $row->title);
    }
    my $restored_biblio = $restored_biblio_rs->reset->next;
    ok($restored_biblio, 'Biblio exists in biblio table after restore');

    # Verify all important biblio fields were restored correctly
    is($restored_biblio->title, $original_biblio_data->{title}, 'Biblio title restored correctly');
    is($restored_biblio->author, $original_biblio_data->{author}, 'Biblio author restored correctly');
    is($restored_biblio->copyrightdate, $original_biblio_data->{copyrightdate}, 'Biblio copyright date restored correctly');
    is($restored_biblio->datecreated, $original_biblio_data->{datecreated}, 'Biblio creation date restored correctly');
    is($restored_biblio->frameworkcode, $original_biblio_data->{frameworkcode}, 'Biblio framework code restored correctly');

    # Verify biblioitem was restored
    my $restored_biblioitem = $schema->resultset('Biblioitem')->find($biblioitemnumber);
    ok($restored_biblioitem, 'Biblioitem exists in biblioitem table after restore');

    # Verify all important biblioitem fields were restored correctly
    is($restored_biblioitem->isbn, $original_biblioitem_data->{isbn}, 'Biblioitem ISBN restored correctly');
    is($restored_biblioitem->issn, $original_biblioitem_data->{issn}, 'Biblioitem ISSN restored correctly');
    is($restored_biblioitem->publishercode, $original_biblioitem_data->{publishercode}, 'Biblioitem publisher code restored correctly');
    is($restored_biblioitem->publicationyear, $original_biblioitem_data->{publicationyear}, 'Biblioitem publication year restored correctly');
    is($restored_biblioitem->pages, $original_biblioitem_data->{pages}, 'Biblioitem pages restored correctly');
    is($restored_biblioitem->size, $original_biblioitem_data->{size}, 'Biblioitem size restored correctly');
    is($restored_biblioitem->place, $original_biblioitem_data->{place}, 'Biblioitem place restored correctly');

    # Verify records were removed from deleted tables
    my $deleted_biblio_after = $schema->resultset('Deletedbiblio')->find($biblio->biblionumber);
    my $deleted_biblioitem_after = $schema->resultset('Deletedbiblioitem')->find($biblioitemnumber);
    ok(!$deleted_biblio_after, 'Biblio removed from deleted biblio table after successful restore');
    ok(!$deleted_biblioitem_after, 'Biblioitem removed from deleted biblioitem table after successful restore');
};

# Create a separate item for testing the restore_item endpoint
my $item2 = $builder->build_sample_item({
    biblionumber => $biblio->biblionumber,
    barcode => '654321',
});

# Delete the item
ok($item2->safe_delete(), 'Second item was successfully deleted');

# Test restore_item endpoint
subtest 'restore_item endpoint' => sub {
    plan tests => 19;

    # Test unauthorized access
    $t->post_ok('/api/v1/restore_records/item/' . $item2->itemnumber)
      ->status_is(401);

    # Test forbidden access (authenticated but not authorized)
    $t->post_ok("//$unauthorized_userid:$password@/api/v1/restore_records/item/" . $item2->itemnumber)
      ->status_is(403);

    # Store original item data for comparison
    my $deleted_item = $schema->resultset('Deleteditem')->find($item2->itemnumber);
    my $original_data = {
        barcode => $deleted_item->barcode,
        homebranch => $deleted_item->homebranch,
        holdingbranch => $deleted_item->holdingbranch,
        biblionumber => $deleted_item->biblionumber,
        itemcallnumber => $deleted_item->itemcallnumber,
        location => $deleted_item->location,
        notforloan => $deleted_item->notforloan,
        damaged => $deleted_item->damaged,
        itemlost => $deleted_item->itemlost,
        withdrawn => $deleted_item->withdrawn
    };

    # Test successful restore
    my $res = $t->post_ok("//$userid:$password@/api/v1/restore_records/item/" . $item2->itemnumber);
    $res->status_is(200)
      ->json_is('/success', 1);

    # Verify item was restored
    my $restored_item_rs = $schema->resultset('Item')->search({ itemnumber => $item2->itemnumber });
    diag("Restored item rows for itemnumber " . $item2->itemnumber . ":");
    while (my $row = $restored_item_rs->next) {
        diag("  - itemnumber: " . $row->itemnumber . ", biblionumber: " . $row->biblionumber . ", barcode: " . $row->barcode);
    }
    my $restored_item = $restored_item_rs->reset->next;
    ok($restored_item, 'Item exists in items table after restore');

    # Verify all important fields were restored correctly
    is($restored_item->barcode, $original_data->{barcode}, 'Item barcode restored correctly');
    is($restored_item->homebranch->branchcode, $original_data->{homebranch}, 'Item homebranch restored correctly');
    is($restored_item->holdingbranch->branchcode, $original_data->{holdingbranch}, 'Item holdingbranch restored correctly');
    is($restored_item->biblionumber->biblionumber, $original_data->{biblionumber}, 'Item biblionumber restored correctly');
    is($restored_item->itemcallnumber, $original_data->{itemcallnumber}, 'Item call number restored correctly');
    is($restored_item->location, $original_data->{location}, 'Item location restored correctly');
    is($restored_item->notforloan, $original_data->{notforloan}, 'Item notforloan status restored correctly');
    is($restored_item->damaged, $original_data->{damaged}, 'Item damaged status restored correctly');
    is($restored_item->itemlost, $original_data->{itemlost}, 'Item lost status restored correctly');
    is($restored_item->withdrawn, $original_data->{withdrawn}, 'Item withdrawn status restored correctly');

    # Verify item was removed from deleted items table
    my $deleted_item_after = $schema->resultset('Deleteditem')->find($item2->itemnumber);
    ok(!$deleted_item_after, 'Item removed from deleted items table after successful restore');
};

# Test restoring item when biblio is deleted
subtest 'restore_item_with_deleted_biblio endpoint' => sub {
    plan tests => 6;

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
    my $res = $t->post_ok("//$userid:$password@/api/v1/restore_records/item/" . $item3->itemnumber);
    $res->status_is(409)
      ->json_like('/error', qr/associated bibliographic record does not exist/,
        'API returns 409 Conflict with appropriate error message');

    # Verify item is still in deleted items table
    my $deleted_item = $schema->resultset('Deleteditem')->find($item3->itemnumber);
    ok( $deleted_item, 'Item still exists in deleted items table after failed restore' );
};

# Clean up
$schema->storage->txn_rollback;