package Koha::Middleware::SAML2;

# Copyright 2025 Koha Development Team
#
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

use parent qw(Plack::Middleware);

use JSON qw( encode_json );
use Plack::Request;
use Plack::Response;
use URI;

use C4::Context;
use Koha::Auth::Identity::Providers;
use Koha::Logger;
use Koha::Session;

=head1 NAME

Koha::Middleware::SAML2 - Plack middleware implementing SAML2 SP endpoints

=head1 SYNOPSIS

  # In app.psgi:
  enable '+Koha::Middleware::SAML2';

=head1 DESCRIPTION

This middleware intercepts C</cgi-bin/koha/saml2/*> paths and handles the SAML2
protocol natively for providers configured with C<mode=native> in the identity
providers database.

For providers configured with C<mode=ipc> (OS-level mod_shib / libshibsp), or
when no enabled SAML2 provider is found for the request hostname, the request
is passed through to the next Plack application unchanged.

Handled paths (for native mode providers):

=over 4

=item C<GET /cgi-bin/koha/saml2/login>

Initiates SP-initiated SSO. Redirects browser to IdP with a SAML2 AuthnRequest.

=item C<POST /cgi-bin/koha/saml2/acs>

Assertion Consumer Service (ACS). Receives the SAMLResponse from the IdP,
validates it, stores SAML attributes in the user's CGI::Session, then
redirects to the original target URL (RelayState).

=item C<GET /cgi-bin/koha/saml2/logout>

Initiates Single Logout. Redirects to IdP with a LogoutRequest (if NameID
is in session), or directly to the return URL if SLO is not available.

=item C<GET /cgi-bin/koha/saml2/sls>

Single Logout Service. Receives LogoutResponse from IdP, validates it,
and redirects to return URL.

=item C<GET /cgi-bin/koha/saml2/metadata>

Returns the SP metadata XML.

=back

All other paths, and all paths when mode is not C<native>, are passed through
to the next Plack app.

=head2 Methods

=head3 call

    $app = $middleware->call($env);

Plack entry point. Intercepts C</cgi-bin/koha/saml2/*> paths for native SAML2
providers and handles login, ACS, logout, SLS, and metadata requests. All
other paths (and all paths when no native provider is configured) are passed
through to the wrapped Plack application.

=cut

sub call {
    my ( $self, $env ) = @_;

    my $path = $env->{PATH_INFO} // '';

    # Only intercept /cgi-bin/koha/saml2/* paths
    return $self->app->($env) unless $path =~ m{^/cgi-bin/koha/saml2/};

    # All /cgi-bin/koha/saml2/* paths are hostname-specific: the metadata contains
    # ACS URLs bound to the matched hostname, so provider lookup must match.
    my $provider = $self->_get_provider($env);

    # Pass through if no provider found or not native mode
    unless ( $provider && $provider->is_native ) {
        return $self->app->($env);
    }

    my $req      = Plack::Request->new($env);
    my $method   = $req->method;
    my $hostname = $self->_request_hostname($env);
    my $logger   = Koha::Logger->get;

    $logger->debug("SAML2 middleware handling: $method $path");

    # Route to appropriate handler
    if ( $path eq '/cgi-bin/koha/saml2/login' && $method eq 'GET' ) {
        return $self->_handle_login( $req, $provider, $hostname );
    } elsif ( $path eq '/cgi-bin/koha/saml2/acs' && $method eq 'POST' ) {
        return $self->_handle_acs( $req, $provider, $hostname );
    } elsif ( $path eq '/cgi-bin/koha/saml2/logout' && $method eq 'GET' ) {
        return $self->_handle_logout( $req, $provider, $hostname );
    } elsif ( $path eq '/cgi-bin/koha/saml2/sls' && $method eq 'GET' ) {
        return $self->_handle_sls( $req, $provider, $hostname );
    } elsif ( $path eq '/cgi-bin/koha/saml2/metadata' && $method eq 'GET' ) {
        return $self->_handle_metadata( $req, $provider, $hostname );
    }

    # Unknown /cgi-bin/koha/saml2/* path
    return [ 404, [ 'Content-Type' => 'text/plain' ], ['Not found'] ];
}

# -------------------------------------------------------------------------
# Handlers
# -------------------------------------------------------------------------

sub _handle_login {
    my ( $self, $req, $provider, $hostname ) = @_;

    my $target = $req->param('target') // '';
    my $logger = Koha::Logger->get;

    # Validate target to prevent open redirect
    unless ( $self->_is_allowed_url($target) ) {
        $logger->warn("SAML2: Login rejected - invalid target URL: $target");
        return $self->_error_response( 400, 'Invalid target URL' );
    }

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2: Failed to initialise SP: $@");
        return $self->_error_response( 500, 'SAML2 SP initialisation failed' );
    }

    my $idp_url;
    eval { $idp_url = $sp->authn_request_redirect($target) };
    if ($@) {
        $logger->error("SAML2: Failed to build AuthnRequest: $@");
        return $self->_error_response( 500, 'Failed to build SAML2 AuthnRequest' );
    }

    return $self->_redirect($idp_url);
}

sub _handle_acs {
    my ( $self, $req, $provider, $hostname ) = @_;

    my $logger        = Koha::Logger->get;
    my $saml_response = $req->param('SAMLResponse') // '';
    my $relay_state   = $req->param('RelayState')   // '';

    unless ($saml_response) {
        $logger->warn('SAML2 ACS: missing SAMLResponse parameter');
        return $self->_error_response( 400, 'Missing SAMLResponse' );
    }

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 ACS: SP init failed: $@");
        return $self->_error_response( 500, 'SAML2 SP initialisation failed' );
    }

    my $result;
    eval { $result = $sp->process_response( $saml_response, $relay_state ) };
    if ($@) {
        $logger->warn("SAML2 ACS: response processing failed: $@");
        return $self->_error_response( 403, 'SAML2 response validation failed' );
    }

    # Load or create a CGI::Session
    my $session_id = $req->cookies->{'CGISESSID'};
    my $session;
    eval {
        if ($session_id) {
            $session = Koha::Session->get_session( { sessionID => $session_id } );

            # If session is expired/invalid, create a new one
            $session = Koha::Session->get_session( { sessionID => '' } )
                unless $session && $session->id;
        } else {
            $session = Koha::Session->get_session( { sessionID => '' } );
        }
    };
    if ($@) {
        $logger->error("SAML2 ACS: session error: $@");
        return $self->_error_response( 500, 'Session error' );
    }

    # Store SAML data so C4::Auth / Koha::Auth::Client::SAML2 can complete login
    my $all_attrs = $result->{all_attributes} // {};

    # check_cookie_auth validates lasttime (expiry) and ip (SessionRestrictionByIP).
    # Both must be set on the ACS-created session or the next request will be
    # rejected as expired / coming from a different IP.
    $session->param( 'lasttime',             time() );
    $session->param( 'ip',                   $req->address // '' );
    $session->param( 'saml2_all_attributes', encode_json($all_attrs) );
    $session->param( 'saml2_nameid',         $result->{nameid} )
        if $result->{nameid};
    $session->param( 'saml2_session_index', $result->{session_index} )
        if $result->{session_index};

    # Resolve the matchpoint value from SAML attributes so that the
    # C4::Auth session bridge (which reads saml2_pending_matchpoint) works.
    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
    )->next;
    if ($hostname_link) {
        my $matchpoint = $hostname_link->matchpoint;
        my $saml_attr;
        $saml_attr = $mapping->{$matchpoint}{is} if $matchpoint;
        my $match_value = defined $saml_attr ? $all_attrs->{$saml_attr} : undef;
        $match_value //= $result->{nameid};
        $session->param( 'saml2_pending_matchpoint', $match_value )
            if defined $match_value;
    }

    $session->flush;

    $logger->info(
        sprintf 'SAML2 ACS: stored SAML attributes in session=%s',
        $session->id
    );

    # Validate relay state before redirecting
    my $redirect_to = $relay_state;
    unless ( $self->_is_allowed_url($redirect_to) ) {
        $logger->warn("SAML2 ACS: invalid RelayState, falling back to home: $redirect_to");
        $redirect_to = $self->_base_url();
    }

    # Build response with session cookie + redirect
    my $res = Plack::Response->new(302);
    $res->header( 'Location' => $redirect_to );
    $res->cookies->{'CGISESSID'} = {
        value    => $session->id,
        httponly => 1,
        secure   => $self->_is_https($redirect_to),
        samesite => 'Lax',
        path     => '/',
    };

    return $res->finalize;
}

sub _handle_logout {
    my ( $self, $req, $provider, $hostname ) = @_;

    my $logger = Koha::Logger->get;
    my $return = $req->param('return') // $self->_base_url();

    unless ( $self->_is_allowed_url($return) ) {
        $logger->warn("SAML2 Logout: invalid return URL: $return");
        $return = $self->_base_url();
    }

    # Check if we have a NameID in session for proper SLO
    my $session_id = $req->cookies->{'CGISESSID'};
    my $nameid;
    my $session_index;
    if ($session_id) {
        eval {
            my $session = Koha::Session->get_session( { sessionID => $session_id } );
            if ( $session && $session->id ) {
                $nameid        = $session->param('saml2_nameid');
                $session_index = $session->param('saml2_session_index');
            }
        };
    }

    if ($nameid) {
        my $sp;
        eval { $sp = $provider->build_sp($hostname) };
        if ($@) {
            $logger->error("SAML2 Logout: SP init failed: $@");

            # Fall through to plain redirect
        } else {
            my $idp_url;
            eval { $idp_url = $sp->logout_request_redirect( $nameid, $session_index, $return ) };
            unless ($@) {
                return $self->_redirect($idp_url);
            }
            $logger->warn("SAML2 Logout: could not build LogoutRequest: $@");
        }
    }

    # No NameID or SLO unavailable — redirect directly
    return $self->_redirect($return);
}

sub _handle_sls {
    my ( $self, $req, $provider, $hostname ) = @_;

    my $logger = Koha::Logger->get;

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 SLS: SP init failed: $@");
        return $self->_error_response( 500, 'SAML2 SP initialisation failed' );
    }

    my $relay_state;
    eval { $relay_state = $sp->process_logout_response( $req->env->{QUERY_STRING} // '' ); };
    if ($@) {
        $logger->warn("SAML2 SLS: logout response validation failed: $@");
        return $self->_error_response( 400, 'SAML2 logout response validation failed' );
    }

    my $return =
        ( $relay_state && $self->_is_allowed_url($relay_state) )
        ? $relay_state
        : $self->_base_url();

    return $self->_redirect($return);
}

sub _handle_metadata {
    my ( $self, $req, $provider, $hostname ) = @_;

    my $logger = Koha::Logger->get;

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 Metadata: SP init failed: $@");
        return $self->_error_response( 500, 'SAML2 SP initialisation failed' );
    }

    my $xml;
    eval { $xml = $sp->sp_metadata_xml() };
    if ($@) {
        $logger->error("SAML2 Metadata: failed to generate metadata: $@");
        return $self->_error_response( 500, 'Failed to generate SP metadata' );
    }

    return [
        200,
        [ 'Content-Type' => 'application/samlmetadata+xml; charset=UTF-8' ],
        [$xml],
    ];
}

# -------------------------------------------------------------------------
# Private helpers
# -------------------------------------------------------------------------

=head2 _request_hostname

  my $hostname = $self->_request_hostname($env);

Extracts the bare hostname (without port) from the request environment.
Returns C<undef> if no hostname can be determined.

=cut

sub _request_hostname {
    my ( $self, $env ) = @_;
    my $hostname = $env->{HTTP_HOST} // $env->{SERVER_NAME} // '';
    $hostname =~ s/:\d+$//;
    return $hostname || undef;
}

=head2 _get_provider

  my $provider = $self->_get_provider($env);

Looks up the enabled SAML2 identity provider for the request hostname.
Returns the provider object, or undef if not found.

=cut

sub _get_provider {
    my ( $self, $env ) = @_;

    my $hostname = $self->_request_hostname($env);

    return unless $hostname;

    my $provider = Koha::Auth::Identity::Providers->search(
        {
            'me.protocol'          => 'SAML2',
            'me.enabled'           => 1,
            'hostname.hostname'    => $hostname,
            'hostnames.is_enabled' => 1,
        },
        { join => { hostnames => 'hostname' }, rows => 1 }
    )->next;

    return $provider;
}

sub _redirect {
    my ( $self, $url ) = @_;
    return [
        302,
        [ 'Location' => $url, 'Content-Type' => 'text/plain' ],
        ['Redirecting...'],
    ];
}

sub _error_response {
    my ( $self, $status, $message ) = @_;
    return [
        $status,
        [ 'Content-Type' => 'text/plain' ],
        [$message],
    ];
}

sub _base_url {
    my ($self) = @_;
    my $url =
           C4::Context->preference('OPACBaseURL')
        || C4::Context->preference('staffClientBaseURL')
        || '/';
    return $url;
}

sub _is_allowed_url {
    my ( $self, $url ) = @_;

    return 0 unless defined $url && length $url;

    # Must be an absolute URL that starts with a known Koha base URL
    # (prevents open redirect attacks)
    my $opac_base     = C4::Context->preference('OPACBaseURL')        // '';
    my $intranet_base = C4::Context->preference('staffClientBaseURL') // '';

    for my $base ( $opac_base, $intranet_base ) {
        next unless length $base;

        # Normalise - ensure base doesn't end with /
        $base =~ s{/+$}{};
        return 1 if index( $url, $base ) == 0;
    }

    # Also allow relative paths (e.g. /cgi-bin/koha/...)
    return 1 if $url =~ m{^/[^/]};

    return 0;
}

sub _is_https {
    my ( $self, $url ) = @_;
    return ( defined $url && $url =~ m{^https://} ) ? 1 : 0;
}

1;

=head1 SEE ALSO

L<Koha::Auth::SAML2>, L<C4::Auth_with_shibboleth>, L<Plack::Middleware>

=head1 AUTHORS

Koha Development Team

=cut
