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
use Test::More tests => 4;
use Test::Warn;
use t::lib::TestBuilder;
use t::lib::Mocks;
use Test::Mojo;

use Koha::Database;
use Koha::RestoreRecords;
use C4::Context;
use C4::Biblio qw( DelBiblio );

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
my $biblioitem = $builder->build({
    source => 'Biblioitem',
    value => {
        biblionumber => $biblio->biblionumber,
        isbn => '1234567890',
        issn => '0987654321',
    }
});

# Verify biblioitem was created
ok($biblioitem, 'Biblioitem was created successfully');
ok($biblioitem->{biblionumber} == $biblio->biblionumber, 'Biblioitem has correct biblionumber');

my $item = $builder->build_sample_item({
    biblionumber => $biblio->biblionumber,
    barcode => '123456',
});

# Mock userenv for safe_delete
t::lib::Mocks::mock_userenv({ branchcode => 'CPL', flags => 1, id => 1 });

# Delete the records in the correct order
ok($item->safe_delete(), 'Item was successfully deleted');
ok($biblioitem->delete(), 'Biblioitem was successfully deleted');
ok(DelBiblio($biblio->biblionumber), 'Biblio was successfully deleted');

# Verify records exist in deleted tables
my $deleted_biblio = $schema->resultset('Deletedbiblio')->find($biblio->biblionumber);
ok($deleted_biblio, 'Deleted biblio exists');

my $deleted_biblioitem = $schema->resultset('Deletedbiblioitem')->find($biblioitem->{biblioitemnumber});
ok($deleted_biblioitem, 'Deleted biblioitem exists');

my $deleted_item = $schema->resultset('Deleteditem')->find($item->itemnumber);
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
    plan tests => 8;

    # Test unauthorized access
    $t->post_ok('/api/v1/restore_records/biblio/' . $biblio->biblionumber)
      ->status_is(401);

    # Test forbidden access (authenticated but not authorized)
    $t->post_ok("//$unauthorized_userid:$password@/api/v1/restore_records/biblio/" . $biblio->biblionumber)
      ->status_is(403);

    # Test successful restore
    my $res = $t->post_ok("//$userid:$password@/api/v1/restore_records/biblio/" . $biblio->biblionumber);
    $res->status_is(200)
      ->json_is('/success', 1);

    # Verify biblio was restored
    my $restored_biblio = $schema->resultset('Biblio')->find($biblio->biblionumber);
    is($restored_biblio->title, $biblio->title, 'Biblio title restored correctly');
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
    plan tests => 8;

    # Test unauthorized access
    $t->post_ok('/api/v1/restore_records/item/' . $item2->itemnumber)
      ->status_is(401);

    # Test forbidden access (authenticated but not authorized)
    $t->post_ok("//$unauthorized_userid:$password@/api/v1/restore_records/item/" . $item2->itemnumber)
      ->status_is(403);

    # Test successful restore
    my $res = $t->post_ok("//$userid:$password@/api/v1/restore_records/item/" . $item2->itemnumber);
    $res->status_is(200)
      ->json_is('/success', 1);

    # Verify item was restored
    my $restored_item = $schema->resultset('Item')->find($item2->itemnumber);
    is($restored_item->barcode, $item2->barcode, 'Item barcode restored correctly');
};

# Clean up
$schema->storage->txn_rollback;