#!/usr/bin/perl

# Copyright 2025 Koha Development Team
#
# This file is part of Koha
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

use Test::More tests => 17;
use Test::MockModule;
use Test::Mojo;
use Test::NoWarnings;

use MIME::Base64 qw( encode_base64 );

use Koha::Database;
use Koha::Session;

use t::lib::Mocks;
use t::lib::TestBuilder;

# Skip unless Net::SAML2 available (same guard as middleware test)
BEGIN {
    eval { require Net::SAML2 };
    plan skip_all => 'Net::SAML2 not installed' if $@;
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# We test via the Intranet app (interface=staff) which loads the SAML2 plugin.
# Opac is symmetric; a single app covers all protocol-level behaviour.
my $t = Test::Mojo->new('Koha::App::Intranet');

t::lib::Mocks::mock_preference( 'OPACBaseURL',        'https://opac.example.com' );
t::lib::Mocks::mock_preference( 'staffClientBaseURL', 'https://staff.example.com' );
t::lib::Mocks::mock_preference( 'SessionStorage',     'file' );

# -------------------------------------------------------------------------
# MockSP — still required: Net::SAML2::SP needs real X.509 certs + IdP
# metadata that cannot be created via TestBuilder.
# -------------------------------------------------------------------------

{

    package MockSP;

    sub authn_request_redirect  { 'https://idp.example.com/sso?SAMLRequest=FAKE' }
    sub sp_metadata_xml         { '<EntityDescriptor entityID="https://sp.example.com/saml2"/>' }
    sub logout_request_redirect { 'https://idp.example.com/slo?SAMLRequest=FAKE' }
    sub process_response        { { all_attributes => {}, nameid => 'user@example.com', session_index => 'idx_1' } }
    sub process_logout_response { 'https://opac.example.com/' }
}

# -------------------------------------------------------------------------
# Set up real identity-provider records in a single wrapping transaction.
# The whole test file is rolled back at the end; patron subtests use nested
# savepoints for their own inner rollbacks.
# -------------------------------------------------------------------------

$schema->storage->txn_begin;

# hostnames table has no Koha:: wrapper — use the DBIC resultset directly.
# Test::Mojo makes in-process requests; $c->req->url->base->host is '127.0.0.1'.
my $hostname_rs = $schema->resultset('Hostname')->create( { hostname => '127.0.0.1' } );

# Native SAML2 provider: _get_provider('localhost') will find this naturally.
my $native_provider = $builder->build_object(
    {
        class => 'Koha::Auth::Identity::Providers',
        value => {
            protocol => 'SAML2',
            enabled  => 1,
            config   => '{"mode":"native"}',
        },
    }
);

# Link the provider to the 'localhost' hostname.
$builder->build_object(
    {
        class => 'Koha::Auth::Identity::Provider::Hostnames',
        value => {
            identity_provider_id => $native_provider->id,
            hostname_id          => $hostname_rs->hostname_id,
            is_enabled           => 1,
        },
    }
);

# IPC-mode provider for the IPC subtest — no hostname link needed since it is
# injected directly via _with_provider.
my $ipc_provider = $builder->build_object(
    {
        class => 'Koha::Auth::Identity::Providers',
        value => {
            protocol => 'SAML2',
            enabled  => 1,
            config   => '{"mode":"ipc"}',
        },
    }
);

# Mock build_sp on the real SAML2 provider class — the only thing that still
# needs mocking because SP construction requires live crypto infrastructure.
my $mock_sp_builder = Test::MockModule->new('Koha::Auth::Identity::Provider::SAML2');
$mock_sp_builder->mock( 'build_sp', sub { bless {}, 'MockSP' } );

# -------------------------------------------------------------------------
# Helper: override _get_provider for edge-case subtests (no provider / IPC).
# Most subtests rely on the real DB-backed lookup via the records above.
# -------------------------------------------------------------------------

sub _with_provider {
    my ( $provider, $test_sub ) = @_;
    my $mock = Test::MockModule->new('Koha::App::Controller::SAML2');
    $mock->mock( '_get_provider', sub { $provider } );
    $test_sub->();
}

# =========================================================================

subtest 'No provider configured => 404 or 400' => sub {
    plan tests => 6;

    # login and metadata return 404 when no provider
    # acs returns 400 (missing SAMLResponse) before reaching the provider check
    _with_provider(
        undef,
        sub {
            $t->get_ok('/auth/saml2/login')->status_is(404);
            $t->post_ok('/auth/saml2/acs')->status_is(400);
            $t->get_ok('/auth/saml2/metadata')->status_is(404);
        }
    );
};

# =========================================================================

subtest 'GET /auth/saml2/login - redirects to IdP' => sub {
    plan tests => 3;

    my $target = 'https://staff.example.com/cgi-bin/koha/mainpage.pl';

    $t->get_ok("/auth/saml2/login?target=$target")
        ->status_is(302)
        ->header_like( 'Location', qr{idp\.example\.com}, 'Redirects to IdP URL' );
};

subtest 'GET /auth/saml2/login - rejects open redirect' => sub {
    plan tests => 2;

    $t->get_ok('/auth/saml2/login?target=https://evil.example.com/steal')->status_is(400);
};

# =========================================================================

subtest 'POST /auth/saml2/acs - missing SAMLResponse => 400' => sub {
    plan tests => 2;

    $t->post_ok('/auth/saml2/acs')->status_is(400);
};

subtest 'POST /auth/saml2/acs - SP process_response fails => 403' => sub {
    plan tests => 2;

    {
        no warnings 'redefine';
        local *MockSP::process_response = sub { die 'Signature validation failed' };

        $t->post_ok(
            '/auth/saml2/acs',
            form => {
                SAMLResponse => encode_base64('<fake/>'),
                RelayState   => 'https://staff.example.com/',
            }
        )->status_is(403);
    }
};

subtest 'POST /auth/saml2/acs - authentication fails => 403' => sub {
    plan tests => 2;

    my $mock_client = Test::MockModule->new('Koha::Auth::Client::SAML2');
    $mock_client->mock( 'authenticate', sub { ( undef, 'patron not found' ) } );

    $t->post_ok(
        '/auth/saml2/acs',
        form => {
            SAMLResponse => encode_base64('<fake/>'),
            RelayState   => 'https://staff.example.com/',
        }
    )->status_is(403);
};

# =========================================================================
# Critical test: ACS success establishes a full Koha session.
# This is the core of Bug 24880 — the old middleware stored only a partial
# saml2_authenticated_borrowernumber; the new controller calls
# create_basic_session() so borrowernumber is set directly in the session.
# =========================================================================

subtest 'POST /auth/saml2/acs - success: full session with borrowernumber' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $mock_client = Test::MockModule->new('Koha::Auth::Client::SAML2');
    $mock_client->mock( 'authenticate', sub { ( $patron, undef ) } );

    my $relay_state = 'https://staff.example.com/cgi-bin/koha/mainpage.pl';

    $t->post_ok(
        '/auth/saml2/acs',
        form => {
            SAMLResponse => encode_base64('<fake_saml_response/>'),
            RelayState   => $relay_state,
        }
    );

    $t->status_is(302);
    $t->header_is( 'Location', $relay_state, 'Redirects to RelayState' );

    # CGISESSID cookie must be present
    my $cookie_header = $t->tx->res->headers->header('Set-Cookie') // '';
    like( $cookie_header, qr{CGISESSID=}, 'CGISESSID cookie set in response' );

    my ($session_id) = ( $cookie_header =~ /CGISESSID=([^;]+)/ );
    ok( $session_id, 'Session ID extracted from cookie' );

    # Load session and verify full content (not just a partial SAML bridge)
    my $session = Koha::Session->get_session( { sessionID => $session_id } );
    ok( $session, 'Session found in storage' );
    is( $session->param('number'),    $patron->borrowernumber, 'Session has borrowernumber' );
    is( $session->param('interface'), 'intranet',              'Session interface is intranet (staff)' );

    $session->delete;
    $session->flush;
    $schema->storage->txn_rollback;
};

# =========================================================================

subtest 'POST /auth/saml2/acs - invalid RelayState falls back to base URL' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $mock_client = Test::MockModule->new('Koha::Auth::Client::SAML2');
    $mock_client->mock( 'authenticate', sub { ( $patron, undef ) } );

    $t->post_ok(
        '/auth/saml2/acs',
        form => {
            SAMLResponse => encode_base64('<fake/>'),
            RelayState   => 'https://evil.example.com/steal',
        }
        )
        ->status_is(302)
        ->header_unlike( 'Location', qr{evil\.example\.com}, 'Location does not point to evil domain' );

    $schema->storage->txn_rollback;
};

# =========================================================================

subtest 'GET /auth/saml2/metadata - returns SP metadata XML' => sub {
    plan tests => 4;

    $t->get_ok('/auth/saml2/metadata')
        ->status_is(200)
        ->header_like( 'Content-Type', qr{application/samlmetadata\+xml}, 'Correct Content-Type' )
        ->content_like( qr{EntityDescriptor}, 'Body contains EntityDescriptor' );
};

# =========================================================================

subtest 'GET /auth/saml2/logout - no session cookie, redirects to base URL' => sub {
    plan tests => 2;

    $t->get_ok('/auth/saml2/logout')->status_is(302);
};

subtest 'GET /auth/saml2/logout - invalid return param is ignored' => sub {
    plan tests => 3;

    $t->get_ok('/auth/saml2/logout?return=https://evil.example.com/steal')
        ->status_is(302)
        ->header_unlike( 'Location', qr{evil\.example\.com}, 'Does not redirect to evil domain' );
};

# =========================================================================

subtest 'GET /auth/saml2/attributes - disabled by default => 403' => sub {
    plan tests => 2;

    $t->get_ok('/auth/saml2/attributes')->status_is(403);
};

subtest 'GET /auth/saml2/attributes - debug on, default IPs (localhost) => 200' => sub {
    plan tests => 2;

    # Enable debug with no explicit allowed IPs — defaults to localhost.
    # Test::Mojo makes requests from 127.0.0.1, so this should succeed.
    $native_provider->set_config( { mode => 'native', debug => 1 } );
    $native_provider->store;

    $t->get_ok('/auth/saml2/attributes')->status_is(200);

    # Restore
    $native_provider->set_config( { mode => 'native' } );
    $native_provider->store;
};

subtest 'GET /auth/saml2/attributes - debug on, explicit localhost => 200' => sub {
    plan tests => 2;

    $native_provider->set_config( { mode => 'native', debug => 1, debug_allowed_ips => '127.0.0.1 ::1' } );
    $native_provider->store;

    $t->get_ok('/auth/saml2/attributes')->status_is(200);

    $native_provider->set_config( { mode => 'native' } );
    $native_provider->store;
};

subtest 'GET /auth/saml2/attributes - debug on, non-matching IP => 403' => sub {
    plan tests => 2;

    $native_provider->set_config( { mode => 'native', debug => 1, debug_allowed_ips => '10.99.99.99' } );
    $native_provider->store;

    $t->get_ok('/auth/saml2/attributes')->status_is(403);

    $native_provider->set_config( { mode => 'native' } );
    $native_provider->store;
};

subtest 'IPC mode provider is ignored by controller (returns 404)' => sub {
    plan tests => 2;

    # Non-native provider: controller must return 404 so mod_shib flow is unaffected
    _with_provider(
        $ipc_provider,
        sub { $t->get_ok('/auth/saml2/login')->status_is(404) }
    );
};

$schema->storage->txn_rollback;

=encoding utf8

=head1 NAME

t/db_dependent/Koha/App/Controller/SAML2.t

=head1 DESCRIPTION

Integration tests for L<Koha::App::Controller::SAML2>.

Tests that:

=over 4

=item * SAML2 routes are registered at C</auth/saml2/*>

=item * Error cases (missing SAMLResponse, SP failure, auth failure) return
correct HTTP status codes

=item * A successful ACS POST establishes a B<full> Koha session with
C<borrowernumber> in the session via C<create_basic_session()>, not the old
partial C<saml2_authenticated_borrowernumber> bridge

=item * Open-redirect defences are active for target, RelayState, and return params

=item * IPC-mode providers return 404 (controller does not intercept IPC flows)

=back

=cut
