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
use Test::More tests => 2;
use Test::Mojo;
use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::Item::Transfers;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );
my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'cancel() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**0 }    # circulate flag = 1
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $unauth = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $unauth->set_password( { password => 'pass000', skip_validation => 1 } );

    my $library_from = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_to   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $item         = $builder->build_sample_item( { library => $library_from->branchcode } );

    my $transfer = $builder->build_object(
        {
            class => 'Koha::Item::Transfers',
            value => {
                itemnumber    => $item->itemnumber,
                frombranch    => $library_from->branchcode,
                tobranch      => $library_to->branchcode,
                datesent      => undef,
                datearrived   => undef,
                datecancelled => undef,
            }
        }
    );

    # Unauthorized
    $t->post_ok( "//" . $unauth->userid . ":pass000\@/api/v1/transfers/" . $transfer->id . "/cancellation" )
        ->status_is( 403, 'Not authorized without circulate permission' );

    # Not found
    $t->post_ok( "//$userid:$password\@/api/v1/transfers/" . ( $transfer->id + 1000 ) . "/cancellation" )
        ->status_is( 404, 'Returns 404 for an unknown transfer' )
        ->json_is( '/error', 'Transfer not found' );

    # Happy path
    my $tx =
        $t->post_ok( "//$userid:$password\@/api/v1/transfers/" . $transfer->id . "/cancellation" )
        ->status_is( 200, 'Transfer cancelled' )
        ->json_is( '/transfer_id', $transfer->id, 'Returns the cancelled transfer' );
    ok( $tx->tx->res->json->{date_cancelled}, 'date_cancelled is set in the response' );

    $transfer->discard_changes;
    ok( $transfer->datecancelled, 'datecancelled populated in the database' );
    is( $transfer->cancellation_reason, 'Manual', 'cancellation_reason is Manual' );

    # Cancelling again -> already cancelled
    $t->post_ok( "//$userid:$password\@/api/v1/transfers/" . $transfer->id . "/cancellation" )
        ->status_is( 409, 'Returns 409 when the transfer is already cancelled' )
        ->json_is( '/error_code', 'already_cancelled', 'error_code is already_cancelled' );

    # An arrived transfer cannot be cancelled
    my $arrived = $builder->build_object(
        {
            class => 'Koha::Item::Transfers',
            value => {
                itemnumber    => $item->itemnumber,
                frombranch    => $library_from->branchcode,
                tobranch      => $library_to->branchcode,
                datearrived   => \'NOW()',
                datecancelled => undef,
            }
        }
    );
    $t->post_ok( "//$userid:$password\@/api/v1/transfers/" . $arrived->id . "/cancellation" )
        ->status_is( 409, 'Returns 409 when the transfer has already arrived' )
        ->json_is( '/error_code', 'already_arrived', 'error_code is already_arrived' );

    # A custom cancellation_reason is honoured
    my $with_reason = $builder->build_object(
        {
            class => 'Koha::Item::Transfers',
            value => {
                itemnumber    => $item->itemnumber,
                frombranch    => $library_from->branchcode,
                tobranch      => $library_to->branchcode,
                datearrived   => undef,
                datecancelled => undef,
            }
        }
    );
    $t->post_ok( "//$userid:$password\@/api/v1/transfers/"
            . $with_reason->id
            . "/cancellation" => json => { cancellation_reason => 'WrongTransfer' } )
        ->status_is( 200, 'Transfer cancelled with a custom reason' );
    $with_reason->discard_changes;
    is( $with_reason->cancellation_reason, 'WrongTransfer', 'Custom cancellation_reason honoured' );

    $schema->storage->txn_rollback;
};
