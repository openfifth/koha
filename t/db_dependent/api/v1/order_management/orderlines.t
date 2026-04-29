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

use Test::NoWarnings;
use Test::More tests => 12;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::Finances::Funds;
use Koha::Acquisition::OrderManagement::OrderlineFundDistributions;
use Koha::Acquisition::OrderManagement::OrderlineItem;
use Koha::Acquisition::OrderManagement::OrderlineItems;
use Koha::Acquisition::OrderManagement::OrderlineManager;
use Koha::Acquisition::OrderManagement::OrderlineManagers;
use Koha::Acquisition::OrderManagement::Orderlines;
use Koha::Acquisition::OrderManagement::OrderlineUser;
use Koha::Acquisition::OrderManagement::OrderlineUsers;
use Koha::AdditionalFields;
use Koha::Biblios;
use Koha::Database;
use Koha::Items;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    Koha::Acquisition::OrderManagement::Orderlines->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # No orderlines, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/orderlines")->status_is(200)->json_is( [] );

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, status => 'draft', payment_status => 'pending' }
        }
    );

    # One orderline created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/orderlines")
        ->status_is(200)
        ->json_is( [ $orderline->to_api ] );

    my $orderline_2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 2, status => 'draft', payment_status => 'pending' }
        }
    );

    # Two orderlines, both should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/orderlines")
        ->status_is(200)
        ->json_is( [ $orderline->to_api, $orderline_2->to_api ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/orderlines")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, status => 'draft', payment_status => 'pending' }
        }
    );

    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/orderlines/" . $orderline->orderline_id )
        ->status_is(200)
        ->json_is( $orderline->to_api );

    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/orderlines/" . $orderline->orderline_id )
        ->status_is(403);

    my $orderline_to_delete = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, status => 'draft', payment_status => 'pending' }
        }
    );
    my $non_existent_id = $orderline_to_delete->orderline_id;
    $orderline_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/orderlines/$non_existent_id")
        ->status_is(404)
        ->json_is( '/error' => 'Orderline not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $biblio = $builder->build_object( { class => 'Koha::Biblios' } );

    my $orderline = {
        quantity_ordered => 1,
        biblionumber     => $biblio->biblionumber,
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )->status_is(403);

    # Authorized attempt - no vendor_id means status should be set to 'draft'
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )
        ->status_is( 201, 'REST3.2.1' )
        ->header_like( Location => qr|^\/api\/v1\/acquisitions\/orderlines\/\d+|, 'REST3.4.1' )
        ->json_is( '/quantity_ordered' => $orderline->{quantity_ordered} )
        ->json_is( '/status'           => 'draft' );

    # With vendor_id but no fund distributions, status should still be 'draft'
    my $vendor                = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $biblio_2              = $builder->build_object( { class => 'Koha::Biblios' } );
    my $orderline_with_vendor = {
        quantity_ordered => 2,
        biblionumber     => $biblio_2->biblionumber,
        vendor_id        => $vendor->id,
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline_with_vendor )
        ->status_is(201)
        ->json_is( '/status' => 'draft' );

    # With vendor_id AND a fund distribution, status should be set to 'new'
    my $fund                           = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    my $orderline_with_vendor_and_fund = {
        quantity_ordered   => 2,
        biblionumber       => $biblio_2->biblionumber,
        vendor_id          => $vendor->id,
        fund_distributions => [
            {
                fund_id                         => $fund->fund_id,
                percentage                      => 100,
                distributed_amount_oc           => 0,
                exchange_rate                   => 1,
                distributed_amount              => 0,
                tax_rate                        => 0,
                tax_value                       => 0,
                distributed_amount_tax_excluded => 0,
                distributed_amount_tax_included => 0,
            }
        ],
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline_with_vendor_and_fund )
        ->status_is(201)
        ->json_is( '/status' => 'new' );

    $schema->storage->txn_rollback;
};

subtest 'add() with fund_distributions tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $biblio = $builder->build_object( { class => 'Koha::Biblios' } );
    my $fund   = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );

    my $orderline = {
        quantity_ordered   => 1,
        biblionumber       => $biblio->biblionumber,
        fund_distributions => [
            {
                fund_id                         => $fund->fund_id,
                percentage                      => 100,
                distributed_amount_oc           => 0,
                exchange_rate                   => 1,
                distributed_amount              => 0,
                tax_rate                        => 0,
                tax_value                       => 0,
                distributed_amount_tax_excluded => 0,
                distributed_amount_tax_included => 0,
            }
        ],
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )->status_is(201);

    my $orderline_id = $t->tx->res->json->{orderline_id};
    my $distributions =
        Koha::Acquisition::OrderManagement::OrderlineFundDistributions->search( { orderline_id => $orderline_id } );

    is( $distributions->count,         1,              'One fund distribution was created' );
    is( $distributions->next->fund_id, $fund->fund_id, 'Distribution linked to correct fund' );

    $schema->storage->txn_rollback;
};

subtest 'add() with patrons_to_notify tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $biblio = $builder->build_object( { class => 'Koha::Biblios' } );
    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $orderline = {
        quantity_ordered  => 1,
        biblionumber      => $biblio->biblionumber,
        patrons_to_notify => [ { borrowernumber => $patron->borrowernumber } ],
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )->status_is(201);

    my $orderline_id = $t->tx->res->json->{orderline_id};
    my $users        = Koha::Acquisition::OrderManagement::OrderlineUsers->search( { orderline_id => $orderline_id } );

    is( $users->count,                1,                       'One patron_to_notify relationship created' );
    is( $users->next->borrowernumber, $patron->borrowernumber, 'Correct patron linked' );

    $schema->storage->txn_rollback;
};

subtest 'add() with managed_by tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $biblio  = $builder->build_object( { class => 'Koha::Biblios' } );
    my $manager = $builder->build_object( { class => 'Koha::Patrons' } );

    my $orderline = {
        quantity_ordered => 1,
        biblionumber     => $biblio->biblionumber,
        managed_by       => [ { borrowernumber => $manager->borrowernumber } ],
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )->status_is(201);

    my $orderline_id = $t->tx->res->json->{orderline_id};
    my $managers = Koha::Acquisition::OrderManagement::OrderlineManagers->search( { orderline_id => $orderline_id } );

    is( $managers->count,                1,                        'One managed_by relationship created' );
    is( $managers->next->borrowernumber, $manager->borrowernumber, 'Correct manager linked' );

    $schema->storage->txn_rollback;
};

subtest 'add() with biblio creation tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    # No biblionumber supplied — controller creates a new biblio from biblio data
    my $orderline = {
        quantity_ordered => 1,
        biblio           => { title => 'Test Title', author => 'Test Author' },
    };

    $t->post_ok(
        "//$userid:$password@/api/v1/acquisitions/orderlines" => { 'x-confirm-not-duplicate' => '1' } => json =>
            $orderline )->status_is(201);

    my $biblionumber = $t->tx->res->json->{biblionumber};
    ok( $biblionumber, 'biblionumber was set after biblio creation' );
    my $created_biblio = Koha::Biblios->find($biblionumber);
    ok( $created_biblio, 'Biblio record exists in database' );
    is( $created_biblio->title,  'Test Title',  'Biblio has correct title' );
    is( $created_biblio->author, 'Test Author', 'Biblio has correct author' );

    $schema->storage->txn_rollback;
};

subtest 'add() with items tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $biblio = $builder->build_sample_biblio;
    my $branch = $builder->build_object( { class => 'Koha::Libraries' } );

    my $orderline = {
        quantity_ordered => 1,
        biblionumber     => $biblio->biblionumber,
        items            => [
            {
                home_library_id    => $branch->branchcode,
                holding_library_id => $branch->branchcode,
            }
        ],
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )->status_is(201);

    my $created_id        = $t->tx->res->json->{orderline_id};
    my $created_orderline = Koha::Acquisition::OrderManagement::Orderlines->find($created_id);

    is( $created_orderline->items->count, 1, 'One item linked to orderline' );
    is(
        $created_orderline->items->next->biblionumber,
        $biblio->biblionumber,
        'Item linked to correct biblio'
    );

    $schema->storage->txn_rollback;
};

subtest 'add() with extended_attributes tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $biblio = $builder->build_object( { class => 'Koha::Biblios' } );
    my $field  = $builder->build_object(
        {
            class => 'Koha::AdditionalFields',
            value => { tablename => 'acq_orderlines', marcfield => '' }
        }
    );

    my $orderline = {
        quantity_ordered    => 1,
        biblionumber        => $biblio->biblionumber,
        extended_attributes => [ { field_id => $field->id, value => 'test_value' } ],
    };

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/orderlines" => json => $orderline )->status_is(201);

    my $created_id        = $t->tx->res->json->{orderline_id};
    my $created_orderline = Koha::Acquisition::OrderManagement::Orderlines->find($created_id);
    my $attrs             = $created_orderline->extended_attributes;

    is( $attrs->count,       1,            'One extended attribute created' );
    is( $attrs->next->value, 'test_value', 'Extended attribute has correct value' );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $biblio    = $builder->build_object( { class => 'Koha::Biblios' } );
    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => {
                quantity_ordered => 1,
                status           => 'draft',
                payment_status   => 'pending',
                biblionumber     => $biblio->biblionumber,
            }
        }
    );
    my $orderline_id = $orderline->orderline_id;

    my $updated_orderline = {
        quantity_ordered => 5,
    };

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/acquisitions/orderlines/$orderline_id" => json => $updated_orderline )
        ->status_is(403);

    # Authorized update
    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/orderlines/$orderline_id" => json => $updated_orderline )
        ->status_is(200)
        ->json_is( '/quantity_ordered' => 5 );

    my $orderline_to_delete = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1, status => 'draft', payment_status => 'pending' }
        }
    );
    my $non_existent_id = $orderline_to_delete->orderline_id;
    $orderline_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/orderlines/$non_existent_id" => json => $updated_orderline )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $fund           = $builder->build_object( { class => 'Koha::Acquisition::Finances::Funds' } );
    my $notify_patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $manager_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $biblio         = $builder->build_object( { class => 'Koha::Biblios' } );
    my $item = $builder->build_object( { class => 'Koha::Items', value => { biblionumber => $biblio->biblionumber } } );

    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => {
                quantity_ordered => 1, status => 'draft', payment_status => 'pending',
                biblionumber     => $biblio->biblionumber
            }
        }
    );
    my $orderline_id = $orderline->orderline_id;

    $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::OrderlineFundDistributions',
            value => { orderline_id => $orderline_id, fund_id => $fund->fund_id }
        }
    );
    Koha::Acquisition::OrderManagement::OrderlineUser->new(
        { orderline_id => $orderline_id, borrowernumber => $notify_patron->borrowernumber } )->store;
    Koha::Acquisition::OrderManagement::OrderlineManager->new(
        { orderline_id => $orderline_id, borrowernumber => $manager_patron->borrowernumber } )->store;
    Koha::Acquisition::OrderManagement::OrderlineItem->new(
        { orderline_id => $orderline_id, itemnumber => $item->itemnumber } )->store;

    is(
        Koha::Acquisition::OrderManagement::OrderlineUsers->search( { orderline_id => $orderline_id } )->count, 1,
        'One patron_to_notify exists before deletion'
    );
    is(
        Koha::Acquisition::OrderManagement::OrderlineManagers->search( { orderline_id => $orderline_id } )->count, 1,
        'One manager exists before deletion'
    );
    is( Koha::Acquisition::OrderManagement::OrderlineFundDistributions->search( { orderline_id => $orderline_id } )
            ->count, 1, 'One fund distribution exists before deletion' );
    is(
        Koha::Acquisition::OrderManagement::OrderlineItems->search( { orderline_id => $orderline_id } )->count, 1,
        'One item link exists before deletion'
    );

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/orderlines/$orderline_id")->status_is(403);

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/orderlines/$orderline_id")
        ->status_is( 204, 'REST3.2.4' )
        ->content_is( '', 'REST3.3.4' );

    is(
        Koha::Acquisition::OrderManagement::OrderlineUsers->search( { orderline_id => $orderline_id } )->count, 0,
        'patron_to_notify records cascade-deleted with orderline'
    );
    is(
        Koha::Acquisition::OrderManagement::OrderlineManagers->search( { orderline_id => $orderline_id } )->count, 0,
        'manager records cascade-deleted with orderline'
    );
    is( Koha::Acquisition::OrderManagement::OrderlineFundDistributions->search( { orderline_id => $orderline_id } )
            ->count, 0, 'fund distribution records cascade-deleted with orderline' );
    is(
        Koha::Acquisition::OrderManagement::OrderlineItems->search( { orderline_id => $orderline_id } )->count, 0,
        'item link records cascade-deleted with orderline'
    );

    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/orderlines/$orderline_id")->status_is(404);

    $schema->storage->txn_rollback;
};
