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
use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Patron::AccountLinks;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {
    plan tests => 11;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }    # borrowers flag
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

    my $test_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $t->get_ok( "//$userid:$password@/api/v1/patrons/" . $test_patron->borrowernumber . "/account_links" )
        ->status_is(200)
        ->json_is( [] );

    my $linked_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();

    Koha::Patron::AccountLink->new(
        { link_group_id => $link_group_id, borrowernumber => $test_patron->borrowernumber } )->store;
    Koha::Patron::AccountLink->new(
        { link_group_id => $link_group_id, borrowernumber => $linked_patron->borrowernumber } )->store;

    $t->get_ok( "//$userid:$password@/api/v1/patrons/" . $test_patron->borrowernumber . "/account_links" )
        ->status_is(200)
        ->json_has('/0')
        ->json_has('/1');

    $t->get_ok( "//$unauth_userid:$password@/api/v1/patrons/" . $test_patron->borrowernumber . "/account_links" )
        ->status_is(403);

    $t->get_ok("//$userid:$password@/api/v1/patrons/99999999/account_links")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {
    plan tests => 13;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
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

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );

    $t->post_ok( "//$unauth_userid:$password@/api/v1/patrons/"
            . $patron1->borrowernumber
            . "/account_links" => json => { linked_patron_id => $patron2->borrowernumber } )->status_is(403);

    $t->post_ok( "//$userid:$password@/api/v1/patrons/"
            . $patron1->borrowernumber
            . "/account_links" => json => { linked_patron_id => $patron2->borrowernumber } )
        ->status_is(201)
        ->json_has('/account_link_id')
        ->json_has('/link_group_id');

    ok( $patron1->account_link, 'patron1 now has account link' );
    ok( $patron2->account_link, 'patron2 now has account link' );
    is(
        $patron1->account_link->link_group_id, $patron2->account_link->link_group_id,
        'Both patrons in same link group'
    );

    $t->post_ok( "//$userid:$password@/api/v1/patrons/"
            . $patron1->borrowernumber
            . "/account_links" => json => { linked_patron_id => $patron2->borrowernumber } )->status_is(409);

    $t->post_ok( "//$userid:$password@/api/v1/patrons/"
            . $patron1->borrowernumber
            . "/account_links" => json => { linked_patron_id => 99999999 } )->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() to existing group' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );

    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;

    $t->post_ok( "//$userid:$password@/api/v1/patrons/"
            . $patron1->borrowernumber
            . "/account_links" => json => { linked_patron_id => $patron3->borrowernumber } )->status_is(201);

    ok( $patron3->account_link, 'patron3 now has account link' );
    is( $patron3->account_link->link_group_id, $link_group_id, 'patron3 added to existing group' );

    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        3, 'Now 3 patrons in group'
    );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {
    plan tests => 10;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
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

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );

    # Use 3-patron group so deleting one leaves 2 (no orphan cleanup triggered)
    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();
    my $link1         = Koha::Patron::AccountLink->new(
        { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron3->borrowernumber } )
        ->store;

    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/patrons/" . $patron1->borrowernumber . "/account_links/" . $link1->id )
        ->status_is(403);

    $t->delete_ok( "//$userid:$password@/api/v1/patrons/" . $patron1->borrowernumber . "/account_links/" . $link1->id )
        ->status_is(204);

    ok( !$patron1->account_link, 'patron1 link removed' );
    ok( $patron2->account_link,  'patron2 link still exists (3-patron group, no orphan cleanup)' );

    $t->delete_ok( "//$userid:$password@/api/v1/patrons/" . $patron1->borrowernumber . "/account_links/" . $link1->id )
        ->status_is(404);

    $t->delete_ok("//$userid:$password@/api/v1/patrons/99999999/account_links/1")->status_is(404);

    $schema->storage->txn_rollback;
};
