# Copyright 2015 Catalyst IT
#
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

use Test::More tests => 19;
use Test::NoWarnings;
use Test::MockModule;
use t::lib::Mocks;
use t::lib::TestBuilder;

use Digest::MD5 qw( md5_hex );
use Koha::Caches;

use Koha::Items;
use Test::Warn;
use Koha::SearchEngine;
use Koha::SearchEngine::Elasticsearch::QueryBuilder;
use Koha::SearchEngine::Elasticsearch::Indexer;
use Koha::SearchFields;

{

    package MockESSearchClient;
    sub new    { bless { response => {}, count_response => { count => 0 } }, shift }
    sub search { my ( $self, %args ) = @_; return $self->{response} }
    sub count  { my ( $self, %args ) = @_; return $self->{count_response} }
}

{

    package MockItemsRS;
    sub new   { bless { count => 0 }, shift }
    sub count { return $_[0]->{count} }
}

my $schema = Koha::Database->new()->schema();
$schema->storage->txn_begin;

my $se = Test::MockModule->new('Koha::SearchEngine::Elasticsearch');
$se->mock(
    'get_elasticsearch_mappings',
    sub {
        my ($self) = @_;

        my %all_mappings;

        my $mappings = {
            properties => {
                title                => { type => 'text' },
                title__sort          => { type => 'text' },
                subject              => { type => 'text' },
                itemnumber           => { type => 'integer' },
                sortablenumber       => { type => 'integer' },
                sortablenumber__sort => { type => 'integer' },
                'local-number'       => { type => 'integer' },
                'local-number__sort' => { type => 'integer' },
            }
        };
        $all_mappings{ $self->index } = $mappings;

        my $sort_fields = {
            $self->index => {
                title          => 1,
                subject        => 0,
                itemnumber     => 0,
                sortablenumber => 1
            }
        };
        $self->sort_fields( $sort_fields->{ $self->index } );

        return $all_mappings{ $self->index };
    }
);

my $builder = Koha::SearchEngine::Elasticsearch::QueryBuilder->new( { index => 'mydb' } );

use_ok('Koha::SearchEngine::Elasticsearch::Search');

ok(
    my $searcher =
        Koha::SearchEngine::Elasticsearch::Search->new( { 'nodes' => ['localhost:9200'], 'index' => 'mydb' } ),
    'Creating a Koha::SearchEngine::Elasticsearch::Search object'
);

is( $searcher->index, 'mydb', 'Testing basic accessor' );

ok( my $query = $builder->build_query('easy'), 'Build a search query' );

subtest '_apply_item_level_filters() tests' => sub {
    plan tests => 4;

    my $mock_search = Test::MockModule->new('Koha::SearchEngine::Elasticsearch::Search');
    $mock_search->mock( '_get_matching_biblionumbers', sub { return ( 1, 2, 3 ) } );
    $mock_search->mock( '_items_index_ready',          sub { return 1 } );

    my $searcher = Koha::SearchEngine::Elasticsearch::Search->new(
        { nodes => ['localhost:9200'], index => $Koha::SearchEngine::BIBLIOS_INDEX } );

    # No constraints attached: query untouched
    my $query = { query => { bool => { must => [ { query_string => { query => 'title:foo' } } ] } } };
    $searcher->_apply_item_level_filters($query);
    is(
        $query->{query}{bool}{must}[0]{query_string}{query},
        'title:foo', 'query without item-level constraints is not modified'
    );

    # Constraints present, items index ready: adds an ids filter, query string untouched
    $query = {
        query                   => { bool => { must => [ { query_string => { query => 'available:true' } } ] } },
        _item_level_constraints => [ { available => 1 } ],
    };
    $searcher->_apply_item_level_filters($query);
    ok( exists $query->{query}{bool}{filter}, 'constraints present: adds an ids filter' );
    is_deeply(
        $query->{query}{bool}{filter}[0]{ids}{values},
        [ '1', '2', '3' ],
        'ids filter contains the matching biblionumbers'
    );

    # Items index not ready: no filter added, falls back to the (untouched) query string
    $mock_search->mock( '_items_index_ready', sub { return 0 } );
    $query = {
        query                   => { bool => { must => [ { query_string => { query => 'mc-itype:BOOK' } } ] } },
        _item_level_constraints => [ { field => 'itype', values => ['BOOK'] } ],
    };
    $searcher->_apply_item_level_filters($query);
    ok( !exists $query->{query}{bool}{filter}, 'items index not ready: no filter added, falls back to query string' );
};

subtest '_items_index_ready() tests' => sub {
    plan tests => 9;

    my $mock_es    = Test::MockModule->new('Koha::SearchEngine::Elasticsearch::Search');
    my $mock_items = Test::MockModule->new('Koha::Items');
    my $cache      = Koha::Caches->get_instance();

    my $mock_items_rs = MockItemsRS->new;
    $mock_items->mock( 'search', sub { $mock_items_rs } );

    my $searcher_bib = Koha::SearchEngine::Elasticsearch::Search->new(
        { nodes => ['localhost:9200'], index => $Koha::SearchEngine::BIBLIOS_INDEX } );

    # ES throws (index does not exist yet)
    $cache->clear_from_cache('elasticsearch_items_index_ready');
    $mock_es->mock( 'get_elasticsearch', sub { die "index_not_found_exception\n" } );
    warning_like { is( $searcher_bib->_items_index_ready, 0, 'returns false when ES throws an exception' ) }
    qr/rebuild_elasticsearch/, 'warns when ES throws';

    # Index exists but has no documents
    $cache->clear_from_cache('elasticsearch_items_index_ready');
    my $mock_client = MockESSearchClient->new;
    $mock_es->mock( 'get_elasticsearch', sub { $mock_client } );
    warning_like { is( $searcher_bib->_items_index_ready, 0, 'returns false when items index is empty' ) }
    qr/rebuild_elasticsearch/, 'warns when items index is empty';

    # Index sparsely populated (e.g. single checkout before full rebuild)
    $cache->clear_from_cache('elasticsearch_items_index_ready');
    $mock_client->{count_response} = { count => 1 };
    $mock_items_rs->{count}        = 5000;
    warning_like {
        is(
            $searcher_bib->_items_index_ready, 0,
            'returns false when items index has far fewer documents than DB items'
        )
    }
    qr/rebuild_elasticsearch/, 'warns when items index is sparsely populated';

    # Index fully populated (>= 95% of DB items indexed)
    $cache->clear_from_cache('elasticsearch_items_index_ready');
    $mock_client->{count_response} = { count => 4900 };
    $mock_items_rs->{count}        = 5000;
    is( $searcher_bib->_items_index_ready, 1, 'returns true when items index has >= 95% of DB items' );

    # Cached result: ES not queried on repeat call
    my $es_calls = 0;
    $mock_es->mock( 'get_elasticsearch', sub { $es_calls++; $mock_client } );
    $searcher_bib->_items_index_ready;    # already cached from previous test
    is( $es_calls, 0, 'cached result used on repeat call without querying ES' );

    # Cache miss: ES queried exactly once
    $cache->clear_from_cache('elasticsearch_items_index_ready');
    $es_calls = 0;
    $searcher_bib->_items_index_ready;
    is( $es_calls, 1, 'ES queried exactly once on cache miss' );
};

SKIP: {

    eval { $builder->get_elasticsearch_params; };

    skip 'Elasticsearch configuration not available', 12
        if $@;

    Koha::SearchEngine::Elasticsearch::Indexer->new( { index => 'mydb' } )->drop_index;
    Koha::SearchEngine::Elasticsearch::Indexer->new( { index => 'mydb' } )->create_index;

    ok( my $results = $searcher->search($query), 'Do a search ' );

    is( my $count = $searcher->count($query), 0, 'Get a count of the results, without returning results ' );

    ok( $results = $searcher->search_compat($query), 'Test search_compat' );

    my ( undef, $scan_query ) = $builder->build_query_compat( undef, ['easy'], [], undef, undef, 1 );
    ok(
        ( undef, $results ) = $searcher->search_compat( $scan_query, undef, [], [], 20, 0, undef, undef, undef, 1 ),
        'Test search_compat scan query'
    );
    my $expected = {
        biblioserver => {
            hits    => 0,
            RECORDS => []
        }
    };
    is_deeply( $results, $expected, 'Scan query results ok' );

    ok( ( $results, $count ) = $searcher->search_auth_compat($query), 'Test search_auth_compat' );

    is( $count = $searcher->count_auth_use( $searcher, 1 ), 0, 'Testing count_auth_use' );

    is( $searcher->max_result_window, 1000000, 'By default, max_result_window is 1000000' );

    $searcher->get_elasticsearch()->indices->put_settings(
        index => $searcher->index_name,
        body  => {
            'index' => {
                'max_result_window' => 12000,
            },
        }
    );
    is( $searcher->max_result_window, 12000, 'max_result_window returns the correct value' );

    subtest "_convert_facets" => sub {
        plan tests => 7;

        $schema->storage->txn_begin;
        my $builder = t::lib::TestBuilder->new;

        my $es_facets = {
            'ln' => {
                'sum_other_doc_count' => 0,
                'buckets'             => [
                    {
                        'doc_count' => 2,
                        'key'       => 'eng'
                    },
                    {
                        'doc_count' => 12,
                        'key'       => ''
                    }
                ],
                'doc_count_error_upper_bound' => 0
            }
        };

        my $koha_facets = $searcher->_convert_facets($es_facets);
        is( @{ $koha_facets->[0]->{facets} }, 1, "We only get one facet, blank is removed" );

        $es_facets->{ln}->{buckets}->[1]->{key} = '0';
        $koha_facets = $searcher->_convert_facets($es_facets);
        is( @{ $koha_facets->[0]->{facets} }, 2,     "We get two facets, '0' is not removed" );
        is( $koha_facets->[0]->{av_cat},      undef, "Not linked with an authorised value category" );

        my $av_cat = $builder->build_object( { class => 'Koha::AuthorisedValueCategories' } );
        Koha::SearchFields->find( { name => 'ln' } )->update( { authorised_value_category => $av_cat->category_name } );
        $builder->build_object(
            {
                class => 'Koha::AuthorisedValues',
                value => { category => $av_cat->category_name, authorised_value => 'eng', lib_opac => 'English' }
            }
        );
        $koha_facets = $searcher->_convert_facets($es_facets);
        is( $koha_facets->[0]->{av_cat}, $av_cat->category_name, "Linked with an authorised value category" );
        is(
            $koha_facets->[0]->{facets}->[1]->{facet_label_value}, "English",
            "Value of the facet replaced with AV's description"
        );

        # biblio_count present: use biblio_count{value} not doc_count
        my $es_facets_bc = {
            'itype' => {
                'sum_other_doc_count'         => 0,
                'doc_count_error_upper_bound' => 0,
                'buckets'                     => [
                    { 'key' => 'BK', 'doc_count' => 10, 'biblio_count' => { 'value' => 3 } },
                ],
            }
        };
        my $koha_facets_bc = $searcher->_convert_facets($es_facets_bc);
        is(
            $koha_facets_bc->[0]->{facets}->[0]->{facet_count}, 3,
            'biblio_count present: facet_count uses biblio_count{value}'
        );

        # biblio_count absent: fall back to doc_count
        my $es_facets_dc = {
            'itype' => {
                'sum_other_doc_count'         => 0,
                'doc_count_error_upper_bound' => 0,
                'buckets'                     => [
                    { 'key' => 'BK', 'doc_count' => 10 },
                ],
            }
        };
        my $koha_facets_dc = $searcher->_convert_facets($es_facets_dc);
        is(
            $koha_facets_dc->[0]->{facets}->[0]->{facet_count}, 10,
            'biblio_count absent: facet_count falls back to doc_count'
        );

        $schema->storage->txn_rollback;

    };

    subtest '_get_matching_biblionumbers() tests' => sub {
        plan tests => 5;

        my $cache        = Koha::Caches->get_instance();
        my $groups       = [ { field => 'itype', values => ['BOOK'] }, { available => 1 } ];
        my $other_groups = [ { field => 'itype', values => ['AUDIO'] } ];
        my $key          = 'elasticsearch_item_level_filter_'
            . md5_hex( Koha::SearchEngine::Elasticsearch::Search::_item_level_groups_cache_key($groups) );
        my $other_key = 'elasticsearch_item_level_filter_'
            . md5_hex( Koha::SearchEngine::Elasticsearch::Search::_item_level_groups_cache_key($other_groups) );
        $cache->clear_from_cache($key);
        $cache->clear_from_cache($other_key);

        my $mock_es     = Test::MockModule->new('Koha::SearchEngine::Elasticsearch');
        my $mock_client = MockESSearchClient->new;
        my $es_calls    = 0;
        $mock_es->mock(
            'get_elasticsearch',
            sub {
                $es_calls++;
                return $mock_client;
            }
        );

        $mock_client->{response} = {
            aggregations => {
                by_biblio => { buckets => [ { key => { biblionumber => 10 } }, { key => { biblionumber => 20 } } ] }
            }
        };

        my @bns = $searcher->_get_matching_biblionumbers($groups);
        is( scalar @bns, 2, '_get_matching_biblionumbers returns one entry per bucket' );
        is_deeply( [ sort { $a <=> $b } @bns ], [ 10, 20 ], 'correct biblionumbers returned' );
        is( $es_calls, 1, 'ES queried on cache miss' );

        # Same constraint set: cached result used, no new ES call
        $searcher->_get_matching_biblionumbers($groups);
        is( $es_calls, 1, 'ES not queried again for the same constraint set' );

        # Different constraint set: cache key differs, ES queried again
        $searcher->_get_matching_biblionumbers($other_groups);
        is( $es_calls, 2, 'ES queried again for a different constraint set' );

        $cache->clear_from_cache($key);
        $cache->clear_from_cache($other_key);
    };

    subtest '_get_item_facets() tests' => sub {
        plan tests => 7;

        my $cache = Koha::Caches->get_instance();
        $cache->clear_from_cache( 'elasticsearch_item_facets_' . md5_hex( join( ',', 1, 2, 3 ) ) );
        $cache->clear_from_cache( 'elasticsearch_item_facets_' . md5_hex( join( ',', 4, 5 ) ) );

        my $mock_es     = Test::MockModule->new('Koha::SearchEngine::Elasticsearch');
        my $mock_client = MockESSearchClient->new;
        my $es_calls    = 0;
        $mock_es->mock(
            'get_elasticsearch',
            sub {
                $es_calls++;
                return $mock_client;
            }
        );

        my $result = $searcher->_get_item_facets( [] );
        is_deeply( $result, {}, '_get_item_facets with empty list returns empty hashref' );
        is( $es_calls, 0, 'empty list short-circuits without querying ES' );

        $mock_client->{response} = {
            aggregations => {
                itype    => { buckets => [ { key => 'BK', doc_count => 5 } ] },
                location => { buckets => [] },
            }
        };

        $result = $searcher->_get_item_facets( [ 1, 2, 3 ] );
        ok( exists $result->{itype},    '_get_item_facets returns itype aggregation' );
        ok( exists $result->{location}, '_get_item_facets returns location aggregation' );
        is( $es_calls, 1, 'ES queried on cache miss' );

        # Same biblionumber set: cached result used, no new ES call
        $searcher->_get_item_facets( [ 1, 2, 3 ] );
        is( $es_calls, 1, 'ES not queried again for the same biblionumber set' );

        # Different biblionumber set: cache key differs, ES queried again
        $searcher->_get_item_facets( [ 4, 5 ] );
        is( $es_calls, 2, 'ES queried again for a different biblionumber set' );

        $cache->clear_from_cache( 'elasticsearch_item_facets_' . md5_hex( join( ',', 1, 2, 3 ) ) );
        $cache->clear_from_cache( 'elasticsearch_item_facets_' . md5_hex( join( ',', 4, 5 ) ) );
    };
}
