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

use Test::More tests => 12;
use Test::NoWarnings;
use Test::MockModule;
use File::Temp   qw(tempdir tempfile);
use Archive::Zip qw(:CONSTANTS);

use t::lib::Mocks;

use Koha::Plugins::Install;
use Crypt::PK::Ed25519;
use Mojo::JSON qw(encode_json);

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
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        { kpz_path => _fixture_kpz(), filename => 'plugin.kpz', confirm_unsigned => 1 } );
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
            kpz_path         => _fixture_kpz(),
            filename         => 'plugin.kpz',
            repo_url         => 'https://github.com/bywatersolutions/koha-plugin-coverflow',
            confirm_unsigned => 1,
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

subtest '_verify_signature' => sub {
    plan tests => 5;

    my $keypair = Crypt::PK::Ed25519->new;
    $keypair->generate_key;
    my $public_key_pem  = $keypair->export_key_pem('public');
    my $private_key_pem = $keypair->export_key_pem('private');

    my $manifest = encode_json(
        {
            slug         => 'widget',
            version      => '1.0.0',
            kpz_url      => 'https://example.com/widget.kpz',
            digest       => 'abc123',
            published_at => '2026-01-01T00:00:00Z',
        }
    );
    my $signer    = Crypt::PK::Ed25519->new( \$private_key_pem );
    my $signature = MIME::Base64::encode_base64( $signer->sign_message($manifest), '' );

    my $install_module = Test::MockModule->new('Koha::Plugins::Install');
    $install_module->mock( _store_public_key => sub { return $public_key_pem } );

    ok(
        Koha::Plugins::Install->_verify_signature( $manifest, $signature, 'abc123' ),
        'a valid signature over the matching digest verifies'
    );

    ok(
        !Koha::Plugins::Install->_verify_signature( $manifest, $signature, 'wrongdigest' ),
        'a valid signature over a NON-matching digest fails -- the manifest is for a different file'
    );

    ( my $tampered_manifest = $manifest ) =~ s/widget/tampered/;
    ok(
        !Koha::Plugins::Install->_verify_signature( $tampered_manifest, $signature, 'abc123' ),
        'a tampered manifest fails signature verification'
    );

    my $other_keypair = Crypt::PK::Ed25519->new;
    $other_keypair->generate_key;
    my $wrong_signature = MIME::Base64::encode_base64( $other_keypair->sign_message($manifest), '' );
    ok(
        !Koha::Plugins::Install->_verify_signature( $manifest, $wrong_signature, 'abc123' ),
        'a signature from the wrong keypair fails'
    );

    ok(
        !Koha::Plugins::Install->_verify_signature( 'not valid json', $signature, 'abc123' ),
        'malformed manifest JSON fails cleanly rather than dying'
    );
};

subtest 'a present, invalid signature is SIGNATUREMISMATCH regardless of plugins_allow_unsigned' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted',     0 );
    t::lib::Mocks::mock_config( 'plugins_allow_unsigned', 1 );
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path        => _fixture_kpz(),
            filename        => 'plugin.kpz',
            signed_manifest => '{"digest":"not-the-real-digest"}',
            signature       => 'ZmFrZQ==',    # base64 of 'fake' -- decodes fine, verifies against nothing real
        }
    );
    ok( !$ok, 'install is rejected when a signature is present but does not verify' );
    is( $result->{SIGNATUREMISMATCH}, 1, 'SIGNATUREMISMATCH error set' );
};

subtest 'an absent signature is UNSIGNED when plugins_allow_unsigned is off' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted',     0 );
    t::lib::Mocks::mock_config( 'plugins_allow_unsigned', 0 );
    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.kpz' } );
    ok( !$ok, 'install is rejected outright with no signature and unsigned installs disabled' );
    is( $result->{UNSIGNED}, 1, 'UNSIGNED error set' );
};

subtest 'an absent signature requires confirmation when plugins_allow_unsigned is on (the default)' => sub {
    plan tests => 3;
    t::lib::Mocks::mock_config( 'plugins_restricted',     0 );
    t::lib::Mocks::mock_config( 'plugins_allow_unsigned', 1 );

    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.kpz' } );
    ok( !$ok, 'install is not performed on the first, unconfirmed attempt' );
    is( $result->{UNSIGNEDCONFIRMREQUIRED}, 1, 'UNSIGNEDCONFIRMREQUIRED error set' );

    ( $ok, $result ) = Koha::Plugins::Install->install(
        { kpz_path => _fixture_kpz(), filename => 'plugin.kpz', confirm_unsigned => 1 } );
    ok( $ok, 'the same request with confirm_unsigned set proceeds to install' );
};

subtest 'plugins_allow_unsigned defaults to enabled when unset' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );

    # deliberately NOT calling mock_config('plugins_allow_unsigned', ...) -- confirms
    # the C4::Context->config('plugins_allow_unsigned') // 1 default takes effect
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        { kpz_path => _fixture_kpz(), filename => 'plugin.kpz', confirm_unsigned => 1 } );
    ok( $ok, 'an unconfigured plugins_allow_unsigned behaves as enabled (matches pre-existing behavior)' );
};
