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

use Test::More tests => 7;
use Test::NoWarnings;
use Test::MockModule;
use File::Temp   qw(tempdir tempfile);
use Archive::Zip qw(:CONSTANTS);

use t::lib::Mocks;

use Koha::Plugins::Install;

my $plugins_dir = tempdir( CLEANUP => 1 );
t::lib::Mocks::mock_config( 'pluginsdir', $plugins_dir );

my $c4_context = Test::MockModule->new('C4::Context');

sub _fixture_kpz {
    my ( $fh, $path ) = tempfile( SUFFIX => '.kpz' );
    my $zip = Archive::Zip->new;
    $zip->addString( "package Test; 1;", 'Test.pm' );
    $zip->writeToFileNamed($path);
    return $path;
}

subtest 'rejects a non-.kpz filename' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );
    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.zip' } );
    is( $result->{NOTKPZ}, 1, 'NOTKPZ error set for a non-.kpz filename' );
};

subtest 'unrestricted install with no known repo_url succeeds' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );
    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.kpz' } );
    ok( $ok, 'install succeeds when plugins_restricted is off, even with no known repo_url' );
};

subtest 'restricted install with no known repo_url is rejected' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted', 1 );
    t::lib::Mocks::mock_config(
        'plugin_repos',
        { repo => [ { org_name => 'bywatersolutions', service => 'github' } ] }
    );
    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.kpz' } );
    ok( !$ok, 'install is rejected with no repo_url to check against the allowlist' );
    is( $result->{RESTRICTED}, 1, 'RESTRICTED error set' );
};

subtest 'restricted install: the exact substring-bypass URL is correctly rejected' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted', 1 );
    t::lib::Mocks::mock_config(
        'plugin_repos',
        { repo => [ { org_name => 'bywatersolutions', service => 'github' } ] }
    );
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path => _fixture_kpz(),
            filename => 'plugin.kpz',
            repo_url => 'https://evil.example.com/bywatersolutions/plugin',
        }
    );
    ok( !$ok, 'a repo_url whose path merely contains an allowed org_name, on the wrong host, is rejected' );
    is( $result->{RESTRICTED}, 1, 'RESTRICTED error set' );
};

subtest 'restricted install: an exact, correctly-hosted org match is allowed' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugins_restricted', 1 );
    t::lib::Mocks::mock_config(
        'plugin_repos',
        { repo => [ { org_name => 'bywatersolutions', service => 'github' } ] }
    );
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path => _fixture_kpz(),
            filename => 'plugin.kpz',
            repo_url => 'https://github.com/bywatersolutions/koha-plugin-coverflow',
        }
    );
    ok( $ok, 'a repo_url exactly matching an allowed org on the right host is allowed' );
};

subtest 'certification tier below PluginStoreMinimumLevel is rejected' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );
    t::lib::Mocks::mock_preference( 'PluginStoreMinimumLevel', 'CERTIFIED' );
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path           => _fixture_kpz(),
            filename           => 'plugin.kpz',
            certification_tier => 'STRUCTURAL',
        }
    );
    ok( !$ok, 'install is rejected when below the configured minimum level' );
    is( $result->{BELOWMINIMUMLEVEL}, 1, 'BELOWMINIMUMLEVEL error set' );
};
