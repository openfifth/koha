package C4::Auth_with_shibboleth;

# Copyright 2014 PTFS Europe
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

our ( @ISA, @EXPORT_OK );

BEGIN {
    require Exporter;
    @ISA       = qw(Exporter);
    @EXPORT_OK = qw(shib_ok logout_shib login_shib_url checkpw_shib get_login_shib);
}

use C4::Context;
use JSON qw( decode_json );
use Koha::Auth::Client::SAML2;
use Koha::Auth::Identity::Providers;
use Koha::AuthUtils qw( get_script_name );
use Koha::Logger;
use Koha::Session;

use Carp qw( carp );

=head1 NAME

C4::Auth_with_shibboleth

=head1 SYNOPSIS

  use C4::Auth_with_shibboleth;

=head1 DESCRIPTION

This module provides the Shibboleth/SAML2 authentication interface for Koha.
It supports both IPC mode (OS-level mod_shib / libshibsp) and native mode
(Koha built-in SAML2 SP via L<Koha::Middleware::SAML2>).

The heavy lifting is delegated to L<Koha::Auth::Client::SAML2>.

=head1 FUNCTIONS

=head2 shib_ok

Returns true if at least one enabled SAML2 identity provider is configured in
the identity providers table for the current hostname.

=cut

sub shib_ok {
    return _get_shib_config() ? 1 : 0;
}

=head2 logout_shib

Sends a logout redirect to the Shibboleth/SAML2 logout endpoint.

  logout_shib($query);

=cut

sub logout_shib {
    my ($query) = @_;
    my $url = Koha::Auth::Client::SAML2->new->logout_url($query);
    print $query->redirect($url);
}

=head2 login_shib_url

Given a query object, returns the Shibboleth login URL with a callback to the
requesting page.

  my $shibLoginURL = login_shib_url($query);

=cut

sub login_shib_url {
    my ($query) = @_;
    return Koha::Auth::Client::SAML2->new->login_url($query);
}

=head2 get_login_shib

Returns the Shibboleth login attribute (matchpoint value) for the current
request. For IPC mode the value comes from the HTTP environment variable set
by mod_shib. For native mode it should be read from the CGI::Session by
C4::Auth after the SAML2 ACS callback.

  my $shib_login = get_login_shib();

=cut

sub get_login_shib {

    # Get shibboleth config to find the matchpoint attribute name
    my $config = _get_shib_config();
    return '' unless $config;

    my $matchAttribute = $config->{mapping}->{ $config->{matchpoint} }->{is};
    return '' unless $matchAttribute;

    if ( C4::Context->psgi_env ) {
        return $ENV{ 'HTTP_' . uc($matchAttribute) } || '';
    } else {
        return $ENV{$matchAttribute} || '';
    }
}

=head2 checkpw_shib

Given a matchpoint attribute value (and optionally a hashref of all SAML
attributes from the assertion), checks for a matching Koha patron.

  my ( $retval, $retcard, $retuserid, $patron ) =
      checkpw_shib( $match_value, \%saml_attributes );

On success returns C<(1, $cardnumber, $userid, $patron)>.
Returns C<0> on failure.

When C<$saml_attributes> is not provided (e.g. when called from C<C4::Auth>
in native SAML2 mode), this function attempts to load SAML attributes from the
current CGI::Session (stored by L<Koha::Middleware::SAML2> during ACS
processing).

=cut

sub checkpw_shib {
    my ( $match, $saml_attributes ) = @_;

    # Try native SAML2 session first (attributes stored by Koha::Middleware::SAML2)
    unless ( defined $saml_attributes ) {
        my $session_id = _get_session_id_from_env();
        if ($session_id) {
            eval {
                my $session = Koha::Session->get_session( { sessionID => $session_id } );
                if ( $session && $session->id ) {
                    my $json = $session->param('saml2_all_attributes');
                    $saml_attributes = decode_json($json) if $json;
                }
            };
        }
    }

    # IPC mode fallback: build SAML attribute hash from HTTP environment variables
    # using the provider mapping config. Also emits the expected debug log entries.
    unless ( defined $saml_attributes ) {
        my $config = _get_shib_config();
        if ( $config && $config->{mapping} ) {
            $saml_attributes = {};
            while ( my ( $koha_field, $entry ) = each %{ $config->{mapping} } ) {
                my $attr_name = $entry->{is};
                next unless $attr_name;
                my $value =
                    C4::Context->psgi_env
                    ? ( $ENV{ 'HTTP_' . uc($attr_name) } // $entry->{content} )
                    : ( $ENV{$attr_name} // $entry->{content} );
                $saml_attributes->{$attr_name} = $value if defined $value;
            }
        }
    }

    my $hostname = _request_hostname();
    return Koha::Auth::Client::SAML2->new->checkpw( $match, $saml_attributes, $hostname );
}

sub _get_session_id_from_env {

    # Try to extract CGISESSID from the HTTP_COOKIE env var
    my $cookie_str = $ENV{HTTP_COOKIE} // '';
    if ( $cookie_str =~ /(?:^|;\s*)CGISESSID=([^;]+)/ ) {
        return $1;
    }
    return;
}

# -------------------------------------------------------------------------
# Private helpers
# -------------------------------------------------------------------------

sub _request_hostname {

    # In Plack/CGI-emulation mode SERVER_NAME is set to the proxy target
    # (typically 'localhost'), while HTTP_HOST carries the actual vhost name
    # from the preserved Host: header.  Prefer HTTP_HOST and strip any port.
    my $hostname = $ENV{HTTP_HOST} // $ENV{SERVER_NAME} // '';
    $hostname =~ s/:\d+$//;
    return $hostname;
}

sub _get_shib_config {
    my $hostname     = _request_hostname();
    my @h_candidates = Koha::Auth::Identity::Providers->hostname_candidates($hostname);
    my $provider     = Koha::Auth::Identity::Providers->search(
        {
            'me.protocol'          => 'SAML2',
            'me.enabled'           => 1,
            'hostname.hostname'    => \@h_candidates,
            'hostnames.is_enabled' => 1,
        },
        { prefetch => [ 'mappings', { 'hostnames' => 'hostname' } ], rows => 1 }
    )->next;
    return 0 unless $provider;

    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $provider->hostnames->search(
        { 'hostname.hostname' => \@h_candidates },
        { join                => 'hostname' }
    )->next;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    unless ($matchpoint) {
        carp 'shibboleth matchpoint not defined';
        return 0;
    }

    unless ( defined $mapping->{$matchpoint}->{is} ) {
        carp 'shibboleth matchpoint not mapped';
        return 0;
    }

    my $saml2_config = $provider->get_config // {};

    my $config = {
        provider   => $provider,
        matchpoint => $matchpoint,
        mapping    => $mapping,
        autocreate => $saml2_config->{autocreate} || 0,
        sync       => $saml2_config->{sync}       || 0,
        welcome    => $saml2_config->{welcome}    || 0,
    };

    my $logger = Koha::Logger->get;
    $logger->debug( 'koha borrower field to match: ' . $config->{matchpoint} );
    $logger->debug( 'shibboleth attribute to match: ' . $mapping->{ $config->{matchpoint} }->{is} );

    return $config;
}

sub _get_uri {
    my $protocol  = 'https://';
    my $interface = C4::Context->interface;

    my $uri =
        $interface eq 'intranet'
        ? C4::Context->preference('staffClientBaseURL')
        : C4::Context->preference('OPACBaseURL');

    $uri or Koha::Logger->get->warn('Syspref staffClientBaseURL or OPACBaseURL not set!');
    $uri ||= '';

    if ( $uri =~ m{(.*?)://(.*)$} ) {
        my $oldprotocol = $1;
        if ( $oldprotocol ne 'https' ) {
            Koha::Logger->get->warn('Shibboleth requires OPACBaseURL/staffClientBaseURL to use the https protocol!');
        }
        $uri = $2;
    }
    return $protocol . $uri;
}

sub _get_return {
    my ($query) = @_;

    my $uri_base_part = _get_uri() . get_script_name();

    my $uri_params_part = '';
    foreach my $param ( sort $query->url_param() ) {
        my $uriPiece = $query->param($param);
        if ($uriPiece) {
            $uri_params_part .= '&' if $uri_params_part;
            $uri_params_part .= $param . '=';
            $uri_params_part .= $uriPiece;
        }
    }
    $uri_base_part .= '%3F' if $uri_params_part;

    return $uri_base_part . URI::Escape::uri_escape_utf8($uri_params_part);
}

1;
__END__

=head1 CONFIGURATION

Shibboleth/SAML2 providers are configured via the identity providers admin UI
(C</cgi-bin/koha/admin/identity_providers.pl>). Both IPC mode (mod_shib) and
native mode (Koha built-in SP) are supported.

=head1 SEE ALSO

L<Koha::Auth::Client::SAML2>, L<Koha::Auth::SAML2>, L<Koha::Middleware::SAML2>

=cut
