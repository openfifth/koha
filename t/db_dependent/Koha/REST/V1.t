#!/usr/bin/perl

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

use Encode qw( encode );

use Test::NoWarnings;
use Test::More tests => 3;
use Test::Mojo;
use Test::Warn;

use Koha::REST::V1;

subtest 'Type definition tests' => sub {

    plan tests => 4;

    # initialize Koha::REST::V1 after mocking
    my $remote_address = '127.0.0.1';
    my $t;

    $t = Test::Mojo->new('Koha::REST::V1');
    my $types = $t->app->types;

    is(
        $types->type('json'),
        'application/json; charset=utf8',
        'application/json gets charset added'
    );
    is( $types->type('marcxml'), 'application/marcxml+xml',  'application/marcxml+xml is defined' );
    is( $types->type('mij'),     'application/marc-in-json', 'application/marc-in-json is defined' );
    is( $types->type('marc'),    'application/marc',         'application/marc is defined' );
};

subtest 'safe_xml_parser and _unsafe_xml_body (Bug 43376 - XXE) tests' => sub {

    plan tests => 8;

    my $doctype_xml = '<!DOCTYPE foo [ <!ENTITY x "y"> ]><foo/>';

    ok( Koha::REST::V1::_unsafe_xml_body($doctype_xml),      '_unsafe_xml_body detects a DOCTYPE declaration' );
    ok( !Koha::REST::V1::_unsafe_xml_body('<foo>bar</foo>'), '_unsafe_xml_body allows DOCTYPE-free XML' );
    ok( Koha::REST::V1::_unsafe_xml_body("<foo>\x00</foo>"), '_unsafe_xml_body detects a NUL byte' );
    ok(
        Koha::REST::V1::_unsafe_xml_body( encode( 'UTF-16LE', $doctype_xml ) ),
        '_unsafe_xml_body detects a DOCTYPE hidden behind UTF-16 encoding'
    );

    my $parser = Koha::REST::V1::safe_xml_parser();

    my $xxe_xml = q{<?xml version="1.0"?>
<!DOCTYPE root [ <!ENTITY xxe SYSTEM "file:///etc/hostname"> ]>
<root>&xxe;</root>};
    my $doc = $parser->parse_string($xxe_xml);
    is( $doc->documentElement->textContent, '', 'safe_xml_parser does not expand external (SYSTEM) entities' );

    is( $parser->no_network,      1, 'safe_xml_parser disables network access' );
    is( $parser->load_ext_dtd,    0, 'safe_xml_parser disables external DTD loading' );
    is( $parser->expand_entities, 0, 'safe_xml_parser disables entity expansion' );
};
