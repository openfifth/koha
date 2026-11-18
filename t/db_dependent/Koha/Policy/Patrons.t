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
use Test::More tests => 2;

use Koha::Database;
use Koha::Policy::Patrons;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'can_change_credentials' => sub {

    plan tests => 28;

    $schema->storage->txn_begin;

    my $staff_category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { category_type => 'S' } } );
    my $adult_category =
        $builder->build_object( { class => 'Koha::Patron::Categories', value => { category_type => 'A' } } );

    my $new_patron = sub {
        my ( $category, $flags ) = @_;
        return $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => { categorycode => $category->categorycode, flags => $flags }
            }
        );
    };

    my $editor           = $new_patron->( $adult_category, 2**4 );           # borrowers
    my $staffaccess      = $new_patron->( $adult_category, 2**4 + 2**17 );   # borrowers + staffaccess
    my $superlibrarian   = $new_patron->( $adult_category, 1 );
    my $ordinary         = $new_patron->( $adult_category, 0 );
    my $staff_category_p = $new_patron->( $staff_category, 0 );
    my $adult_with_flags = $new_patron->( $adult_category, 2**4 );           # not a staff category, but has permissions
    my $adult_super      = $new_patron->( $adult_category, 1 );              # not a staff category, but superlibrarian

    my $sub_editor = $new_patron->( $adult_category, 0 );
    $sub_editor->set_permissions( { borrowers => { edit_borrowers => 1 } } );
    my $sub_viewer = $new_patron->( $adult_category, 0 );
    $sub_viewer->set_permissions( { borrowers => { view_borrower_infos_from_any_libraries => 1 } } );
    my $sub_staffaccess = $new_patron->( $adult_category, 0 );
    $sub_staffaccess->set_permissions( { borrowers => { edit_borrowers => 1 }, staffaccess => 1 } );

    my $policy = 'Koha::Policy::Patrons';

    ok( $policy->can_change_credentials( $editor,           $editor ),      'Anyone can change their own password' );
    ok( $policy->can_change_credentials( $adult_super,      $adult_super ), 'Including a superlibrarian' );
    ok( $policy->can_change_credentials( $staff_category_p, $staff_category_p ), 'Including a staff category account' );

    ok( $policy->can_change_credentials( $editor, $ordinary ), "Can change an ordinary patron's password" );

    my $result = $policy->can_change_credentials( $editor, $staff_category_p );
    ok( !$result, "Cannot change a staff category account's password without staffaccess" );
    is( scalar @{ $result->messages },   1,                      'One message' );
    is( $result->messages->[0]->message, 'staffaccess_required', 'The message says what is missing' );

    $result = $policy->can_change_credentials( $editor, $adult_with_flags );
    ok( !$result, "Cannot change the password of an account with permissions, whatever its category" );
    is( $result->messages->[0]->message, 'staffaccess_required', 'The message says what is missing' );

    $result = $policy->can_change_credentials( $editor, $adult_super );
    ok( !$result, "Cannot change the password of a superlibrarian, whatever its category" );
    is( $result->messages->[0]->message, 'staffaccess_required', 'The message says what is missing' );

    ok(
        $policy->can_change_credentials( $staffaccess, $staff_category_p ),
        "staffaccess allows changing a staff category account's password"
    );
    ok(
        $policy->can_change_credentials( $staffaccess, $adult_with_flags ),
        "staffaccess allows changing the password of an account with permissions"
    );
    ok(
        $policy->can_change_credentials( $staffaccess, $adult_super ),
        "staffaccess allows changing a superlibrarian's password"
    );
    ok( $policy->can_change_credentials( $staffaccess, $ordinary ), "And an ordinary patron's, of course" );

    ok(
        $policy->can_change_credentials( $superlibrarian, $staff_category_p ),
        "A superlibrarian can change a staff category account's password"
    );
    ok(
        $policy->can_change_credentials( $superlibrarian, $adult_super ),
        "A superlibrarian can change another superlibrarian's password"
    );
    ok( $policy->can_change_credentials( $superlibrarian, $ordinary ), "And an ordinary patron's" );

    $result = $policy->can_change_credentials( $ordinary, $staff_category_p );
    ok( !$result, "A patron without any permission cannot change a staff account's password" );
    is( $result->messages->[0]->message, 'edit_borrowers_required', 'The missing permission is edit_borrowers' );

    $result = $policy->can_change_credentials( $ordinary, $new_patron->( $adult_category, 0 ) );
    ok( !$result, "A patron without any permission cannot change an ordinary patron's password either" );
    is( $result->messages->[0]->message, 'edit_borrowers_required', 'The missing permission is edit_borrowers' );

    ok( !$policy->can_change_credentials( $sub_viewer, $ordinary ), 'Another borrowers sub-permission is not enough' );

    ok(
        $policy->can_change_credentials( $sub_editor, $ordinary ),
        'The edit_borrowers sub-permission is enough for an ordinary patron'
    );
    $result = $policy->can_change_credentials( $sub_editor, $staff_category_p );
    ok( !$result, '... but not for a staff account' );
    is( $result->messages->[0]->message, 'staffaccess_required', 'The message says what is missing' );
    ok(
        $policy->can_change_credentials( $sub_staffaccess, $adult_super ),
        'edit_borrowers sub-permission plus staffaccess allows changing a superlibrarian'
    );

    ok(
        !$policy->can_change_credentials( $new_patron->( $adult_category, 2**17 ), $ordinary ),
        'staffaccess alone is not enough: edit_borrowers is still required'
    );

    $schema->storage->txn_rollback;
};
