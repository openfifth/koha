#!/usr/bin/perl
use Modern::Perl;
use Time::HiRes qw( time );
use List::Util  qw( sum min max );
use Digest::MD5;
use MARC::Record;
use MARC::File::XML;
use Koha::Database;
use Koha::Caches;
use Koha::SearchEngine;
use Koha::SearchEngine::QueryBuilder;
use Koha::SearchEngine::Elasticsearch::Search;

my $N_BIBLIOS           = 9_000;                 # matches search_compat's aggregations{_biblionumbers}{terms}{size}
my $ITEMS_EACH          = 3;
my $ITERATIONS          = 20;
my $AUTHOR_TAG          = 'DemoFacetsLatency';
my $ACCEPTABLE_TOTAL_MS = 100;                   # rough "still feels instant" budget for a single backend search call

my $schema = Koha::Database->new->schema;

say "=== Seeding $N_BIBLIOS synthetic biblios (\@ $ITEMS_EACH items each) ===";
seed();

say "=== Rebuilding Elasticsearch biblios + items indexes ===";
system('perl misc/search_tools/rebuild_elasticsearch.pl --biblios --items --reset 2>/dev/null');
Koha::Caches->get_instance->flush_all;

say "=== Benchmarking search_compat()'s facets overhead ($ITERATIONS iterations each) ===";
benchmark();

say "=== Cleaning up synthetic data and rebuilding indexes back to normal ===";
cleanup();

exit 0;

sub seed {
    $schema->storage->dbh->do(
        qq{
        INSERT INTO biblio (frameworkcode, author, title, datecreated)
        SELECT 'BKS', '$AUTHOR_TAG', CONCAT('$AUTHOR_TAG ', n), NOW()
        FROM (
            SELECT (a.N + b.N*10 + c.N*100 + d.N*1000) AS n
            FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                  UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
            CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
            CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
            CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8) d
        ) nums
        WHERE n < $N_BIBLIOS
    }
    );

    my $rs = $schema->resultset('Biblio')->search( { author => $AUTHOR_TAG } );
    while ( my $b = $rs->next ) {
        my $record = MARC::Record->new();
        $record->encoding('UTF-8');
        $record->append_fields(
            MARC::Field->new( '999', ' ', ' ', c => $b->biblionumber, d => $b->biblionumber ),
            MARC::Field->new( '245', ' ', ' ', a => $b->title ),
            MARC::Field->new( '100', ' ', ' ', a => $b->author ),
            MARC::Field->new( '942', ' ', ' ', c => 'BK' ),
        );
        $schema->resultset('BiblioMetadata')->create(
            {
                biblionumber => $b->biblionumber,
                format       => 'marcxml',
                schema       => 'MARC21',
                metadata     => $record->as_xml(),
            }
        );
    }

    $schema->storage->dbh->do(
        qq{
        INSERT INTO biblioitems (biblionumber, itemtype)
        SELECT biblionumber, 'BK' FROM biblio WHERE author = '$AUTHOR_TAG'
    }
    );

    $schema->storage->dbh->do(
        qq{
        INSERT INTO items (biblionumber, biblioitemnumber, barcode, homebranch, holdingbranch,
                            itype, dateaccessioned, notforloan, itemlost, withdrawn, damaged)
        SELECT bi.biblionumber, bi.biblioitemnumber,
               CONCAT('DFL', bi.biblioitemnumber, '_', seq.n),
               'CPL', 'CPL', 'BK', NOW(), 0, 0, 0, 0
        FROM biblioitems bi
        JOIN biblio b ON b.biblionumber = bi.biblionumber
        CROSS JOIN (SELECT 1 n UNION SELECT 2 UNION SELECT 3) seq
        WHERE b.author = '$AUTHOR_TAG' AND seq.n <= $ITEMS_EACH
    }
    );
}

sub cleanup {
    $schema->storage->dbh->do(
        qq{DELETE FROM items WHERE biblionumber IN (SELECT biblionumber FROM biblio WHERE author = '$AUTHOR_TAG')});
    $schema->storage->dbh->do(
        qq{DELETE FROM biblioitems WHERE biblionumber IN (SELECT biblionumber FROM biblio WHERE author = '$AUTHOR_TAG')}
    );
    $schema->storage->dbh->do(
        qq{DELETE FROM biblio_metadata WHERE biblionumber IN (SELECT biblionumber FROM biblio WHERE author = '$AUTHOR_TAG')}
    );
    $schema->storage->dbh->do(qq{DELETE FROM biblio WHERE author = '$AUTHOR_TAG'});
    system('perl misc/search_tools/rebuild_elasticsearch.pl --biblios --items --reset 2>/dev/null');
}

sub timed(&) {
    my $code   = shift;
    my $t0     = time;
    my $result = $code->();
    return ( time - $t0, $result );
}

sub stats {
    my @xs = sort { $a <=> $b } @_;
    my $n  = scalar @xs;
    return ( min(@xs), $xs[ int( $n / 2 ) ], sum(@xs) / $n, max(@xs) );
}

sub benchmark {
    my $qb = Koha::SearchEngine::QueryBuilder->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );
    my ( undef, $query ) = $qb->build_query_compat( undef, [$AUTHOR_TAG], undef, undef, undef, undef, undef );
    my $searcher = Koha::SearchEngine::Elasticsearch::Search->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );

    # A/B/C are interleaved within each iteration (not run as three sequential blocks) so that
    # drift over the run's lifetime (ES cache warmup, background load) hits all three arms
    # equally instead of biasing the B-minus-A / C deltas.
    my ( @a_times, @b_times, @c_times, @all_biblionumbers );

    for ( 1 .. $ITERATIONS ) {
        my $qa = { %$query, aggregations => { %{ $query->{aggregations} } } };
        my ($ta) = timed { $searcher->search( $qa, undef, 20, ( offset => 0 ) ) };
        push @a_times, $ta;

        my $qb = {
            %$query,
            aggregations => {
                %{ $query->{aggregations} },
                _biblionumbers => { terms => { field => 'biblionumber', size => 9_000 } }
            }
        };
        my ( $tb, $res ) = timed { $searcher->search( $qb, undef, 20, ( offset => 0 ) ) };
        push @b_times, $tb;
        my $buckets = $res->{aggregations}{_biblionumbers}{buckets} // [];
        @all_biblionumbers = map { $_->{key} } @$buckets;

        my $cache_key =
            'elasticsearch_item_facets_' . Digest::MD5::md5_hex( join( ',', sort { $a <=> $b } @all_biblionumbers ) );
        Koha::Caches->get_instance->clear_from_cache($cache_key);
        my ($tc) = timed { $searcher->_get_item_facets( \@all_biblionumbers ) };
        push @c_times, $tc;
    }

    say "Matched biblionumbers feeding the facets lookup: " . scalar(@all_biblionumbers);

    my @rows = (
        [ 'A: baseline',    \@a_times ],
        [ 'B: +agg',        \@b_times ],
        [ 'C: item facets', \@c_times ],
    );
    my $label_width = max( length('Scenario'), map { length( $_->[0] ) } @rows );

    printf "\n%-*s %8s %8s %8s\n", $label_width, 'Scenario', 'min(ms)', 'med(ms)', 'max(ms)';
    for my $row (@rows) {
        my ( $min, $med, undef, $max ) = stats( @{ $row->[1] } );
        printf "%-*s %8.1f %8.1f %8.1f\n", $label_width, $row->[0], $min * 1000, $med * 1000, $max * 1000;
    }

    my ( undef, $a_med, undef, undef ) = stats(@a_times);
    my ( undef, $b_med, undef, undef ) = stats(@b_times);
    my ( undef, $c_med, undef, undef ) = stats(@c_times);
    my $agg_overhead    = $b_med - $a_med;
    my $total_added     = $agg_overhead + $c_med;
    my $total_roundtrip = $a_med + $total_added;
    printf
        "\nAdded (median): %.1fms agg + %.1fms item-facets round-trip (cold cache) = %.1fms, %.1f%% of baseline (%.1fms). Cache hits on repeat searches pay less.\n",
        $agg_overhead * 1000, $c_med * 1000, $total_added * 1000,
        ( $a_med > 0 ? $total_added / $a_med * 100 : 0 ), $a_med * 1000;

    # The percentage above looks scary because the baseline itself is fast; what matters for a
    # user-facing search is the absolute total. $ACCEPTABLE_TOTAL_MS is a rough "still feels
    # instant" budget for a single backend search call, not a hard spec.
    my $verdict =
        $total_roundtrip * 1000 < $ACCEPTABLE_TOTAL_MS
        ? 'well within an "instant" search budget -- not worth chasing further'
        : 'above the instant-search budget -- may be worth a closer look';
    printf "Total round-trip (baseline + added, cold cache): %.1fms -- %s\n", $total_roundtrip * 1000, $verdict;
}
