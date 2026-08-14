#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 9;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;
use t::lib::QueryCounter;

use MARC::Field;
use Koha::Database;
use Koha::Biblio::Availability::Hold;
use Koha::CirculationRules;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Patron ineligible blocks before item loop' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { gonenoaddress => 1 } } );
    my $biblio = $builder->build_sample_biblio;
    $builder->build_sample_item( { biblionumber => $biblio->biblionumber } );

    my $result = Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );

    ok( !$result->available,              'Not available when patron has bad address' );
    ok( $result->blockers->{bad_address}, 'bad_address blocker set' );

    $schema->storage->txn_rollback;
};

subtest 'Returns available when at least one item is holdable' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    # One damaged, one good
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );
    my $good_item = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 0, library => $library->branchcode } );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 10, holds_per_record => 10 }
        }
    );

    my $result = Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );

    ok( $result->available, 'Available when at least one item is holdable' );
    is( $result->context->{available_item}->itemnumber, $good_item->itemnumber, 'Context has the available item' );

    $schema->storage->txn_rollback;
};

subtest 'no_item_available when all items blocked' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );
    $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 10, holds_per_record => 10 }
        }
    );

    my $result = Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );

    ok( !$result->available,                    'Not available when all items are damaged' );
    ok( $result->blockers->{no_item_available}, 'no_item_available blocker set' );

    $schema->storage->txn_rollback;
};

subtest 'no_items when biblio has no items' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $biblio = $builder->build_sample_biblio;

    my $result = Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );

    ok( !$result->available,           'Not available when biblio has no items' );
    ok( $result->blockers->{no_items}, 'no_items blocker set' );

    $schema->storage->txn_rollback;
};

subtest 'Host items (analytics) are considered' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'EasyAnalyticalRecords', 1 );
    t::lib::Mocks::mock_preference( 'marcflavour',           'MARC21' );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );

    # Biblio with no items of its own
    my $biblio = $builder->build_sample_biblio;

    # Host biblio with an item
    my $host_biblio = $builder->build_sample_biblio;
    my $host_item =
        $builder->build_sample_item( { biblionumber => $host_biblio->biblionumber, library => $library->branchcode } );

    # Add 773 field linking to host item
    my $record = $biblio->metadata->record;
    $record->append_fields(
        MARC::Field->new( '773', '0', ' ', '0' => $host_biblio->biblionumber, '9' => $host_item->itemnumber ) );
    $biblio->metadata->metadata( $record->as_xml_record('MARC21') )->store;

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 10, holds_per_record => 10 }
        }
    );

    my $result = Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );

    ok( $result->available, 'Available via host item when biblio has no own items' );
    is( $result->context->{available_item}->itemnumber, $host_item->itemnumber, 'Host item found' );

    $schema->storage->txn_rollback;
};

=head2 build_biblio_held_throughout

    my ( $biblio, $patron ) = build_biblio_held_throughout($n_items);

Builds a biblio whose every item the patron already holds, so that each item's
check reaches (and is blocked by) item_already_on_hold.

The circulation rules must be permissive here. holds_per_record defaults to 1,
so without a rule the patron trips too_many_holds_for_this_record and the check
returns before the item loop ever runs - which would make any assertion about
per-item query counts meaningless.

=cut

sub build_biblio_held_throughout {
    my ($n_items) = @_;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    for ( 1 .. $n_items ) {
        my $item =
            $builder->build_sample_item( { biblionumber => $biblio->biblionumber, library => $library->branchcode } );
        $builder->build_object(
            {
                class => 'Koha::Holds',
                value => {
                    itemnumber     => $item->itemnumber,
                    borrowernumber => $patron->borrowernumber,
                    biblionumber   => $biblio->biblionumber,
                }
            }
        );
    }

    t::lib::Mocks::mock_preference( 'maxreserves',    0 );
    t::lib::Mocks::mock_preference( 'maxoutstanding', 0 );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 1000, holds_per_record => 1000 }
        }
    );

    return ( $biblio, $patron );
}

subtest 'Query count stays flat as item count scales (bug 43124)' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    # Every item is already held by the patron, so each item's check reaches
    # (and is blocked by) item_already_on_hold - this, together with age
    # restriction, is precomputed once per biblio rather than queried per
    # item. If either regresses back to a per-item query, query count grows
    # with item count instead of staying flat.
    my $count_queries = sub {
        my ($n_items) = @_;

        my ( $biblio, $patron ) = build_biblio_held_throughout($n_items);

        my ( $result, $stats ) = t::lib::QueryCounter->measure(
            sub {
                return Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );
            }
        );

        return ( $result, $stats->{queries} );
    };

    my ( $result_10,  $queries_10 )  = $count_queries->(10);
    my ( $result_100, $queries_100 ) = $count_queries->(100);

    ok( !$result_10->available && !$result_100->available, 'Sanity: both runs correctly find no available item' )
        or diag("queries for 10 items: $queries_10, queries for 100 items: $queries_100");

    # Without this, a patron-level blocker can return before the item loop and
    # leave the query count trivially flat, so the assertion below would hold
    # even if the per-item work had regressed entirely.
    is(
        scalar @{ $result_100->context->{item_failures} // [] }, 100,
        'Sanity: the item loop ran for every item'
    );

    # A regression to per-item queries for either optimization would add
    # roughly 2 extra queries per extra item (90 extra items here) - a
    # generous absolute delta catches that while tolerating the couple of
    # genuinely per-item-type/branch queries (e.g. circulation rule lookups)
    # that are already cached elsewhere but not eliminated by this bug.
    cmp_ok( $queries_100 - $queries_10, '<', 20, 'Query count does not scale with item count (10 vs 100 items)' );

    $schema->storage->txn_rollback;
};

subtest 'summarise_items reports every item (bug 43126)' => sub {
    plan tests => 9;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AllowHoldsOnDamagedItems', 0 );

    my $library = $builder->build_object( { class => 'Koha::Libraries', value => { pickup_location => 1 } } );
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library->branchcode } } );
    my $biblio = $builder->build_sample_biblio;

    my $damaged = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 1, library => $library->branchcode } );
    my $good = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 0, library => $library->branchcode } );
    my $also_good = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, damaged => 0, library => $library->branchcode } );

    Koha::CirculationRules->set_rules(
        {
            categorycode => undef,
            branchcode   => undef,
            itemtype     => undef,
            rules        => { reservesallowed => 10, holds_per_record => 10 }
        }
    );

    # Without the option, the loop still stops at the first holdable item
    my $short = Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );

    ok( $short->available, 'Available without summarise_items' );
    is( $short->context->{item_results}, undef, 'No item_results without summarise_items' );

    my $result =
        Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron, summarise_items => 1 } );

    ok( $result->available, 'Still available with summarise_items' );

    my $item_results = $result->context->{item_results};

    is( scalar @{$item_results}, 3, 'One entry for each item on the record' );

    my %by_itemnumber = map { $_->{itemnumber} => $_ } @{$item_results};

    is( $by_itemnumber{ $damaged->itemnumber }->{available}, 0, 'The damaged item is reported as not available' );
    is( $by_itemnumber{ $damaged->itemnumber }->{blockers}->{damaged}, 1, 'The damaged item carries its blocker' );
    is( $by_itemnumber{ $good->itemnumber }->{available},              1, 'The good item is reported as available' );
    is( $by_itemnumber{ $also_good->itemnumber }->{available},         1, 'The second good item is reported too' );

    is(
        $result->context->{available_item}->itemnumber, $good->itemnumber,
        'available_item is still the first holdable item'
    );

    $schema->storage->txn_rollback;
};

subtest 'summarise_items keeps the query count flat (bug 43126)' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    # Same shape as the bug 43124 subtest above, but with summarise_items on.
    # The option must not defeat the prefetched patron/biblio context: the
    # extra items it checks may cost their own per-item queries, but the
    # per-biblio context must still be fetched once.
    my $count_queries = sub {
        my ($n_items) = @_;

        my ( $biblio, $patron ) = build_biblio_held_throughout($n_items);

        my ( $result, $stats ) = t::lib::QueryCounter->measure(
            sub {
                return Koha::Biblio::Availability::Hold->check(
                    { biblio => $biblio, patron => $patron, summarise_items => 1 } );
            }
        );

        return ( $result, $stats->{queries} );
    };

    my ( $result_10,  $queries_10 )  = $count_queries->(10);
    my ( $result_100, $queries_100 ) = $count_queries->(100);

    is(
        scalar @{ $result_100->context->{item_results} }, 100,
        'Sanity: every item was checked and reported'
    ) or diag("queries for 10 items: $queries_10, queries for 100 items: $queries_100");

    cmp_ok(
        $queries_100 - $queries_10, '<', 20,
        'Query count does not scale with item count when summarise_items is on'
    );

    $schema->storage->txn_rollback;
};
