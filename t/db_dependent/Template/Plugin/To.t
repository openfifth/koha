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

use Test::NoWarnings;
use Test::More tests => 2;
use JSON ();
use Template;
use t::lib::TestBuilder;

use Koha::Template::Plugin::To;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

subtest 'json' => sub {
    plan tests => 4;

    subtest 'newlines' => sub {
        plan tests => 1;
        my $patron = $builder->build_object(
            {
                class => 'Koha::Patrons',
                value => {
                    borrowernotes => q|
several
lines|,
                }
            }
        );
        my $expected_escaped_notes = q|\\\\nseveral\\\\nlines|;
        is( Koha::Template::Plugin::To->json( $patron->borrowernotes ), $expected_escaped_notes );
    };

    subtest 'XSS characters are escaped (bug 42796)' => sub {
        plan tests => 6;

        is(
            Koha::Template::Plugin::To->json(q|</script><script>alert(1)</script>|),
            q|\u003c/script\u003e\u003cscript\u003ealert(1)\u003c/script\u003e|,
            'closing/opening script tags are escaped'
        );
        is( Koha::Template::Plugin::To->json(q|a & b|), q|a \u0026 b|, '& is escaped' );
        is( Koha::Template::Plugin::To->json(q|a < b|), q|a \u003c b|, '< is escaped' );
        is( Koha::Template::Plugin::To->json(q|a > b|), q|a \u003e b|, '> is escaped' );
        is( Koha::Template::Plugin::To->json(q|a + b|), q|a \u002b b|, '+ is escaped' );
        is(
            Koha::Template::Plugin::To->json( "a" . chr(0x2028) . "b" . chr(0x2029) . "c" ),
            q|a\u2028b\u2029c|,
            'U+2028/U+2029 are escaped'
        );
    };

    subtest 'escaped output still decodes to the original value' => sub {
        plan tests => 2;

        my $value = qq|</script><script>alert("x")</script> & 'q' \\ caf\x{e9} \x{2028}|;
        my $out   = Koha::Template::Plugin::To->json($value);
        is( JSON->new->decode(qq|["$out"]|)->[0], $value, 'quotes, backslashes and non-ASCII survive the round trip' );
        unlike( $out, qr{[<>&+\x{2028}\x{2029}]}, 'no HTML-significant characters left in the output' );
    };

    subtest 'rendered inside a script block (bug 42796)' => sub {
        plan tests => 2;

        my $payload  = q|</script><script>alert('hacked')</script><script>|;
        my $template = Template->new( { PLUGIN_BASE => 'Koha::Template::Plugin' } );
        my $output;
        $template->process(
            \q{[% USE raw %][% USE To %]<script>let test = "[% To.json(payload) | $raw %]";</script>},
            { payload => $payload }, \$output
        ) or die $template->error;

        my @script_tags = $output =~ m{<script}gi;
        is( scalar @script_tags, 1, 'only the intended <script> element is present' );
        my @closing_tags = $output =~ m{</script}gi;
        is( scalar @closing_tags, 1, 'only the intended closing tag is present' );
    };
};

$schema->storage->txn_rollback;
