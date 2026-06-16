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
use Test::More tests => 6;
use Test::Warn;

use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Acquisition::VendorAllocation;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 14;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }    ## 11 => acquisitions
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $vendor_id = $vendor->id;

    # No allocations yet
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations")
        ->status_is(200)
        ->json_is( [] );

    my $period_1 = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    my $period_2 = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );

    Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor_id,
            budget_period_id  => $period_1->budget_period_id,
            allocation_amount => '1000.000000',
        }
    )->store;
    Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor_id,
            budget_period_id  => $period_2->budget_period_id,
            allocation_amount => '500.000000',
        }
    )->store;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations")
        ->status_is(200)
        ->json_has('/0/allocation_id')
        ->json_has('/0/vendor_id')
        ->json_has('/0/budget_period_id')
        ->json_has('/0/allocation_amount')
        ->json_has('/1/allocation_id');

    # Unauthorized
    $patron->set( { flags => 0 } )->store;
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations")
        ->status_is(403);

    # Vendor not found
    my $gone_vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $gone_id     = $gone_vendor->id;
    $gone_vendor->delete;
    $patron->set( { flags => 2**11 } )->store;
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/vendors/$gone_id/allocations")
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );

    my $allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $period->budget_period_id,
            allocation_amount => '750.000000',
        }
    )->store;

    my $vendor_id     = $vendor->id;
    my $allocation_id = $allocation->id;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id")
        ->status_is(200)
        ->json_is( '/allocation_id'    => $allocation_id )
        ->json_is( '/vendor_id'        => $vendor_id )
        ->json_is( '/allocation_amount' => 750 );

    # Not found
    $allocation->delete;
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id")
        ->status_is(404);

    # Unauthorized
    $patron->set( { flags => 0 } )->store;
    my $other_allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $period->budget_period_id,
            allocation_amount => '100.000000',
        }
    )->store;
    $t->get_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/"
            . $other_allocation->id
    )->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $authorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $authorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $auth_userid = $authorized_patron->userid;

    my $unauthorized_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $unauthorized_patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $unauthorized_patron->userid;

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    my $vendor_id = $vendor->id;

    my $allocation_body = {
        budget_period_id   => $period->budget_period_id,
        allocation_amount  => 1000,
        warn_at_percentage => 80,
        warn_at_amount     => 900,
    };

    $t->post_ok(
        "//$auth_userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations"
            => json => $allocation_body
    )
        ->status_is(201)
        ->json_has('/allocation_id')
        ->json_is( '/vendor_id'       => $vendor_id )
        ->json_is( '/allocation_amount' => 1000 )
        ->header_like( Location => qr|/api/v1/acquisitions/vendors/$vendor_id/allocations/\d+| );

    # Duplicate — same vendor + period
    warnings_like {
        $t->post_ok(
            "//$auth_userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations"
                => json => $allocation_body
        )->status_is(409);
    }
    qr{DBD::mysql::st execute failed: Duplicate entry '.*' for key 'uq_vendor_period'};

    # Unauthorized
    my $period_2 = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );
    $t->post_ok(
        "//$unauth_userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations"
            => json => {
                budget_period_id  => $period_2->budget_period_id,
                allocation_amount => 500,
            }
    )->status_is(403);

    # Vendor not found
    my $gone_vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $gone_id     = $gone_vendor->id;
    $gone_vendor->delete;
    $t->post_ok(
        "//$auth_userid:$password@/api/v1/acquisitions/vendors/$gone_id/allocations"
            => json => {
                budget_period_id  => $period_2->budget_period_id,
                allocation_amount => 500,
            }
    )->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );

    my $allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $period->budget_period_id,
            allocation_amount => '500.000000',
        }
    )->store;

    my $vendor_id     = $vendor->id;
    my $allocation_id = $allocation->id;

    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id"
            => json => {
                budget_period_id   => $period->budget_period_id,
                allocation_amount  => 750,
                warn_at_percentage => 80,
                warn_at_amount     => 700,
            }
    )
        ->status_is(200)
        ->json_is( '/allocation_amount'  => 750 )
        ->json_is( '/warn_at_percentage' => 80 );

    # Not found
    $allocation->delete;
    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id"
            => json => {
                budget_period_id  => $period->budget_period_id,
                allocation_amount => 750,
            }
    )->status_is(404);

    # Unauthorized
    $patron->set( { flags => 0 } )->store;
    my $other_allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $period->budget_period_id,
            allocation_amount => '200.000000',
        }
    )->store;
    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/"
            . $other_allocation->id
            => json => { budget_period_id => $period->budget_period_id, allocation_amount => 300 }
    )->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    my $vendor = $builder->build_object( { class => 'Koha::Acquisition::Booksellers' } );
    my $period = $builder->build_object( { class => 'Koha::Acquisition::Budgets' } );

    my $allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $period->budget_period_id,
            allocation_amount => '500.000000',
        }
    )->store;

    my $vendor_id     = $vendor->id;
    my $allocation_id = $allocation->id;

    $t->delete_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id"
    )
        ->status_is(204)
        ->content_is('');

    # Deleted — subsequent GET returns 404
    $t->get_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id"
    )->status_is(404);

    # Not found
    $t->delete_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/$allocation_id"
    )->status_is(404);

    # Unauthorized
    $patron->set( { flags => 0 } )->store;
    my $other_allocation = Koha::Acquisition::VendorAllocation->new(
        {
            booksellerid      => $vendor->id,
            budget_period_id  => $period->budget_period_id,
            allocation_amount => '200.000000',
        }
    )->store;
    $t->delete_ok(
        "//$userid:$password@/api/v1/acquisitions/vendors/$vendor_id/allocations/"
            . $other_allocation->id
    )->status_is(403);

    $schema->storage->txn_rollback;
};
