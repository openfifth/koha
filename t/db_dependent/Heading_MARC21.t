#!/usr/bin/perl
#
# This Koha test module is a stub!
# Add more tests here!!!

use strict;
use warnings;

use Test::NoWarnings;
use Test::More tests => 13;
use C4::Context;

BEGIN {
    use_ok( 'C4::Heading', qw( new_from_field ) );
}

SKIP: {
    skip "MARC21 heading tests not applicable to UNIMARC", 4 if C4::Context->preference('marcflavour') eq 'UNIMARC';
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

    # Bug 43483: a 6XX field with a blank/undefined 2nd indicator asserts no
    # thesaurus, so it should be treated the same as a non-subject field
    # (1XX/7XX), not coerced to the literal 'notdefined' thesaurus.
    $field   = MARC::Field->new( '600', '1', ' ', a => 'Goddard, Giles', d => '1962-' );
    $heading = C4::Heading->new_from_field($field);
    ok(
        !defined $heading->{thesaurus},
        'Thesaurus is not generated for a 6XX field with a blank 2nd indicator'
    );

    $field   = MARC::Field->new( '600', '1', '', a => 'Goddard, Giles', d => '1962-' );
    $heading = C4::Heading->new_from_field($field);
    ok(
        !defined $heading->{thesaurus},
        'Thesaurus is not generated for a 6XX field with an undefined 2nd indicator'
    );
}
