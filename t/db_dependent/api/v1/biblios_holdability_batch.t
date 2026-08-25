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

use Test::More tests => 9;
use Test::NoWarnings;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;
use t::lib::QueryCounter;

use Koha::CirculationRules;
use Koha::Database;
use Koha::Patron::Debarments qw( AddDebarment );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $password = 'thePassword123';

# build_staff_user
#
#     my $userid = build_staff_user();
#
# Builds a staff user that holds the reserveforothers > place_holds permission,
# which is the permission that this endpoint needs.

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

    return $staff->userid;
}

# allow_holds
#
#     allow_holds();
#
# Sets a permissive default circulation rule. holds_per_record defaults to 1,
# which would otherwise block a patron before any item is looked at.

sub allow_holds {

    t::lib::Mocks::mock_preference( 'maxreserves',    0 );
    t::lib::Mocks::mock_preference( 'maxoutstanding', 0 );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 100, holds_per_record => 100 }
        }
    );

    return;
}

subtest 'Several patrons, one verdict for each' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );

    my $eligible =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $restricted =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    AddDebarment( { borrowernumber => $restricted->borrowernumber, type => 'MANUAL' } );

    my $biblio = $builder->build_sample_biblio;
    $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;

    $t->post_ok( "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json =>
            { patron_ids => [ $eligible->borrowernumber, $restricted->borrowernumber ] } )
        ->status_is( 200, 'Reports rather than creates, so 200 not 201' )
        ->json_is( '/0/patron_id' => $eligible->borrowernumber )
        ->json_is( '/0/available' => Mojo::JSON->true )
        ->json_is( '/1/patron_id' => $restricted->borrowernumber )
        ->json_is( '/1/available' => Mojo::JSON->false )
        ->json_is( '/1/blockers'  => [ { code => 'restricted', overridable => Mojo::JSON->true } ] )
        ->json_hasnt( '/0/item_id', 'A record-level verdict carries no item_id' );

    $schema->storage->txn_rollback;
};

subtest 'Several items for one patron' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $biblio = $builder->build_sample_biblio;
    my $good   = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, damaged => 0 } );
    my $damaged = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, damaged => 1 } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    $t->post_ok(
        "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json => {
            patron_ids => [$patron_id],
            item_ids   => [ $good->itemnumber, $damaged->itemnumber ],
        }
        )
        ->status_is(200)
        ->json_is( '/0/patron_id' => $patron_id )
        ->json_is( '/0/item_id'   => $good->itemnumber )
        ->json_is( '/0/available' => Mojo::JSON->true )
        ->json_is( '/1/item_id'   => $damaged->itemnumber )
        ->json_is( '/1/available' => Mojo::JSON->false )
        ->json_is( '/1/blockers'  => [ { code => 'damaged', overridable => Mojo::JSON->true } ] );

    $schema->storage->txn_rollback;
};

subtest 'Both lists give one entry for each pair' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );

    my @patrons =
        map { $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } ) }
        ( 1 .. 2 );

    my $biblio = $builder->build_sample_biblio;
    my @items  = map {
        $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } )
    } ( 1 .. 3 );

    my $biblio_id = $biblio->biblionumber;

    my $results = $t->post_ok(
        "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json => {
            patron_ids => [ map { $_->borrowernumber } @patrons ],
            item_ids   => [ map { $_->itemnumber } @items ],
        }
    )->status_is(200)->tx->res->json;

    is( scalar @{$results}, 6, 'Two patrons by three items gives six entries' );

    is_deeply(
        [ map { [ $_->{patron_id}, $_->{item_id} ] } @{$results} ],
        [
            map {
                my $p = $_;
                map { [ $p->borrowernumber, $_->itemnumber ] } @items
            } @patrons
        ],
        'Every pair is present, patron by patron'
    );

    $schema->storage->txn_rollback;
};

subtest 'The verdicts match the single-call endpoints' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    allow_holds();
    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, damaged => 1 } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;
    my $item_id   = $item->itemnumber;

    # Record level: the batch entry must match GET /biblios/{id}/holdability,
    # which adds an items summary the batch does not report.
    my $batch_record =
        $t->post_ok(
        "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json => { patron_ids => [$patron_id] } )
        ->status_is(200)
        ->tx->res->json->[0];

    my $single_record =
        $t->get_ok("//$userid:$password@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id")
        ->status_is(200)
        ->tx->res->json;

    delete $single_record->{items};
    delete $single_record->{hold_fee};
    delete $single_record->{prospective_priority};
    delete $batch_record->{patron_id};

    is_deeply( $batch_record, $single_record, 'The record-level verdict matches GET /biblios/{biblio_id}/holdability' );

    # Item level: must match GET /items/{item_id}/holdability
    my $batch_item = $t->post_ok(
        "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json => {
            patron_ids => [$patron_id],
            item_ids   => [$item_id],
        }
    )->tx->res->json->[0];

    my $single_item =
        $t->get_ok("//$userid:$password@/api/v1/items/$item_id/holdability?patron_id=$patron_id")->tx->res->json;

    delete $batch_item->{$_} for qw( patron_id item_id );

    is_deeply( $batch_item, $single_item, 'The item-level verdict matches GET /items/{item_id}/holdability' );

    $schema->storage->txn_rollback;
};

subtest 'An unknown id becomes its own entry' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $biblio = $builder->build_sample_biblio;
    my $item =
        $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;

    my $gone_patron    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $gone_patron_id = $gone_patron->borrowernumber;
    $gone_patron->delete;

    # An unknown patron must not cost the caller the other verdicts
    $t->post_ok( "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json =>
            { patron_ids => [ $gone_patron_id, $patron_id ] } )
        ->status_is( 200, 'The request still succeeds' )
        ->json_is( '/0/patron_id'  => $gone_patron_id )
        ->json_is( '/0/error_code' => 'patron_not_found' )
        ->json_hasnt( '/0/available', 'An unresolved entry carries no verdict' )
        ->json_is( '/1/patron_id' => $patron_id )
        ->json_is( '/1/available' => Mojo::JSON->true, 'The good patron is still answered' );

    # An item that is not on this record
    my $other_item = $builder->build_sample_item( { library => $library->branchcode } );

    $t->post_ok(
        "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json => {
            patron_ids => [$patron_id],
            item_ids   => [ $other_item->itemnumber, $item->itemnumber ],
        }
        )
        ->status_is(200)
        ->json_is( '/0/error_code' => 'item_not_found' )
        ->json_is( '/0/item_id'    => $other_item->itemnumber )
        ->json_is( '/1/available'  => Mojo::JSON->true, 'The item on this record is still answered' );

    $schema->storage->txn_rollback;
};

subtest 'The record items are fetched once for every patron' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );

    my $biblio = $builder->build_sample_biblio;
    $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } )
        for ( 1 .. 10 );

    my @patrons =
        map { $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } ) }
        ( 1 .. 20 );

    my $biblio_id = $biblio->biblionumber;
    my $url       = "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch";

    my $post = sub {
        my ($count) = @_;
        return $t->ua->post(
            $url => json => { patron_ids => [ map { $_->borrowernumber } @patrons[ 0 .. $count - 1 ] ] } );
    };

    # Warm the request path, then measure one patron against twenty
    $post->(1);

    my ( undef, $one )    = t::lib::QueryCounter->measure( sub { $post->(1);  return } );
    my ( undef, $twenty ) = t::lib::QueryCounter->measure( sub { $post->(20); return } );

    is( scalar @{ $post->(20)->res->json }, 20, 'Twenty patrons give twenty verdicts' );

    diag( sprintf( 'queries: 1 patron %d, 20 patrons %d', $one->{queries}, $twenty->{queries} ) );

    # Without the shared fetch_items call, each extra patron would re-read the
    # record's items. The check itself is per patron, so the count still grows -
    # but far more slowly than twenty times the single-patron cost.
    cmp_ok(
        $twenty->{queries}, '<', $one->{queries} * 20,
        'Twenty patrons cost less than twenty single-patron checks'
    );

    # The items query names the biblio and nothing else. It must appear once,
    # however many patrons the request asks about.
    my $item_fetches = () = $twenty->{trace} =~ /FROM `items` `me` WHERE \( `me`\.`biblionumber` = \? \):/g;

    is( $item_fetches, 1, 'The record item list is read exactly once' );

    $schema->storage->txn_rollback;
};

subtest 'Error cases' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid  = build_staff_user();
    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    my $biblio = $builder->build_sample_biblio;
    $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;
    my $url       = "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch";

    # No patron_ids at all
    $t->post_ok( $url => json => {} )->status_is( 400, 'A body without patron_ids is rejected' );

    # An empty patron_ids list
    $t->post_ok( $url => json => { patron_ids => [] } )->status_is( 400, 'An empty patron_ids list is rejected' );

    # Above the maxItems cap
    $t->post_ok( $url => json => { patron_ids => [ 1 .. 101 ] } )
        ->status_is( 400, 'A patron_ids list above the cap is rejected' );

    # Unknown pickup library
    $t->post_ok( $url => json => { patron_ids => [$patron_id], pickup_library_id => 'nope' } )
        ->json_is( '/error_code' => 'library_not_found' );

    # Unknown record
    my $gone_biblio    = $builder->build_sample_biblio;
    my $gone_biblio_id = $gone_biblio->biblionumber;
    $gone_biblio->delete;

    $t->post_ok( "//$userid:$password@/api/v1/biblios/$gone_biblio_id/holdability/batch" => json =>
            { patron_ids => [$patron_id] } )->status_is( 404, 'An unknown record gives a 404' );

    # A user without the reserveforothers > place_holds permission
    my $unauthorised = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
    $unauthorised->set_password( { password => $password, skip_validation => 1 } );
    my $unauthorised_userid = $unauthorised->userid;

    $t->post_ok( "//$unauthorised_userid:$password@/api/v1/biblios/$biblio_id/holdability/batch" => json =>
            { patron_ids => [$patron_id] } )->status_is( 403, 'A user without place_holds gives a 403' );

    $schema->storage->txn_rollback;
};

subtest 'item_type_id limits the items considered' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    allow_holds();

    my $userid   = build_staff_user();
    my $library  = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons',   value => { branchcode => $library->id } } );
    my $wanted   = $builder->build_object( { class => 'Koha::ItemTypes' } );
    my $unwanted = $builder->build_object( { class => 'Koha::ItemTypes' } );

    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, library => $library->branchcode, itype => $unwanted->itemtype } );

    my $biblio_id = $biblio->biblionumber;
    my $patron_id = $patron->borrowernumber;
    my $url       = "//$userid:$password@/api/v1/biblios/$biblio_id/holdability/batch";

    # The record's only item is of the unwanted type, so filtering to the wanted
    # one leaves nothing to fill the hold.
    $t->post_ok( $url => json => { patron_ids => [$patron_id], item_type_id => $wanted->itemtype } )
        ->status_is(200)
        ->json_is( '/0/blockers' => [ { code => 'no_items', overridable => Mojo::JSON->false } ] );

    # Filtering to the item's own type leaves it holdable, and its id is now
    # resolvable for a per-item entry.
    $t->post_ok(
        $url => json => {
            patron_ids   => [$patron_id],
            item_ids     => [ $item->itemnumber ],
            item_type_id => $unwanted->itemtype,
        }
    )->json_is( '/0/available' => Mojo::JSON->true );

    $schema->storage->txn_rollback;
};
