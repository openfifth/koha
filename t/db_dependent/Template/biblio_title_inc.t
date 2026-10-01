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

use CGI;
use JSON ();
use Template;

use Test::NoWarnings;
use Test::More tests => 3;

use C4::Context;
use C4::Templates;
use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

# Awkward on purpose: HTML-significant characters, a backslash and a tab
my $title = qq{Pride & Prejudice <3 C++ "quoted" back\\slash\ttab};

my $biblio = $builder->build_sample_biblio( { title => $title } );

subtest 'biblio-title.inc renders plain HTML (bug 42796)' => sub {
    plan tests => 3;

    my $includes = C4::Context->config('intrahtdocs') . '/prog/en/includes';
    my $tt       = Template->new( { INCLUDE_PATH => $includes, PLUGIN_BASE => 'Koha::Template::Plugin' } );
    my $output;
    $tt->process( \q{[% USE Koha %][% INCLUDE 'biblio-title.inc' %]}, { biblio => $biblio }, \$output )
        or die $tt->error;

    like(
        $output, qr{Pride &amp; Prejudice &lt;3 C\+\+ &quot;quoted&quot;},
        'Title is HTML-escaped and nothing else'
    );
    unlike( $output, qr{\\u[0-9a-f]{4}}, 'No JSON unicode escapes leak into the HTML' );
    like( $output, qr{back\\slash\ttab}, 'Backslash and tab are not JSON-escaped' );
};

subtest 'itemsearch JSON stays valid and decodes to the same HTML (bug 42796)' => sub {
    plan tests => 3;

    my $item =
        $builder->build_sample_item( { biblionumber => $biblio->biblionumber, itemcallnumber => qq{A\\B\tC&D} } );
    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $template = C4::Templates::gettemplate( 'catalogue/itemsearch_json.tt', 'intranet', CGI->new );
    $template->param( draw => 1, total_rows => 1, results => [$item], user => $patron );

    my $data = eval { JSON->new->decode( $template->output ) };
    ok( $data, 'Output is valid JSON' ) or diag $@;

    my $row = $data->{data}->[0];
    like(
        $row->[1], qr{Pride &amp; Prejudice &lt;3 C\+\+ &quot;quoted&quot; back\\slash tab</span>},
        'Title cell decodes to the HTML-escaped title, backslash intact and tab collapsed'
    );
    is( $row->[8], qq{A\\B\tC&amp;D}, 'Call number cell decodes to the HTML-escaped value' )
        or diag explain $row;
};

$schema->storage->txn_rollback;
