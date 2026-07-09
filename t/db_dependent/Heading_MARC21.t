#!/usr/bin/perl
#
# This Koha test module is a stub!
# Add more tests here!!!

use strict;
use warnings;

use Test::NoWarnings;
use Test::More tests => 17;
use C4::Context;

BEGIN {
    use_ok( 'C4::Heading', qw( new_from_field ) );
    use_ok('C4::Heading::MARC21');
}

SKIP: {
    skip "MARC21 heading tests not applicable to UNIMARC", 2 if C4::Context->preference('marcflavour') eq 'UNIMARC';
    my $field   = MARC::Field->new( '650', ' ', '2', a => 'Uncles', x => 'Fiction' );
    my $heading = C4::Heading->new_from_field($field);
    is( $heading->display_form(), 'Uncles--Fiction',              'Display form generation' );
    is( $heading->search_form(),  'Uncles generalsubdiv Fiction', 'Search form generation' );
    is( $heading->{thesaurus},    'mesh',                         'Thesaurus generation' );

    $field   = MARC::Field->new( '830', ' ', '4', a => 'The dark is rising ;', v => '3' );
    $heading = C4::Heading->new_from_field($field);
    is( $heading->display_form(), 'The dark is rising ;', 'Display form generation' );
    is( $heading->search_form(),  'The dark is rising',   'Search form generation' );
    ok( !defined $heading->{thesaurus}, 'Thesaurus is not generated outside of 6XX fields' );

    $field   = MARC::Field->new( '100', '1', '', a => 'Yankovic, Al', d => '1959-' );
    $heading = C4::Heading->new_from_field($field);
    is( $heading->display_form(), 'Yankovic, Al 1959-', 'Display form generation' );
    is( $heading->search_form(),  'Yankovic, Al 1959',  'Search form generation' );
    ok( !defined $heading->{thesaurus}, 'Thesaurus is not generated outside of 6XX fields' );

}

is( C4::Heading::MARC21::thesaurus_to_authority_008_11('lcsh'), 'a', 'lcsh maps to 008/11 code a' );
is( C4::Heading::MARC21::thesaurus_to_authority_008_11('mesh'), 'c', 'mesh maps to 008/11 code c' );
is( C4::Heading::MARC21::thesaurus_to_authority_008_11('rvm'),  'v', 'rvm maps to 008/11 code v' );
is(
    C4::Heading::MARC21::thesaurus_to_authority_008_11('fast'), 'z',
    'Unrecognized raw $2 code (e.g. fast, from an ind2=7 heading) maps to 008/11 code z (Other)'
);
is( C4::Heading::MARC21::thesaurus_to_authority_008_11(undef), 'z', 'undef maps to 008/11 code z (Other)' );
