#!/usr/bin/perl
use Modern::Perl;
use Time::HiRes qw( time );
use Digest::MD5;
use Koha::Caches;
use Koha::SearchEngine;
use Koha::SearchEngine::Elasticsearch::Search;

my $cache = Koha::Caches->get_instance();
$cache->clear_from_cache('elasticsearch_available_biblionumbers');

my $searcher = Koha::SearchEngine::Elasticsearch::Search->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );

# Count real ES calls by wrapping the client object get_elasticsearch() returns,
# rather than the internal Search::Elasticsearch client class directly - that
# class's methods are Moo-role-composed at load time, so redefining them after
# the fact doesn't affect classes that already consumed the role.
package ESCallCounter;

our $count = 0;
our $AUTOLOAD;

sub new {
    my ( $class, $real ) = @_;
    return bless { real => $real }, $class;
}

sub AUTOLOAD {
    my $self = shift;
    ( my $name = $AUTOLOAD ) =~ s/.*:://;
    return if $name eq 'DESTROY';
    $count++;
    return $self->{real}->$name(@_);
}

package main;

{
    no warnings 'redefine';
    my $orig = \&Koha::SearchEngine::Elasticsearch::get_elasticsearch;
    *Koha::SearchEngine::Elasticsearch::get_elasticsearch = sub {
        return ESCallCounter->new( $orig->(@_) );
    };
}

sub es_calls       { return $ESCallCounter::count }
sub reset_es_calls { $ESCallCounter::count = 0 }

say "=== _get_available_biblionumbers() ===";
say "--- Call 1 (cold, should hit ES) ---";
reset_es_calls();
my $t0   = time();
my @bns1 = $searcher->_get_available_biblionumbers();
my $t1   = time();
say sprintf( "ES calls made: %d | time: %.4fs | biblionumbers found: %d", es_calls(), $t1 - $t0, scalar(@bns1) );

say "--- Call 2 (immediately after, should be cached) ---";
reset_es_calls();
$t0 = time();
my @bns2 = $searcher->_get_available_biblionumbers();
$t1 = time();
say sprintf( "ES calls made: %d | time: %.4fs | biblionumbers found: %d", es_calls(), $t1 - $t0, scalar(@bns2) );

say "";
say "=== _get_item_facets() ===";
my @all_bns         = ( 1 .. 50 );    # arbitrary biblionumber set for cache-key purposes
my $facet_cache_key = 'elasticsearch_item_facets_' . Digest::MD5::md5_hex( join( ',', sort { $a <=> $b } @all_bns ) );
$cache->clear_from_cache($facet_cache_key);

say "--- Call 1 (cold, should hit ES) ---";
reset_es_calls();
$t0 = time();
my $facets1 = $searcher->_get_item_facets( \@all_bns );
$t1 = time();
say sprintf( "ES calls made: %d | time: %.4fs", es_calls(), $t1 - $t0 );

say "--- Call 2 (same biblionumber set, should be cached) ---";
reset_es_calls();
$t0 = time();
my $facets2 = $searcher->_get_item_facets( \@all_bns );
$t1 = time();
say sprintf( "ES calls made: %d | time: %.4fs", es_calls(), $t1 - $t0 );

$cache->clear_from_cache('elasticsearch_available_biblionumbers');
$cache->clear_from_cache($facet_cache_key);
