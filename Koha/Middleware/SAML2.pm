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

use JSON qw( decode_json encode_json );
use Plack::Request;
use Plack::Response;
use URI;

use C4::Context;
use Koha::Auth::Client::SAML2;
use Koha::Auth::Identity::Providers;
use Koha::Logger;
use Koha::Patrons;
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

=item C<GET /cgi-bin/koha/saml2/attributes>

Debug page. Only available when C<debug=1> is set in the provider config.
Shows all SAML attributes received in the current session alongside the
configured matchpoint and attribute mappings, to help administrators
configure the correct attribute mapping.

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

    my $logger = Koha::Logger->get;
    $logger->warn( "SAML2 middleware: intercepted $path (HOST=" . ( $env->{HTTP_HOST} // '?' ) . ")" );

    # All /cgi-bin/koha/saml2/* paths are hostname-specific: the metadata contains
    # ACS URLs bound to the matched hostname, so provider lookup must match.
    my $provider = $self->_get_provider($env);

    # Pass through if no provider found or not native mode
    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 middleware: no native provider found for "
                . ( $self->_request_hostname($env) // '?' )
                . " — passing through" );
        return $self->app->($env);
    }

    my $req      = Plack::Request->new($env);
    my $method   = $req->method;
    my $hostname = $self->_request_hostname($env);

    $logger->warn( "SAML2 middleware handling: $method $path (provider=" . $provider->code . ")" );

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
    } elsif ( $path eq '/cgi-bin/koha/saml2/attributes' && $method eq 'GET' ) {
        return $self->_handle_attributes( $req, $provider, $hostname );
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

    # Authenticate the patron now, while the assertion is fresh.
    # On success, store the borrowernumber so C4::Auth can establish the
    # Koha session without calling checkpw() again on the next request.
    # Derive interface from the relay_state URL (which was set from the
    # original target page).
    my $interface = 'opac';
    {
        my $staff_base = C4::Context->preference('staffClientBaseURL') // '';
        $staff_base =~ s{/+$}{};
        $interface = 'staff' if $staff_base && index( $relay_state, $staff_base ) == 0;
    }

    my $client = Koha::Auth::Client::SAML2->new;
    my ( $patron, $auth_error ) = $client->authenticate(
        {
            provider  => $provider,
            data      => $all_attrs,
            hostname  => $hostname,
            interface => $interface,
        }
    );

    if ($patron) {
        $session->param( 'saml2_authenticated_borrowernumber', $patron->borrowernumber );
        $logger->warn( 'SAML2 ACS: authenticated borrowernumber=' . $patron->borrowernumber );
    } else {
        $logger->warn("SAML2 ACS: authentication deferred: $auth_error");
    }

    # Resolve matchpoint and match_value for debug logging
    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
    )->next;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;
    my $match_value;
    if ($matchpoint) {
        my $saml_attr = $mapping->{$matchpoint}{is};
        $match_value = defined $saml_attr ? $all_attrs->{$saml_attr} : undef;
        $match_value //= $result->{nameid};
    }

    $session->flush;

    $logger->warn(
        sprintf 'SAML2 ACS: stored session=%s nameid=%s attributes=%s',
        $session->id,
        $result->{nameid} // '(none)',
        join( ', ', sort keys %$all_attrs ) || '(none)',
    );

    # When debug mode is on, append assertion data to the provider's debug log
    # so the /saml2/attributes page can show it regardless of session boundaries.
    my $saml2_config = $provider->get_config // {};
    if ( $saml2_config->{debug} ) {
        _log_debug_assertion(
            $provider->code,
            {
                nameid         => $result->{nameid},
                session_index  => $result->{session_index},
                all_attributes => $all_attrs,
                matchpoint     => $matchpoint,
                match_value    => $match_value,
                session_id     => $session->id,
            }
        );
    }

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

sub _handle_attributes {
    my ( $self, $req, $provider, $hostname ) = @_;

    my $logger = Koha::Logger->get;

    # Only available when debug mode is enabled in the provider config
    my $saml2_config = $provider->get_config // {};
    unless ( $saml2_config->{debug} ) {
        return $self->_error_response(
            403,
            'SAML2 attribute debug page is disabled. Enable "Debug mode" in the Identity Provider configuration.'
        );
    }

    # Read recent assertions from the provider's debug log file.
    # We log on every ACS call rather than relying on the browser session,
    # so this survives session boundary crossings in C4::Auth.
    my $entries = _read_debug_log( $provider->code );

    # Read matchpoint and mapping config
    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
    )->next;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    my $provider_name = $provider->description // $provider->code // '(unknown)';
    my $html          = _attributes_html( $provider_name, $entries, $mapping, $matchpoint );

    return [ 200, [ 'Content-Type' => 'text/html; charset=UTF-8' ], [$html] ];
}

sub _debug_log_path {
    my ($provider_code) = @_;

    # Sanitise provider code to a safe filename component
    ( my $safe = $provider_code // 'unknown' ) =~ s/[^A-Za-z0-9_-]/_/g;
    return "/tmp/koha_saml2_debug_${safe}.jsonl";
}

sub _log_debug_assertion {
    my ( $provider_code, $data ) = @_;

    my $path = _debug_log_path($provider_code);

    # Keep a rolling window: read existing lines, drop oldest if over limit
    my @lines;
    if ( open my $fh, '<', $path ) {
        @lines = <$fh>;
        close $fh;
    }
    chomp @lines;

    my $entry = encode_json(
        {
            ts            => time(),
            nameid        => $data->{nameid}         // '',
            session_index => $data->{session_index}  // '',
            session_id    => $data->{session_id}     // '',
            matchpoint    => $data->{matchpoint}     // '',
            match_value   => $data->{match_value}    // '',
            attributes    => $data->{all_attributes} // {},
        }
    );

    push @lines, $entry;

    # Keep last 20 entries
    @lines = @lines[ -20 .. $#lines ] if @lines > 20;

    if ( open my $fh, '>', $path ) {
        print $fh "$_\n" for @lines;
        close $fh;
    }

    return;
}

sub _read_debug_log {
    my ($provider_code) = @_;

    my $path = _debug_log_path($provider_code);
    return [] unless -f $path;

    my @entries;
    open my $fh, '<', $path or return [];
    while ( my $line = <$fh> ) {
        chomp $line;
        next unless $line;
        my $entry = eval { decode_json($line) };
        push @entries, $entry if $entry;
    }
    close $fh;

    # Return newest first
    return [ reverse @entries ];
}

sub _attributes_html {
    my ( $provider_name, $entries, $mapping, $matchpoint ) = @_;

    my $esc = sub {
        my $s = shift // '';
        $s =~ s/&/&amp;/g;
        $s =~ s/</&lt;/g;
        $s =~ s/>/&gt;/g;
        return $s;
    };

    # Build reverse mapping: saml_attr -> koha_field
    my %saml_to_koha;
    for my $koha_field ( keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is};
        $saml_to_koha{$saml_attr} = $koha_field if $saml_attr;
    }

    my $matchpoint_saml_attr =
          ( $matchpoint && $mapping->{$matchpoint} )
        ? ( $mapping->{$matchpoint}{is} // '' )
        : '';

    # Configured mappings table (shown once, applies to all assertions)
    my $map_rows = '';
    for my $koha_field ( sort keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is} // '';
        $map_rows .= sprintf(
            '<tr><td>%s</td><td>%s</td></tr>',
            $esc->($koha_field), $esc->($saml_attr)
        );
    }
    $map_rows ||= '<tr><td colspan="2"><em>No mappings configured.</em></td></tr>';

    # Matchpoint config summary
    my $mp_html;
    if ($matchpoint) {
        my $mp_attr_display =
            $matchpoint_saml_attr ? $esc->($matchpoint_saml_attr) : '<em>(not mapped to a SAML attribute)</em>';
        $mp_html = sprintf(
                  '<table><tr><th>Koha matchpoint field</th><td>%s</td></tr>'
                . '<tr><th>Mapped SAML attribute</th><td>%s</td></tr></table>',
            $esc->($matchpoint), $mp_attr_display
        );
    } else {
        $mp_html = '<p style="color:red">No matchpoint configured for this hostname.</p>';
    }

    # Assertion log entries
    my $assertions_html;
    if ( !@$entries ) {
        $assertions_html =
            '<p><em>No assertions logged yet. Attempt a login via SAML2, then reload this page.</em></p>';
    } else {
        for my $entry (@$entries) {
            my $ts        = $entry->{ts} ? localtime( $entry->{ts} ) : '(unknown)';
            my $all_attrs = $entry->{attributes}  // {};
            my $mv        = $entry->{match_value} // '';
            my $mv_status =
                length($mv)
                ? '<span style="color:green">&#10003; ' . $esc->($mv) . '</span>'
                : '<span style="color:red">&#10007; No value &mdash; patron lookup will fail</span>';

            my $attr_rows = '';
            if (%$all_attrs) {
                for my $attr ( sort keys %$all_attrs ) {
                    my $koha_field = $saml_to_koha{$attr} // '';
                    my $is_match   = $attr eq $matchpoint_saml_attr ? ' style="background:#fffbdd"' : '';
                    $attr_rows .= sprintf(
                        '<tr%s><td>%s</td><td>%s</td><td>%s</td></tr>',
                        $is_match, $esc->($attr), $esc->( $all_attrs->{$attr} ), $esc->($koha_field)
                    );
                }
            } else {
                $attr_rows =
                    '<tr><td colspan="3"><em>No SAML attribute statements received. Configure attribute mappers in your IdP.</em></td></tr>';
            }

            $assertions_html .= sprintf(
                '<details open><summary style="cursor:pointer;font-weight:bold;padding:0.4em 0">%s &mdash; NameID: %s</summary>'
                    . '<table style="margin:0.5em 0"><tr><th>NameID</th><td>%s</td></tr>'
                    . '<tr><th>Session index</th><td>%s</td></tr>'
                    . '<tr><th>Matchpoint value</th><td>%s</td></tr>'
                    . '<tr><th>Koha session ID</th><td>%s</td></tr></table>'
                    . '<table style="margin:0.5em 0"><thead><tr>'
                    . '<th>SAML attribute</th><th>Value</th><th>Mapped to Koha field</th>'
                    . '</tr></thead><tbody>%s</tbody></table></details><hr>',
                $esc->($ts),
                $esc->( $entry->{nameid}        // '' ),
                $esc->( $entry->{nameid}        // '' ) || '<em>(none)</em>',
                $esc->( $entry->{session_index} // '' ) || '<em>(none)</em>',
                $mv_status,
                $esc->( $entry->{session_id} // '' ) || '<em>(none)</em>',
                $attr_rows,
            );
        }
    }

    my $provider_name_esc = $esc->($provider_name);

    return <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>SAML2 Attribute Debug &mdash; $provider_name_esc</title>
  <style>
    body { font-family: sans-serif; margin: 2em; max-width: 1100px; }
    h1 { font-size: 1.4em; }
    h2 { font-size: 1.1em; margin-top: 1.5em; border-bottom: 1px solid #ddd; padding-bottom: 0.2em; }
    table { border-collapse: collapse; margin-top: 0.5em; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background: #f0f0f0; white-space: nowrap; }
    details { margin: 0.5em 0; }
    hr { border: none; border-top: 2px solid #eee; margin: 1em 0; }
    .warn { background: #fff3cd; border: 1px solid #ffc107; padding: 0.5em 1em; border-radius: 4px; margin-bottom: 1em; }
  </style>
</head>
<body>
  <h1>SAML2 Attribute Debug &mdash; $provider_name_esc</h1>
  <p class="warn">&#9888; This page is only visible when <strong>Debug mode</strong> is enabled in the Identity Provider configuration. Disable it in production.</p>

  <h2>Matchpoint configuration</h2>
  $mp_html

  <h2>Configured attribute mappings</h2>
  <table>
    <thead><tr><th>Koha field</th><th>SAML attribute</th></tr></thead>
    <tbody>$map_rows</tbody>
  </table>

  <h2>Recent login attempts (newest first, last 20)</h2>
  <p style="font-size:0.9em;color:#555">Each entry shows what the IdP sent during a login attempt. The highlighted row (yellow) is the attribute used as the matchpoint. After configuring mappings, attempt a login and reload this page.</p>
  $assertions_html

  <p style="margin-top:2em;font-size:0.85em;color:#666">
    Configure attribute mappings in the
    <a href="/cgi-bin/koha/admin/identity_providers.pl">Identity Providers admin UI</a>.
  </p>
</body>
</html>
HTML
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

L<Koha::Auth::SAML2>, L<Koha::Auth::Client::SAML2>, L<Plack::Middleware>

=head1 AUTHORS

Koha Development Team

=cut
