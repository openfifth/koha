package Koha::App::Controller::SAML2;

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

use Mojo::Base 'Mojolicious::Controller';

use JSON      qw( decode_json encode_json );
use Net::CIDR qw( range2cidr cidrlookup );

use C4::Auth qw( create_basic_session );
use C4::Context;
use File::Spec;
use Koha::Auth::Client::SAML2;
use Koha::Auth::Identity::Providers;
use Koha::Logger;

=encoding utf8

=head1 NAME

Koha::App::Controller::SAML2 - Mojolicious controller for SAML2 SP endpoints

=head1 DESCRIPTION

Handles the SAML2 protocol for identity providers configured with C<mode=native>.

Registered at C</auth/saml2/*> by L<Koha::App::Plugin::SAML2>.

=head1 METHODS

=head2 login

C<GET /auth/saml2/login>

Initiates SP-initiated SSO.  Redirects the browser to the IdP with a SAML2
AuthnRequest.  The C<target> query parameter (the page to return to after
login) is carried as the RelayState.

=cut

sub login {
    my ($c) = @_;

    my $logger   = Koha::Logger->get;
    my $hostname = _request_hostname($c);
    my $provider = _get_provider($hostname);

    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 login: no native provider for " . ( $hostname // '?' ) );
        return $c->reply->not_found;
    }

    my $target = $c->req->param('target') // '';
    unless ( _is_allowed_url($target) ) {
        $logger->warn("SAML2 login: invalid target URL: $target");
        return $c->render( status => 400, text => 'Invalid target URL' );
    }

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 login: SP init failed: $@");
        return $c->render( status => 500, text => 'SAML2 SP initialisation failed' );
    }

    my $idp_url;
    eval { $idp_url = $sp->authn_request_redirect($target) };
    if ($@) {
        $logger->error("SAML2 login: failed to build AuthnRequest: $@");
        return $c->render( status => 500, text => 'Failed to build SAML2 AuthnRequest' );
    }

    return $c->redirect_to($idp_url);
}

=head2 acs

C<POST /auth/saml2/acs>

Assertion Consumer Service.  Receives the SAMLResponse from the IdP,
validates it, authenticates (or auto-creates) the patron, establishes a
full Koha session, sets the CGISESSID cookie, and redirects to the
original target URL (RelayState).

=cut

sub acs {
    my ($c) = @_;

    my $logger        = Koha::Logger->get;
    my $hostname      = _request_hostname($c);
    my $interface     = $c->stash('interface')         // 'opac';
    my $saml_response = $c->req->param('SAMLResponse') // '';
    my $relay_state   = $c->req->param('RelayState')   // '';

    unless ($saml_response) {
        $logger->warn('SAML2 ACS: missing SAMLResponse parameter');
        return $c->render( status => 400, text => 'Missing SAMLResponse' );
    }

    my $provider = _get_provider($hostname);
    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 ACS: no native provider for " . ( $hostname // '?' ) );
        return $c->reply->not_found;
    }

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 ACS: SP init failed: $@");
        return $c->render( status => 500, text => 'SAML2 SP initialisation failed' );
    }

    my $result;
    eval { $result = $sp->process_response( $saml_response, $relay_state ) };
    if ($@) {
        $logger->warn("SAML2 ACS: response processing failed: $@");
        return $c->render( status => 403, text => 'SAML2 response validation failed' );
    }

    my $all_attrs = $result->{all_attributes} // {};

    my $client = Koha::Auth::Client::SAML2->new;
    my ( $patron, $auth_error ) = $client->authenticate(
        {
            provider  => $provider,
            data      => $all_attrs,
            hostname  => $hostname,
            interface => $interface,
        }
    );

    unless ($patron) {
        $logger->warn("SAML2 ACS: authentication failed: $auth_error");
        return $c->render( status => 403, text => 'SAML2 authentication failed' );
    }

    $logger->info( 'SAML2 ACS: authenticated borrowernumber=' . $patron->borrowernumber );

    my $session = create_basic_session( { patron => $patron, interface => $interface } );
    $session->param( 'idp_code',             $provider->code );
    $session->param( 'saml2_all_attributes', encode_json($all_attrs) );
    $session->param( 'saml2_nameid',         $result->{nameid} )
        if $result->{nameid};
    $session->param( 'saml2_session_index', $result->{session_index} )
        if $result->{session_index};
    $session->flush;

    $logger->info(
        sprintf 'SAML2 ACS: session=%s nameid=%s attributes=%s',
        $session->id,
        $result->{nameid} // '(none)',
        join( ', ', sort keys %$all_attrs ) || '(none)',
    );

    # Debug logging (for the /auth/saml2/attributes page)
    my $saml2_config = $provider->get_config // {};
    if ( $saml2_config->{debug} ) {
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

    my $redirect_to = $relay_state;
    unless ( _is_allowed_url($redirect_to) ) {
        $logger->warn("SAML2 ACS: invalid RelayState, falling back to home: $redirect_to");
        $redirect_to = _base_url();
    }

    $c->cookie(
        'CGISESSID' => $session->id,
        {
            path     => '/',
            httponly => 1,
            secure   => ( $c->req->headers->header('X-Forwarded-Proto') // $c->req->url->base->scheme // '' ) eq 'https'
            ? 1
            : 0,
            samesite => 'Lax',
        }
    );

    return $c->redirect_to($redirect_to);
}

=head2 logout

C<GET /auth/saml2/logout>

Initiates Single Logout.  If a NameID is present in the session, redirects
to the IdP with a LogoutRequest.  Otherwise redirects directly to the
C<return> parameter (or the base URL).

=cut

sub logout {
    my ($c) = @_;

    my $logger   = Koha::Logger->get;
    my $hostname = _request_hostname($c);
    my $provider = _get_provider($hostname);

    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 logout: no native provider for " . ( $hostname // '?' ) );
        return $c->reply->not_found;
    }

    my $return = $c->req->param('return') // _base_url();
    unless ( _is_allowed_url($return) ) {
        $logger->warn("SAML2 logout: invalid return URL: $return");
        $return = _base_url();
    }

    my $nameid;
    my $session_index;
    if ( my $session_id = $c->cookie('CGISESSID') ) {
        eval {
            require Koha::Session;
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
        unless ($@) {
            my $idp_url;
            eval { $idp_url = $sp->logout_request_redirect( $nameid, $session_index, $return ) };
            unless ($@) {
                return $c->redirect_to($idp_url);
            }
            $logger->warn("SAML2 logout: could not build LogoutRequest: $@");
        } else {
            $logger->error("SAML2 logout: SP init failed: $@");
        }
    }

    return $c->redirect_to($return);
}

=head2 sls

C<GET /auth/saml2/sls>

Single Logout Service.  Receives the LogoutResponse from the IdP, validates
it, and redirects to the RelayState URL (or the base URL).

=cut

sub sls {
    my ($c) = @_;

    my $logger   = Koha::Logger->get;
    my $hostname = _request_hostname($c);
    my $provider = _get_provider($hostname);

    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 SLS: no native provider for " . ( $hostname // '?' ) );
        return $c->reply->not_found;
    }

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 SLS: SP init failed: $@");
        return $c->render( status => 500, text => 'SAML2 SP initialisation failed' );
    }

    my $relay_state;
    eval { $relay_state = $sp->process_logout_response( $c->req->url->query->to_string ) };
    if ($@) {
        $logger->warn("SAML2 SLS: logout response validation failed: $@");
        return $c->render( status => 400, text => 'SAML2 logout response validation failed' );
    }

    my $return =
        ( $relay_state && _is_allowed_url($relay_state) )
        ? $relay_state
        : _base_url();

    return $c->redirect_to($return);
}

=head2 metadata

C<GET /auth/saml2/metadata>

Returns the SP metadata XML.

=cut

sub metadata {
    my ($c) = @_;

    my $logger   = Koha::Logger->get;
    my $hostname = _request_hostname($c);
    my $provider = _get_provider($hostname);

    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 metadata: no native provider for " . ( $hostname // '?' ) );
        return $c->reply->not_found;
    }

    my $sp;
    eval { $sp = $provider->build_sp($hostname) };
    if ($@) {
        $logger->error("SAML2 metadata: SP init failed: $@");
        return $c->render( status => 500, text => 'SAML2 SP initialisation failed' );
    }

    my $xml;
    eval { $xml = $sp->sp_metadata_xml() };
    if ($@) {
        $logger->error("SAML2 metadata: failed to generate metadata: $@");
        return $c->render( status => 500, text => 'Failed to generate SP metadata' );
    }

    $c->res->headers->content_type('application/samlmetadata+xml; charset=UTF-8');
    return $c->render( data => $xml );
}

=head2 attributes

C<GET /auth/saml2/attributes>

Debug page — only available when C<debug=1> is set in the provider config.
Shows recent SAML assertions and configured mappings to help administrators
set up correct attribute mapping.

=cut

sub attributes {
    my ($c) = @_;

    my $logger   = Koha::Logger->get;
    my $hostname = _request_hostname($c);
    my $provider = _get_provider($hostname);

    unless ( $provider && $provider->is_native ) {
        $logger->warn( "SAML2 attributes: no native provider for " . ( $hostname // '?' ) );
        return $c->reply->not_found;
    }

    my $saml2_config = $provider->get_config // {};
    unless ( $saml2_config->{debug} ) {
        return $c->render(
            status => 403,
            text   =>
                'SAML2 attribute debug page is disabled. Enable "Debug mode" in the Identity Provider configuration.',
        );
    }

    my $client_ip   = $c->tx->remote_address;
    my $allowed_ips = $saml2_config->{debug_allowed_ips};
    unless ( _ip_in_allowed_range( $allowed_ips, $client_ip ) ) {
        $logger->warn("SAML2 attributes: access denied for IP $client_ip");
        return $c->render(
            status => 403,
            text   => "SAML2 debug page: your IP address ($client_ip) is not in the allowed list."
                . ' Update "Debug allowed IPs" in the Identity Provider configuration.',
        );
    }

    my $entries       = _read_debug_log( $provider->code );
    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
    )->next;
    my $matchpoint    = $hostname_link ? $hostname_link->matchpoint : undef;
    my $provider_name = $provider->description // $provider->code // '(unknown)';

    my $html = _attributes_html( $provider_name, $entries, $mapping, $matchpoint );

    $c->res->headers->content_type('text/html; charset=UTF-8');
    return $c->render( data => $html );
}

# -------------------------------------------------------------------------
# Private helpers
# -------------------------------------------------------------------------

=head2 _ip_in_allowed_range

Checks whether C<$client_ip> is contained in the space-separated list of IP
addresses / CIDR ranges given in C<$allowed_ips_str>.  When the string is
empty or undefined the default C<127.0.0.1 ::1> (localhost) is used so that
the debug page is never accidentally world-readable.

Returns true (1) if the IP is allowed, false (0) otherwise.  Errors in
the range specification are logged and treated as a deny (fail-closed).

=cut

sub _ip_in_allowed_range {
    my ( $allowed_ips_str, $client_ip ) = @_;

    my $ranges = $allowed_ips_str // '';
    $ranges =~ s/^\s+|\s+$//g;
    $ranges = '127.0.0.1 ::1' unless length $ranges;

    my @allowed = split /\s+/, $ranges;
    return 0 unless @allowed;

    my @cidr;
    eval { @cidr = range2cidr(@allowed) };
    if ($@) {
        Koha::Logger->get->warn("SAML2 debug _ip_in_allowed_range: bad range '$ranges': $@");
        return 0;
    }

    my $ok;
    eval { $ok = cidrlookup( $client_ip, @cidr ) };
    if ($@) {
        Koha::Logger->get->warn("SAML2 debug cidrlookup failed for '$client_ip': $@");
        return 0;
    }

    return $ok ? 1 : 0;
}

=head2 _request_hostname

Returns the bare hostname (no port) from the current Mojolicious request.

=cut

sub _request_hostname {
    my ($c) = @_;
    my $host = $c->req->url->base->host // '';
    $host =~ s/:\d+$//;
    return $host || undef;
}

=head2 _get_provider

Looks up the enabled SAML2 identity provider configured for the given hostname.
Returns the provider object or undef if none is found.

=cut

sub _get_provider {
    my ($hostname) = @_;
    return unless $hostname;
    return Koha::Auth::Identity::Providers->search(
        {
            'me.protocol'          => 'SAML2',
            'me.enabled'           => 1,
            'hostname.hostname'    => $hostname,
            'hostnames.is_enabled' => 1,
        },
        { join => { hostnames => 'hostname' }, rows => 1 }
    )->next;
}

=head2 _is_allowed_url

Returns true if the given URL is allowed as a redirect target (i.e. it starts
with the configured OPACBaseURL or staffClientBaseURL, or is a relative path).

=cut

sub _is_allowed_url {
    my ($url) = @_;

    return 0 unless defined $url && length $url;

    my $opac_base     = C4::Context->preference('OPACBaseURL')        // '';
    my $intranet_base = C4::Context->preference('staffClientBaseURL') // '';

    for my $base ( $opac_base, $intranet_base ) {
        next unless length $base;
        $base =~ s{/+$}{};
        return 1 if index( $url, $base ) == 0;
    }

    # Allow relative paths (e.g. /cgi-bin/koha/...)
    return 1 if $url =~ m{^/[^/]};

    return 0;
}

=head2 _base_url

Returns the base URL for the Koha instance, preferring OPACBaseURL then
staffClientBaseURL, falling back to C</>.

=cut

sub _base_url {
    return
           C4::Context->preference('OPACBaseURL')
        || C4::Context->preference('staffClientBaseURL')
        || '/';
}

=head2 _debug_log_path

Returns the filesystem path to the JSONL debug log file for the given provider
code. Lives in the instance log directory (not a world-readable temp dir) as
entries contain NameIDs and assertion attributes.

=cut

sub _debug_log_path {
    my ($provider_code) = @_;
    ( my $safe = $provider_code // 'unknown' ) =~ s/[^A-Za-z0-9_-]/_/g;
    my $dir = C4::Context->config('logdir') || File::Spec->tmpdir;
    return "$dir/koha_saml2_debug_${safe}.jsonl";
}

=head2 _log_debug_assertion

Appends a SAML2 assertion debug entry (as JSON) to the provider's debug log file,
keeping only the most recent 20 entries.

=cut

sub _log_debug_assertion {
    my ( $provider_code, $data ) = @_;

    my $path = _debug_log_path($provider_code);

    my @lines;
    if ( open my $fh, '<', $path ) {
        @lines = <$fh>;
        close $fh;
    }
    chomp @lines;

    # Only a session ID prefix is recorded: enough to correlate with other
    # logs, useless for session hijacking should the file leak
    my $session_id = $data->{session_id} // '';
    $session_id = substr( $session_id, 0, 8 ) . '...' if length $session_id > 8;

    my $entry = encode_json(
        {
            ts            => time(),
            nameid        => $data->{nameid}        // '',
            session_index => $data->{session_index} // '',
            session_id    => $session_id,
            matchpoint    => $data->{matchpoint}     // '',
            match_value   => $data->{match_value}    // '',
            attributes    => $data->{all_attributes} // {},
        }
    );

    push @lines, $entry;
    @lines = @lines[ -20 .. $#lines ] if @lines > 20;

    if ( open my $fh, '>', $path ) {
        print $fh "$_\n" for @lines;
        close $fh;
        chmod 0600, $path;
    }

    return;
}

=head2 _read_debug_log

Reads and parses the debug log file for the given provider code.
Returns an arrayref of assertion entry hashrefs, newest first.

=cut

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

    return [ reverse @entries ];
}

=head2 _attributes_html

Generates the HTML debug page showing recent SAML assertions, attribute mappings,
and matchpoint configuration for the given provider.

=cut

sub _attributes_html {
    my ( $provider_name, $entries, $mapping, $matchpoint ) = @_;

    my $esc = sub {
        my $s = shift // '';
        $s =~ s/&/&amp;/g;
        $s =~ s/</&lt;/g;
        $s =~ s/>/&gt;/g;
        return $s;
    };

    my %saml_to_koha;
    for my $koha_field ( keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is};
        $saml_to_koha{$saml_attr} = $koha_field if $saml_attr;
    }

    my $matchpoint_saml_attr =
          ( $matchpoint && $mapping->{$matchpoint} )
        ? ( $mapping->{$matchpoint}{is} // '' )
        : '';

    my $map_rows = '';
    for my $koha_field ( sort keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is} // '';
        $map_rows .= sprintf(
            '<tr><td>%s</td><td>%s</td></tr>',
            $esc->($koha_field), $esc->($saml_attr)
        );
    }
    $map_rows ||= '<tr><td colspan="2"><em>No mappings configured.</em></td></tr>';

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
  <p class="warn"><strong>&#9888; Security warning:</strong> This debug page exposes sensitive data including SAML NameIDs, session identifiers, and attribute values. Access is restricted to IP addresses listed in <em>Debug allowed IPs</em>. <strong>Disable debug mode when you are finished troubleshooting.</strong></p>

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

1;

=head1 SEE ALSO

L<Koha::App::Plugin::SAML2>, L<Koha::Auth::Client::SAML2>, L<Koha::Middleware::SAML2>

=head1 AUTHORS

Koha Development Team

=cut
