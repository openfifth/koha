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
use Test::More tests => 7;
use Test::Mojo;
use Test::Warn;
use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Circulation qw( AddIssue );
use C4::Reserves    qw( AddReserve );
use Koha::Database;
use Koha::Holds;
use Koha::Checkin;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );
my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'get_availability' => sub {

    plan tests => 17;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2 } } );
    my $password  = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $patron->set_password( { password => 'pass000', skip_validation => 1 } );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    # Unauthorized
    $t->get_ok( "//" . $patron->userid . ":pass000\@/api/v1/checkins/availability?item_id=" . $item->id )
        ->status_is(403);

    # Missing item_id
    $t->get_ok( "//$userid:$password\@/api/v1/checkins/availability?library_id=" . $library->branchcode )
        ->status_is(400);

    # Item not found
    $t->get_ok("//$userid:$password\@/api/v1/checkins/availability?item_id=999999999")->status_is(404);

    # Item not checked out - not_issued warning + token
    $t->get_ok( "//$userid:$password\@/api/v1/checkins/availability?item_id="
            . $item->id
            . "&library_id="
            . $library->branchcode )
        ->status_is(200)
        ->json_is( '/blockers' => {} )
        ->json_has('/warnings/not_issued')
        ->json_is( '/confirmation_token' => undef );

    # Item checked out - no confirmations, no token
    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    $t->get_ok( "//$userid:$password\@/api/v1/checkins/availability?item_id="
            . $item->id
            . "&library_id="
            . $library->branchcode )->status_is(200)->json_is( '/confirmation_token' => undef );

    # Withdrawn item with BlockReturnOfWithdrawnItems - has blocker
    my $withdrawn_item = $builder->build_sample_item( { library => $library->branchcode, withdrawn => 1 } );
    AddIssue( $patron, $withdrawn_item->barcode );
    t::lib::Mocks::mock_preference( 'BlockReturnOfWithdrawnItems', 1 );

    $t->get_ok( "//$userid:$password\@/api/v1/checkins/availability?item_id="
            . $withdrawn_item->id
            . "&library_id="
            . $library->branchcode )->status_is(200)->json_has('/blockers/blocked_withdrawn');

    $schema->storage->txn_rollback;
};

subtest 'add' => sub {

    plan tests => 33;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2 } } );
    my $password  = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $patron->set_password( { password => 'pass000', skip_validation => 1 } );

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

    # Unauthorized
    $t->post_ok(
        "//" . $patron->userid . ":pass000\@/api/v1/checkins" => json => {
            item_id    => $item->id,
            library_id => $library->branchcode,
        }
    )->status_is(403);

    # Missing parameters
    $t->post_ok( "//$userid:$password\@/api/v1/checkins" => json => { library_id => $library->branchcode } )
        ->status_is(400)
        ->json_is( '/error_code' => 'missing_item_identifier' );

    # Item not found
    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => 999999999,
            library_id => $library->branchcode,
        }
    )->status_is(404);

    # Not checked out - succeeds directly (local use, no confirmation needed)
    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => $item->id,
            library_id => $library->branchcode,
        }
        )
        ->status_is(200)
        ->json_has('/checkin_id')
        ->json_is( '/item_id' => $item->id );

    # Check out then check in - normal flow
    AddIssue( $patron, $item->barcode );
    my $checkout = Koha::Checkouts->find( { itemnumber => $item->id } );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => $item->id,
            library_id => $library->branchcode,
        }
        )
        ->status_is(200)
        ->json_has('/checkin_id')
        ->json_is( '/item_id'     => $item->id )
        ->json_is( '/checkout_id' => $checkout->issue_id )
        ->json_is( '/library_id'  => $library->branchcode );

    # Check in by barcode
    AddIssue( $patron, $item->barcode );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            external_id => $item->barcode,
            library_id  => $library->branchcode,
        }
    )->status_is(200)->json_has('/checkin_id');

    # With embeds
    AddIssue( $patron, $item->barcode );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => { 'x-koha-embed' => 'item,library' } => json => {
            item_id    => $item->id,
            library_id => $library->branchcode,
        }
    )->status_is(200)->json_has('/item')->json_has('/library');

    # Withdrawn + BlockReturnOfWithdrawnItems - blocked
    my $withdrawn_item = $builder->build_sample_item( { library => $library->branchcode, withdrawn => 1 } );
    AddIssue( $patron, $withdrawn_item->barcode );
    t::lib::Mocks::mock_preference( 'BlockReturnOfWithdrawnItems', 1 );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => $withdrawn_item->id,
            library_id => $library->branchcode,
        }
    )->status_is(403)->json_is( '/error_code' => 'checkin_blocked' );

    # exempt_fine without writeoff permission - rejected
    t::lib::Mocks::mock_preference( 'BlockReturnOfWithdrawnItems', 0 );
    t::lib::Mocks::mock_preference( 'finesMode',                   'production' );

    my $limited_staff = $builder->build_object(
        { class => 'Koha::Patrons', value => { flags => 2 } }    # circulate only
    );
    my $limited_pw = 'limitedPass123';
    $limited_staff->set_password( { password => $limited_pw, skip_validation => 1 } );
    my $limited_userid = $limited_staff->userid;

    my $fine_item = $builder->build_sample_item( { library => $library->branchcode } );
    AddIssue( $patron, $fine_item->barcode );

    $t->post_ok(
        "//$limited_userid:$limited_pw\@/api/v1/checkins" => json => {
            item_id     => $fine_item->id,
            library_id  => $library->branchcode,
            exempt_fine => 1,
        }
    )->status_is(403)->json_is( '/error_code' => 'no_permission_for_exempt_fine' );

    # Same request without exempt_fine succeeds
    $t->post_ok(
        "//$limited_userid:$limited_pw\@/api/v1/checkins" => json => {
            item_id    => $fine_item->id,
            library_id => $library->branchcode,
        }
    )->status_is(200)->json_has('/checkin_id');

    $schema->storage->txn_rollback;
};

subtest 'add - return_date and dropbox_mode' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2 } } );
    my $password  = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

    # Check in with explicit return_date
    my $item = $builder->build_sample_item( { library => $library->branchcode } );
    AddIssue( $patron, $item->barcode );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id     => $item->id,
            library_id  => $library->branchcode,
            return_date => '2025-01-15T10:00:00',
        }
    )->status_is(200)->json_has('/checkin_id');

    # Check in with dropbox_mode
    my $item2 = $builder->build_sample_item( { library => $library->branchcode } );
    AddIssue( $patron, $item2->barcode );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id      => $item2->id,
            library_id   => $library->branchcode,
            dropbox_mode => 1,
        }
    )->status_is(200)->json_has('/checkin_id');

    # dropbox_mode takes precedence over return_date
    my $item3 = $builder->build_sample_item( { library => $library->branchcode } );
    AddIssue( $patron, $item3->barcode );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id      => $item3->id,
            library_id   => $library->branchcode,
            return_date  => '2025-06-01T12:00:00',
            dropbox_mode => 1,
        }
    )->status_is(200);

    $schema->storage->txn_rollback;
};

subtest 'add - post-checkin messages' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2 } } );
    my $password  = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

    # Check in a lost item - should get was_lost message
    my $lost_item = $builder->build_sample_item( { library => $library->branchcode } );
    AddIssue( $patron, $lost_item->barcode );
    $lost_item->itemlost(1)->store;

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => $lost_item->id,
            library_id => $library->branchcode,
        }
    )->status_is(200)->json_has('/checkin_id');

    # Verify was_lost message is present somewhere in the messages array
    my $messages = $t->tx->res->json('/messages');
    ok( ( grep { $_->{message} eq 'was_lost' } @$messages ), 'was_lost message present' );

    # Check in item not checked out (with confirmation token) - should get not_issued and local_use
    my $free_item = $builder->build_sample_item( { library => $library->branchcode } );

    # Check in item not checked out - succeeds directly
    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => $free_item->id,
            library_id => $library->branchcode,
        }
    )->status_is(200);

    $schema->storage->txn_rollback;
};

subtest 'X-Koha-Module-Policy header' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
    my $password  = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $item    = $builder->build_sample_item( { library => $library->branchcode } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );
    t::lib::Mocks::mock_preference( 'finesMode',  'production' );
    t::lib::Mocks::mock_preference( 'UseRecalls', 1 );

    # get_availability includes the header
    $t->get_ok( "//$userid:$password\@/api/v1/checkins/availability?item_id="
            . $item->id
            . "&library_id="
            . $library->branchcode )
        ->status_is(200)
        ->header_like( 'X-Koha-Module-Policy' => qr/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/ );

    # add (checkin) includes the header
    AddIssue( $patron, $item->barcode );

    $t->post_ok(
        "//$userid:$password\@/api/v1/checkins" => json => {
            item_id    => $item->id,
            library_id => $library->branchcode,
        }
        )
        ->status_is(200)
        ->header_like( 'X-Koha-Module-Policy' => qr/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/ );

    # Decode and verify policy content
    my $jwt = $t->tx->res->headers->header('X-Koha-Module-Policy');
    require Encode;
    require Digest::MD5;
    require Mojo::JWT;
    my $secret = Digest::MD5::md5_base64( Encode::encode( 'UTF-8', C4::Context->config('pass') ) );
    my $claims = Mojo::JWT->new( secret => $secret )->decode($jwt);

    is( $claims->{exempt_fine},     1, 'Policy JWT carries exempt_fine=1 for superlibrarian' );
    is( $claims->{recalls_enabled}, 1, 'Policy JWT carries recalls_enabled=1' );
    ok( exists $claims->{transfers_block}, 'Policy JWT carries transfers_block key' );

    $schema->storage->txn_rollback;
};

subtest 'sub-resource confirmation endpoints' => sub {

    plan tests => 24;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
    my $password  = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $patron->set_password( { password => 'pass000', skip_validation => 1 } );

    my $checkin_library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $pickup_library  = $builder->build_object( { class => 'Koha::Libraries' } );

    t::lib::Mocks::mock_userenv(
        { branchcode => $checkin_library->branchcode, borrowernumber => $librarian->borrowernumber } );
    t::lib::Mocks::mock_preference( 'UseRecalls', 0 );

    # -- hold_confirmation: not found
    $t->post_ok( "//$userid:$password\@/api/v1/checkins/999999999/hold_confirmation" )->status_is(404);

    # -- hold_confirmation: no hold (400)
    my $item_no_hold = $builder->build_sample_item( { library => $checkin_library->branchcode } );
    AddIssue( $patron, $item_no_hold->barcode );
    $t->post_ok( "//$userid:$password\@/api/v1/checkins" => json =>
            { item_id => $item_no_hold->id, library_id => $checkin_library->branchcode } )->status_is(200);
    my $checkin_no_hold_id = $t->tx->res->json('/checkin_id');

    $t->post_ok( "//$userid:$password\@/api/v1/checkins/$checkin_no_hold_id/hold_confirmation" )->status_is(400);

    # -- hold_confirmation: same library (set to waiting)
    my $item = $builder->build_sample_item( { library => $checkin_library->branchcode } );
    AddIssue( $patron, $item->barcode );

    my $reserve_id = AddReserve(
        {
            branchcode     => $checkin_library->branchcode,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item->biblionumber,
            itemnumber     => $item->itemnumber,
            priority       => 1,
        }
    );

    $t->post_ok( "//$userid:$password\@/api/v1/checkins" => json =>
            { item_id => $item->id, library_id => $checkin_library->branchcode } )->status_is(200);
    my $checkin_id = $t->tx->res->json('/checkin_id');

    $t->post_ok( "//$userid:$password\@/api/v1/checkins/$checkin_id/hold_confirmation" )
        ->status_is(201)
        ->header_like( 'Location' => qr{/api/v1/checkins/\d+} );

    my $hold = Koha::Holds->find($reserve_id);
    is( $hold->found, 'W', 'Hold set to waiting after hold_confirmation' );

    # -- hold_cancellation
    my $item2 = $builder->build_sample_item( { library => $checkin_library->branchcode } );
    AddIssue( $patron, $item2->barcode );

    my $reserve_id2 = AddReserve(
        {
            branchcode     => $checkin_library->branchcode,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item2->biblionumber,
            itemnumber     => $item2->itemnumber,
            priority       => 1,
        }
    );

    $t->post_ok( "//$userid:$password\@/api/v1/checkins" => json =>
            { item_id => $item2->id, library_id => $checkin_library->branchcode } )->status_is(200);
    my $checkin_id2 = $t->tx->res->json('/checkin_id');

    warning_like {
        $t->post_ok(
            "//$userid:$password\@/api/v1/checkins/$checkin_id2/hold_cancellation" => json =>
                { reason => 'PATRON_REQUEST' } )->status_is(201);
    } qr/HOLD_CANCELLATION/, 'Warning about missing letter template expected';

    is( Koha::Holds->find($reserve_id2), undef, 'Hold cancelled' );

    # -- transfer_confirmation
    my $item3     = $builder->build_sample_item( { library => $checkin_library->branchcode } );
    my $to_branch = $builder->build_object( { class => 'Koha::Libraries' } );
    my $transfer  = $item3->request_transfer( { to => $to_branch, reason => 'Manual' } );

    my $checkin3 = Koha::Checkin->new(
        {
            item_id     => $item3->itemnumber,
            user_id     => $librarian->borrowernumber,
            library_id  => $checkin_library->branchcode,
            transfer_id => $transfer->id,
        }
    )->store;

    $t->post_ok( "//$userid:$password\@/api/v1/checkins/" . $checkin3->id . "/transfer_confirmation" )
        ->status_is(201);

    $transfer->discard_changes;
    ok( $transfer->datesent, 'Transfer set in transit' );

    # -- transfer_cancellation
    my $item4      = $builder->build_sample_item( { library => $checkin_library->branchcode } );
    my $transfer4  = $item4->request_transfer( { to => $to_branch, reason => 'Manual' } );
    $transfer4->transit;

    my $checkin4 = Koha::Checkin->new(
        {
            item_id     => $item4->itemnumber,
            user_id     => $librarian->borrowernumber,
            library_id  => $checkin_library->branchcode,
            transfer_id => $transfer4->id,
        }
    )->store;

    $t->post_ok( "//$userid:$password\@/api/v1/checkins/" . $checkin4->id . "/transfer_cancellation" )
        ->status_is(201);

    $transfer4->discard_changes;
    ok( $transfer4->datecancelled, 'Transfer cancelled' );

    $schema->storage->txn_rollback;
};
