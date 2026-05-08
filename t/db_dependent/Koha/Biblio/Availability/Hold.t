#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 6;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;

use MARC::Field;
use Koha::Database;
use Koha::Biblio::Availability::Hold;

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
