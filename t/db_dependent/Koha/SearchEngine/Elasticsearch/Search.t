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

use Test::More tests => 18;
use Test::NoWarnings;
use Test::MockModule;
use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::SearchEngine;
use Koha::SearchEngine::Elasticsearch::QueryBuilder;
use Koha::SearchEngine::Elasticsearch::Indexer;
use Koha::SearchFields;

{

    package MockESSearchClient;
    sub new    { bless { response => {} }, shift }
    sub search { my ( $self, %args ) = @_; return $self->{response} }
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

subtest '_apply_available_filter() tests' => sub {
    plan tests => 4;

    my $mock_search = Test::MockModule->new('Koha::SearchEngine::Elasticsearch::Search');
    $mock_search->mock( '_get_available_biblionumbers', sub { return ( 1, 2, 3 ) } );

    my $searcher = Koha::SearchEngine::Elasticsearch::Search->new(
        { nodes => ['localhost:9200'], index => $Koha::SearchEngine::BIBLIOS_INDEX } );

    my $query = { query => { bool => { must => [ { query_string => { query => 'title:foo' } } ] } } };
    $searcher->_apply_available_filter($query);
    is(
        $query->{query}{bool}{must}[0]{query_string}{query},
        'title:foo', 'query without available:true is not modified'
    );

    $query = { query => { bool => { must => [ { query_string => { query => 'available:true' } } ] } } };
    $searcher->_apply_available_filter($query);
    ok( exists $query->{query}{bool}{filter}, 'available:true rewrite adds a filter' );
    is( $query->{query}{bool}{must}[0]{query_string}{query}, '*', 'available:true stripped from query string' );

    $query = {
        query => {
            bool => {
                must => [
                    { query_string => { query => 'title:foo' } },
                    { query_string => { query => 'available:true' } },
                ]
            }
        }
    };
    $searcher->_apply_available_filter($query);
    ok( exists $query->{query}{bool}{filter}, 'available:true found and rewritten when not at must[0]' );
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
        plan tests => 5;

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

        $schema->storage->txn_rollback;

    };

    subtest '_get_available_biblionumbers() tests' => sub {
        plan tests => 2;

        my $mock_es     = Test::MockModule->new('Koha::SearchEngine::Elasticsearch');
        my $mock_client = MockESSearchClient->new;
        $mock_es->mock( 'get_elasticsearch', sub { $mock_client } );

        $mock_client->{response} = { aggregations => { by_biblio => { buckets => [ { key => 10 }, { key => 20 } ] } } };

        my @bns = $searcher->_get_available_biblionumbers();
        is( scalar @bns, 2, '_get_available_biblionumbers returns one entry per bucket' );
        is_deeply( [ sort { $a <=> $b } @bns ], [ 10, 20 ], 'correct biblionumbers returned' );
    };

    subtest '_get_item_facets() tests' => sub {
        plan tests => 3;

        my $mock_es     = Test::MockModule->new('Koha::SearchEngine::Elasticsearch');
        my $mock_client = MockESSearchClient->new;
        $mock_es->mock( 'get_elasticsearch', sub { $mock_client } );

        my $result = $searcher->_get_item_facets( [] );
        is_deeply( $result, {}, '_get_item_facets with empty list returns empty hashref' );

        $mock_client->{response} = {
            aggregations => {
                itype    => { buckets => [ { key => 'BK', doc_count => 5 } ] },
                location => { buckets => [] },
            }
        };

        $result = $searcher->_get_item_facets( [ 1, 2, 3 ] );
        ok( exists $result->{itype},    '_get_item_facets returns itype aggregation' );
        ok( exists $result->{location}, '_get_item_facets returns location aggregation' );
    };
}
