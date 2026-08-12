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

use Test::More tests => 4;
use Test::NoWarnings;
use Test::MockModule;

use t::lib::Mocks;

use Koha::Plugins::Search;

subtest 'returns an error when no plugin store is configured' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugin_store_url', undef );
    my ( $results, $errors ) = Koha::Plugins::Search->search('coverflow');
    is( scalar @$results, 0, 'no results' );
    is( scalar @$errors,  1, 'one error reported' );
};

subtest 'filters by name/description, case-insensitively' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );
    t::lib::Mocks::mock_preference( 'Version', '26.06.00.000' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx   = Mojo::Transaction::HTTP->new;
            my $body = '['
                . '{"name":"CoverFlow plugin","description":"widget","repo_url":"https://github.com/a/b","releases":[{"kpz_url":"https://example.com/a.kpz","tag_name":"v1"}]},'
                . '{"name":"Other plugin","description":"unrelated","repo_url":"https://github.com/c/d","releases":[{"kpz_url":"https://example.com/b.kpz","tag_name":"v1"}]}'
                . ']';
            $tx->res->code(200);
            $tx->res->body($body);
            return $tx;
        }
    );

    my ( $results, $errors ) = Koha::Plugins::Search->search('coverflow');
    is( scalar @$errors,                 0,                  'no errors' );
    is( scalar @$results,                1,                  'exactly one matching plugin' );
    is( $results->[0]->{result}->{name}, 'CoverFlow plugin', 'the matching plugin is returned' );
    is( $results->[0]->{repo}->{name},   'a',                'repo.name contains extracted org, not full URL' );
};

subtest 'reports an error when the store is unreachable' => sub {
    plan tests => 1;

    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );
    t::lib::Mocks::mock_preference( 'Version', '26.06.00.000' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res->code(500);
            return $tx;
        }
    );

    my ( $results, $errors ) = Koha::Plugins::Search->search('anything');
    is( scalar @$errors, 1, 'one error reported when the store returns a non-200' );
};
