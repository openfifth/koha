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

use Test::More tests => 6;
use Test::NoWarnings;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Patron::Debarments qw( AddDebarment );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $password = 'thePassword123';

=head2 build_staff_user

    my ( $userid, $patron ) = build_staff_user();

Builds a staff user that holds the reserveforothers > place_holds permission,
which is the permission that this endpoint needs.

=cut

sub build_staff_user {

    my $staff = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );

    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $staff->borrowernumber,
                module_bit     => 6,
                code           => 'place_holds',
            },
        }
    );

    $staff->set_password( { password => $password, skip_validation => 1 } );

    return ( $staff->userid, $staff );
}

subtest 'An eligible patron' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'maxoutstanding', 0 );
    t::lib::Mocks::mock_preference( 'maxreserves',    0 );

    my ($userid) = build_staff_user();
    my $patron   = $builder->build_object( { class => 'Koha::Patrons' } );
    my $id       = $patron->borrowernumber;

    $t->get_ok("//$userid:$password@/api/v1/patrons/$id/hold_eligibility")
        ->status_is(200)
        ->json_is( '/available'          => Mojo::JSON->true )
        ->json_is( '/needs_confirmation' => Mojo::JSON->false )
        ->json_is( '/blockers'           => [] )
        ->json_is( '/warnings'           => [] );

    $schema->storage->txn_rollback;
};

subtest 'A restricted patron' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'maxoutstanding', 0 );
    t::lib::Mocks::mock_preference( 'maxreserves',    0 );

    my ($userid) = build_staff_user();
    my $patron   = $builder->build_object( { class => 'Koha::Patrons' } );
    my $id       = $patron->borrowernumber;

    AddDebarment( { borrowernumber => $id, type => 'MANUAL' } );

    $t->get_ok("//$userid:$password@/api/v1/patrons/$id/hold_eligibility")
        ->status_is(200)
        ->json_is( '/available' => Mojo::JSON->false )
        ->json_is( '/blockers'  => [ { code => 'restricted' } ] )
        ->json_hasnt( '/blockers/0/payload', 'A restricted blocker carries no payload' );

    $schema->storage->txn_rollback;
};

subtest 'A patron above the debt limit carries the payload' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'maxoutstanding', 5 );
    t::lib::Mocks::mock_preference( 'maxreserves',    0 );

    my ($userid) = build_staff_user();
    my $patron   = $builder->build_object( { class => 'Koha::Patrons' } );
    my $id       = $patron->borrowernumber;

    $patron->account->add_debit( { amount => 10, interface => 'opac', type => 'ACCOUNT' } );

    $t->get_ok("//$userid:$password@/api/v1/patrons/$id/hold_eligibility")
        ->status_is(200)
        ->json_is( '/available'                            => Mojo::JSON->false )
        ->json_is( '/blockers/0/code'                      => 'debt_limit' )
        ->json_is( '/blockers/0/payload/total_outstanding' => 10 )
        ->json_is( '/blockers/0/payload/max_outstanding'   => 5 );

    $schema->storage->txn_rollback;
};

subtest 'Every blocker is reported, and x-koha-override clears them' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'maxoutstanding', 5 );
    t::lib::Mocks::mock_preference( 'maxreserves',    0 );

    my ($userid) = build_staff_user();

    # This patron meets three gates at once. Koha::Patron::Availability::Hold
    # stops at the first gate unless the caller asks for every one, so this also
    # proves that the endpoint passes no_short_circuit.
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                dateexpiry    => \'DATE_ADD(NOW(), INTERVAL -1 DAY)',
                gonenoaddress => 1,
            }
        }
    );
    my $id = $patron->borrowernumber;

    $patron->category->BlockExpiredPatronOpacActions('hold')->store;
    $patron->account->add_debit( { amount => 10, interface => 'opac', type => 'ACCOUNT' } );

    my $result =
        $t->get_ok("//$userid:$password@/api/v1/patrons/$id/hold_eligibility")
        ->status_is(200)
        ->json_is( '/available' => Mojo::JSON->false )
        ->tx->res->json;

    is_deeply(
        [ map { $_->{code} } @{ $result->{blockers} } ],
        [ 'bad_address', 'debt_limit', 'expired' ],
        'All three blockers are reported, in a sorted order'
    );

    $t->get_ok(
        "//$userid:$password@/api/v1/patrons/$id/hold_eligibility" => { 'x-koha-override' => 'expired,debt_limit' } )
        ->status_is(200)
        ->json_is( '/available' => Mojo::JSON->false )
        ->json_is( '/blockers'  => [ { code => 'bad_address' } ], 'The overridden blockers are gone' );

    $schema->storage->txn_rollback;
};

subtest 'Error cases' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my ($userid) = build_staff_user();

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $id     = $patron->borrowernumber;
    $patron->delete;

    $t->get_ok("//$userid:$password@/api/v1/patrons/$id/hold_eligibility")
        ->status_is( 404, 'An unknown patron gives a 404' );

    # A user without the reserveforothers > place_holds permission
    my $unauthorised = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $unauthorised->set_password( { password => $password, skip_validation => 1 } );
    my $unauthorised_userid = $unauthorised->userid;

    my $other    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $other_id = $other->borrowernumber;

    $t->get_ok("//$unauthorised_userid:$password@/api/v1/patrons/$other_id/hold_eligibility")
        ->status_is( 403, 'A user without place_holds gives a 403' );

    $schema->storage->txn_rollback;
};
