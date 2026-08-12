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

=head1 NAME

holdability_benchmark.t - Performance harness for the hold availability checks

=head1 DESCRIPTION

This is the performance harness for bug 43126. It measures the query count and
the run time of a hold availability check against biblios of several sizes. It
uses L<t::lib::QueryCounter>, which has its own tests in
F<t/db_dependent/QueryCounter.t>.

The first subtest records the present-day figures for the legacy
C<CanBookBeReserved> call and the C<CanItemBeReserved> loop that the new
endpoints replace. Read those figures with C<prove -v>, and then copy them into
the Performance Budgets table on the bug. They are the numbers that the p95
targets are measured against.

Each new endpoint then adds a subtest of its own. Every subtest prints its
figures through C<diag_figures>, so the tables share their columns and can be
read against the baseline one.

=head1 NOTE

This test builds every record size twice, once for each subtest, so about 1700
items in all. It is therefore slower than a normal unit test.

=cut

use Modern::Perl;

use Test::More tests => 5;
use Test::NoWarnings;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;
use t::lib::QueryCounter;

use C4::Reserves qw( CanBookBeReserved CanItemBeReserved );

use Koha::Cache::Memory::Lite;
use Koha::CirculationRules;
use Koha::Database;
use Koha::Libraries;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';

# Every subtest measures the same record sizes, so that one table can be read
# against another row by row. 10, 50, 100 and 500 are the sizes the bug 43126
# specification asks for; 200 is the size its p95 target names.
my @ITEM_COUNTS = ( 10, 50, 100, 200, 500 );

# The batch endpoint varies the number of patrons asked about rather than the
# size of the record, so it walks its own list. 50 is the size the bug 43126
# specification names for a club check.
my @PATRON_COUNTS = ( 1, 10, 50 );

=head2 build_biblio_with_items

    my ( $biblio, $patron, $items ) = build_biblio_with_items($item_count);

Builds one biblio with I<$item_count> items, and one patron who is able to place
a hold on them. The caller must run this inside a transaction.

=cut

sub build_biblio_with_items {
    my ($item_count) = @_;

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    my @items = map {
        $builder->build_sample_item(
            {
                biblionumber => $biblio->biblionumber,
                library      => $library->branchcode,
                damaged      => 0,
            }
        )
    } ( 1 .. $item_count );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => {
                reservesallowed  => 100,
                holds_per_record => 100,
            }
        }
    );

    return ( $biblio, $patron, \@items );
}

=head2 diag_figures

    diag_figures( $title, \@counts, \%figures );
    diag_figures( $title, \@counts, \%figures, 'patrons' );

Prints one measurement as a table. I<%figures> holds the stats hashref that
L<t::lib::QueryCounter/measure> returned, keyed on the count that varies.

I<$unit> names what that count counts, and defaults to C<items>. Most subtests
here vary the size of the record; the batch one varies the number of patrons
asked about instead.

Every table in this file goes through here, so that the columns stay the same
from one to the next and a reader can hold two of them side by side.

=cut

sub diag_figures {
    my ( $title, $counts, $figures, $unit ) = @_;

    $unit //= 'items';

    my $singular = $unit;
    $singular =~ s{s$}{};

    diag('');
    diag($title);
    diag( sprintf( '  %-8s %-10s %-12s %s', $unit, 'queries', 'time (ms)', "queries/$singular" ) );

    for my $count ( @{$counts} ) {
        my $stats = $figures->{$count};
        diag(
            sprintf(
                '  %-8d %-10d %-12.1f %.2f',
                $count, $stats->{queries}, $stats->{elapsed_ms},
                $stats->{queries} / $count
            )
        );
    }

    diag('');

    return;
}

subtest 'Baseline: CanBookBeReserved plus a CanItemBeReserved loop' => sub {
    plan tests => 1 + scalar @ITEM_COUNTS;

    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems',       0 );
    t::lib::Mocks::mock_preference( 'AllowHoldsOnPatronsPossessions', 0 );

    my %figures;

    for my $item_count (@ITEM_COUNTS) {

        $schema->storage->txn_begin;

        my ( $biblio, $patron, $items ) = build_biblio_with_items($item_count);

        # Each run must start from the same state. The request-lifetime memory
        # cache holds circulation rules and CanItemBeReserved results from the
        # previous run, which would otherwise hide queries.
        Koha::Cache::Memory::Lite->get_instance()->flush();

        my ( undef, $stats ) = t::lib::QueryCounter->measure(
            sub {
                CanBookBeReserved( $patron->borrowernumber, $biblio->biblionumber );
                CanItemBeReserved( $patron, $_ ) for @{$items};
                return;
            }
        );

        $figures{$item_count} = $stats;

        ok( $stats->{queries} > 0, "Baseline measured for $item_count items" );

        $schema->storage->txn_rollback;
    }

    diag_figures( 'Baseline: CanBookBeReserved + CanItemBeReserved loop (present-day code)', \@ITEM_COUNTS, \%figures );

    # The legacy per-item loop issues a fresh set of queries for every item, so
    # its query count grows with the item count. This assertion records that
    # growth as the problem that bug 43126 addresses. The new endpoints must not
    # show it.
    cmp_ok(
        $figures{500}->{queries}, '>', $figures{10}->{queries} * 5,
        'Baseline query count grows with the item count'
    );
};

=head2 build_staff_user

    my $userid = build_staff_user();

Builds a staff user that holds the reserveforothers > place_holds permission,
which the holdability endpoints need, and the catalogue flag, which
C<GET /biblios/{biblio_id}/items> needs on top of it.

=cut

sub build_staff_user {

    my $staff = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 4 } } );

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

subtest 'GET /biblios/{biblio_id}/holdability' => sub {

    # Two warm-up assertions for each record size, plus the four below
    plan tests => ( 2 * scalar @ITEM_COUNTS ) + 4;

    my %figures;

    my $measure = sub {
        my ($item_count) = @_;

        $schema->storage->txn_begin;

        my $userid = build_staff_user();
        my ( $biblio, $patron ) = build_biblio_with_items($item_count);

        my $biblio_id = $biblio->biblionumber;
        my $patron_id = $patron->borrowernumber;
        my $url       = "//$userid:$password\@/api/v1/biblios/$biblio_id/holdability?patron_id=$patron_id";

        # Warm the request path once. The first call through Mojolicious pays
        # for lazy loading that has nothing to do with the availability checks,
        # and would otherwise land entirely on the smallest item count.
        $t->get_ok($url)->status_is(200);

        Koha::Cache::Memory::Lite->get_instance()->flush();

        # Send the measured request through the plain user agent rather than
        # get_ok. A test assertion inside the measured block would put the
        # Test::More machinery into the timing.
        my $body;
        my ( undef, $stats ) = t::lib::QueryCounter->measure( sub { $body = $t->ua->get($url)->res->json; return } );

        $schema->storage->txn_rollback;

        return { %{$stats}, total => $body->{items}->{total}, holdable => $body->{items}->{holdable} };
    };

    $figures{$_} = $measure->($_) for @ITEM_COUNTS;

    diag_figures( 'GET /biblios/{biblio_id}/holdability', \@ITEM_COUNTS, \%figures );

    # The holdable count is not in the table above, because that table exists to
    # be read against the baseline one. It is asserted instead.
    is( $figures{200}->{total},    200, 'Sanity: every item on the 200-item record was checked' );
    is( $figures{200}->{holdable}, 200, 'Sanity: every item on the 200-item record was holdable' );

    # The 200 ms p95 target for a 200-item record is met with room to spare.
    # Wall-clock in KTD is noisy and shares the box with the database, so assert
    # at twice the budget rather than at it - a test that fails on a busy build
    # machine teaches nobody anything. The diag table above, not this assertion,
    # is the figure to quote.
    cmp_ok(
        $figures{200}->{elapsed_ms}, '<', 400,
        'A 200-item record stays within twice the 200 ms budget'
    );

    # The query count is flat: the same queries answer a 10-item record and a
    # 200-item one. Anything that reintroduces per-item work - a context read
    # moved back inside the loop, or a rule lookup that stops hitting the memo
    # cache - shows up here immediately, because 90 extra items would add 90 or
    # more queries.
    is(
        $figures{500}->{queries}, $figures{10}->{queries},
        'Query count is identical for a 10-item and a 500-item record'
    );
};

subtest 'GET /biblios/{biblio_id}/items?holdability=true' => sub {

    # Two warm-up assertions for each record size, plus the four below
    plan tests => ( 2 * scalar @ITEM_COUNTS ) + 4;

    my $per_page = 20;
    my %figures;

    my $measure = sub {
        my ($item_count) = @_;

        $schema->storage->txn_begin;

        my $userid = build_staff_user();
        my ( $biblio, $patron ) = build_biblio_with_items($item_count);

        my $biblio_id = $biblio->biblionumber;
        my $patron_id = $patron->borrowernumber;
        my $url       = "//$userid:$password\@/api/v1/biblios/$biblio_id/items"
            . "?holdability=1&patron_id=$patron_id&_per_page=$per_page&_order_by=item_id";

        $t->get_ok($url)->status_is(200);

        Koha::Cache::Memory::Lite->get_instance()->flush();

        my $body;
        my ( undef, $stats ) = t::lib::QueryCounter->measure( sub { $body = $t->ua->get($url)->res->json; return } );

        $schema->storage->txn_rollback;

        return { %{$stats}, returned => scalar @{$body} };
    };

    $figures{$_} = $measure->($_) for @ITEM_COUNTS;

    diag_figures( "GET /biblios/{biblio_id}/items?holdability=true (_per_page=$per_page)", \@ITEM_COUNTS, \%figures );

    # The queries/item column above is per item ON THE RECORD, not per item
    # returned, so it falls away as the record grows. That is the point: the
    # cost follows the page size, not the record size.
    is( $figures{500}->{returned}, $per_page, "A 500-item record still returns one page of $per_page items" );

    # The p95 target for a page of 20 items with holdability embedded is 300 ms.
    # Assert at twice the budget, for the same reason as the subtest above.
    cmp_ok(
        $figures{500}->{elapsed_ms}, '<', 600,
        'A page of a 500-item record stays within twice the 300 ms budget'
    );

    # Compare two records that both fill a page. The 10-item record returns only
    # 10 items, so it does less work and is not comparable - the cost follows
    # the number of items returned, which is exactly the intended behaviour.
    is( $figures{10}->{returned}, 10, 'A 10-item record returns all 10, being smaller than a page' );

    is(
        $figures{500}->{queries}, $figures{50}->{queries},
        'Query count does not grow with the size of the record behind the page'
    );
};

subtest 'POST /biblios/{biblio_id}/holdability/batch' => sub {

    # Two warm-up assertions for each patron count, plus the two below
    plan tests => ( 2 * scalar @PATRON_COUNTS ) + 2;

    my $item_count = 100;
    my %figures;

    $schema->storage->txn_begin;

    my $userid = build_staff_user();
    my ( $biblio, undef ) = build_biblio_with_items($item_count);

    my $library = Koha::Libraries->find( $biblio->items->next->homebranch );

    my @patrons =
        map { $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } ) }
        ( 1 .. $PATRON_COUNTS[-1] );

    my $biblio_id = $biblio->biblionumber;
    my $url       = "//$userid:$password\@/api/v1/biblios/$biblio_id/holdability/batch";

    for my $patron_count (@PATRON_COUNTS) {

        my $payload = { patron_ids => [ map { $_->borrowernumber } @patrons[ 0 .. $patron_count - 1 ] ] };

        # Warm the request path once, as the subtests above do
        $t->post_ok( $url => json => $payload )->status_is(200);

        Koha::Cache::Memory::Lite->get_instance()->flush();

        my ( undef, $stats ) =
            t::lib::QueryCounter->measure( sub { $t->ua->post( $url => json => $payload ); return } );

        $figures{$patron_count} = $stats;
    }

    $schema->storage->txn_rollback;

    diag_figures(
        "POST /biblios/{biblio_id}/holdability/batch (a record of $item_count items)",
        \@PATRON_COUNTS, \%figures, 'patrons'
    );

    # Each patron still needs its own eligibility and count checks, so the total
    # grows with the number of patrons. What must not grow is the record work:
    # fetch_items runs once for the whole request, not once per patron.
    cmp_ok(
        $figures{ $PATRON_COUNTS[-1] }->{queries}, '<',
        $figures{1}->{queries} * $PATRON_COUNTS[-1],
        'A batch costs less than the same number of single-patron calls'
    );

    my $item_fetches = () =
        $figures{ $PATRON_COUNTS[-1] }->{trace} =~ /FROM `items` `me` WHERE \( `me`\.`biblionumber` = \? \):/g;

    is( $item_fetches, 1, 'The record item list is read once, however many patrons are asked about' );
};
