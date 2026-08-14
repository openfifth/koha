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

use Test::More tests => 6;
use Test::NoWarnings;
use Test::MockModule;

use t::lib::Mocks;

use Koha::Plugins::Store;

subtest 'returns undef when plugin_store_url is not configured' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugin_store_url', undef );
    is(
        Koha::Plugins::Store->lookup_by_kpz_url('https://example.com/plugin.kpz'), undef,
        'undef when the store URL is not configured'
    );
};

subtest 'returns undef when no release matches the given kpz_url' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );
    t::lib::Mocks::mock_preference( 'Version', '26.06.00.000' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res->code(200);
            $tx->res->body('[]');
            return $tx;
        }
    );

    is(
        Koha::Plugins::Store->lookup_by_kpz_url('https://example.com/nomatch.kpz'), undef,
        'undef when the store has no plugin with a matching release kpz_url'
    );
};

subtest 'resolves repo_url, certification_tier, signed_manifest, and signature for a matching kpz_url' => sub {
    plan tests => 1;

    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );
    t::lib::Mocks::mock_preference( 'Version', '26.06.00.000' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            my $body =
                  '[{"repo_url":"https://github.com/openfifth/koha-plugin-coverflow","releases":'
                . '[{"kpz_url":"https://example.com/match.kpz","certification_tier":"CERTIFIED",'
                . '"signed_manifest":"{\"digest\":\"abc123\"}","signature":"fakesignaturebase64=="}]}]';
            $tx->res->code(200);
            $tx->res->body($body);
            return $tx;
        }
    );

    is_deeply(
        Koha::Plugins::Store->lookup_by_kpz_url('https://example.com/match.kpz'),
        {
            repo_url           => 'https://github.com/openfifth/koha-plugin-coverflow',
            certification_tier => 'CERTIFIED',
            signed_manifest    => '{"digest":"abc123"}',
            signature          => 'fakesignaturebase64==',
        },
        'repo_url, certification_tier, signed_manifest, and signature all resolved from the matching release'
    );
};

subtest 'lookup_by_digest returns undef when plugin_store_url is not configured' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugin_store_url', undef );
    is( Koha::Plugins::Store->lookup_by_digest('abc123'), undef, 'undef when the store URL is not configured' );
};

subtest 'lookup_by_digest resolves signed_manifest, signature, and certification_tier for a known digest' => sub {
    plan tests => 2;

    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res->code(200);
            $tx->res->body(
                '{"signed_manifest":"{\"digest\":\"abc123\"}","signature":"fakesig==","certification_tier":"CERTIFIED"}'
            );
            return $tx;
        }
    );
    is_deeply(
        Koha::Plugins::Store->lookup_by_digest('abc123'),
        { signed_manifest => '{"digest":"abc123"}', signature => 'fakesig==', certification_tier => 'CERTIFIED' },
        'fields resolved from a 200 response'
    );

    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res->code(404);
            return $tx;
        }
    );
    is( Koha::Plugins::Store->lookup_by_digest('unknown'), undef, 'undef on a 404 (no matching published version)' );
};
