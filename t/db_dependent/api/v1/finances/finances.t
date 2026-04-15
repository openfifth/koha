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
use Test::More tests => 3;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use JSON qw(encode_json);
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'config() tests' => sub {

    plan tests => 10;

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

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/finances/config")->status_is(403);

    # Authorized access returns config object
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/finances/config")
        ->status_is(200)
        ->json_has('/permissions')
        ->json_has('/sysprefs')
        ->json_has('/gst_values');

    # Verify specific syspref keys are present in the response
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/finances/config")
        ->status_is(200)
        ->json_has('/sysprefs/calculate_fund_values_including_tax');

    $schema->storage->txn_rollback;
};

subtest 'list_users() tests' => sub {

    plan tests => 17;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Superlibrarian - authorised to make requests, and should appear in all results
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 1 }     # superlibrarian
        }
    );
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    # No permissions - unauthorised and should not appear in any results
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    # Full acquisition module flag - should appear for both module-level and sub-permission queries
    my $acq_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }    # acquisition flag (bit 11)
        }
    );

    # Catalogue permission only - should NOT appear in any acquisition results
    my $catalogue_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2 }        # catalogue flag (bit 1), no acquisition
        }
    );

    # budget_manage_all sub-permission only (no module flag) - should appear only for the
    # sub-permission query, not the module-level query
    my $sub_perm_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $sub_perm_patron->borrowernumber,
                module_bit     => 11,
                code           => 'budget_manage_all',
            }
        }
    );

    # Different sub-permission (budget_manage) - should NOT appear for budget_manage_all query
    my $other_sub_perm_patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $other_sub_perm_patron->borrowernumber,
                module_bit     => 11,
                code           => 'budget_manage',
            }
        }
    );

    # Unauthorized access
    my $query = encode_json( { permission => 'acquisition' } );
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/finances/users?q=$query")->status_is(403);

    # Module-level query: only patrons with the acquisition flag or superlibrarian are returned;
    # sub-permission-only patrons are not matched without the module flag
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/finances/users?q=$query")->status_is(200);
    my $patron_ids = [ map { $_->{patron_id} } @{ $t->tx->res->json } ];

    ok(
        grep( { $_ == $librarian->borrowernumber } @$patron_ids ),
        'Module-level: superlibrarian is included'
    );
    ok(
        grep( { $_ == $acq_patron->borrowernumber } @$patron_ids ),
        'Module-level: patron with full acquisition flag is included'
    );
    ok(
        !grep( { $_ == $patron->borrowernumber } @$patron_ids ),
        'Module-level: patron with no permissions is excluded'
    );
    ok(
        !grep( { $_ == $catalogue_patron->borrowernumber } @$patron_ids ),
        'Module-level: patron with only catalogue permission is excluded'
    );
    ok(
        !grep( { $_ == $sub_perm_patron->borrowernumber } @$patron_ids ),
        'Module-level: patron with budget_manage_all sub-permission only is excluded'
    );
    ok(
        !grep( { $_ == $other_sub_perm_patron->borrowernumber } @$patron_ids ),
        'Module-level: patron with budget_manage sub-permission only is excluded'
    );

    # Sub-permission query: patrons with the specific sub-permission are now also matched,
    # but patrons with a different sub-permission are still excluded
    my $sub_perm_query = encode_json( { permission => 'acquisition.budget_manage_all' } );
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/finances/users?q=$sub_perm_query")->status_is(200);
    my $sub_perm_patron_ids = [ map { $_->{patron_id} } @{ $t->tx->res->json } ];

    ok(
        grep( { $_ == $librarian->borrowernumber } @$sub_perm_patron_ids ),
        'Sub-permission: superlibrarian is included'
    );
    ok(
        grep( { $_ == $acq_patron->borrowernumber } @$sub_perm_patron_ids ),
        'Sub-permission: patron with full acquisition flag is included'
    );
    ok(
        grep( { $_ == $sub_perm_patron->borrowernumber } @$sub_perm_patron_ids ),
        'Sub-permission: patron with budget_manage_all sub-permission is included'
    );
    ok(
        !grep( { $_ == $patron->borrowernumber } @$sub_perm_patron_ids ),
        'Sub-permission: patron with no permissions is excluded'
    );
    ok(
        !grep( { $_ == $other_sub_perm_patron->borrowernumber } @$sub_perm_patron_ids ),
        'Sub-permission: patron with different sub-permission (budget_manage) is excluded'
    );

    $schema->storage->txn_rollback;
};
