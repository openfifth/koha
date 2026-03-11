package C4::Auth_with_cas;

# Copyright 2009 BibLibre SARL
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
use base 'Exporter';

BEGIN {
    our @EXPORT_OK =
        qw(check_api_auth_cas checkpw_cas login_cas logout_cas login_cas_url logout_if_required multipleAuth getMultipleAuth);
}

use C4::Context;
use Koha::AuthUtils qw( get_script_name );
use Authen::CAS::Client;
use CGI qw ( -utf8 );
use URI::Escape;

use Koha::Auth::Identity::Providers;
use Koha::Logger;

=head1 Subroutines

=cut

=head2 multipleAuth

Returns true when more than one enabled CAS identity provider is configured.

=cut

sub multipleAuth {
    return Koha::Auth::Identity::Providers->search( { protocol => 'CAS', enabled => 1 } )->count > 1;
}

=head2 getMultipleAuth

Returns a hashref of C<< { provider_code => server_url } >> for all enabled
CAS identity providers.

=cut

sub getMultipleAuth {
    my %servers;
    my $providers = Koha::Auth::Identity::Providers->search( { protocol => 'CAS', enabled => 1 } );
    while ( my $p = $providers->next ) {
        $servers{ $p->code } = $p->get_config->{server_url};
    }
    return \%servers;
}

=head2 logout_cas

Redirect the browser to the CAS server logout URL.  C<$provider_code> is the
identity provider code stored in the session; if omitted the first enabled
CAS provider is used.

=cut

sub logout_cas {
    my ( $query, $type, $provider_code ) = @_;
    my $provider = _get_cas_provider($provider_code);
    return unless $provider;

    my $config = $provider->get_config;
    my $uri    = _url_with_get_params( $query, $type );

    # We don't want to keep triggering a logout, if we got here,
    # the borrower is already logged out of Koha
    $uri =~ s/\?logout\.x=1//;

    my $cas        = Authen::CAS::Client->new( $config->{server_url} );
    my $logout_url = $cas->logout_url( url => $uri );
    my $version    = $config->{version} || '2';
    $logout_url =~ s/url=/service=/ if $version eq '3';

    print $query->redirect($logout_url);
}

=head2 login_cas

Redirect the browser to the CAS login URL.

=cut

sub login_cas {
    my ( $query, $type ) = @_;
    my $provider = _get_cas_provider( $query->param('cas_provider') );
    return unless $provider;
    my $uri = _url_with_get_params_for_provider( $query, $type, $provider );
    my $cas = Authen::CAS::Client->new( $provider->get_config->{server_url} );
    print $query->redirect( $cas->login_url($uri) );
}

=head2 login_cas_url

Returns the CAS login URL for the provider identified by C<$key> (a provider
code), or the first enabled CAS provider when C<$key> is not given.

The provider code is encoded into the returned service URL so that it is
available when CAS redirects back with a ticket.

=cut

sub login_cas_url {
    my ( $query, $key, $type ) = @_;
    my $provider = _get_cas_provider($key);
    return undef unless $provider;
    my $uri = _url_with_get_params_for_provider( $query, $type, $provider );
    my $cas = Authen::CAS::Client->new( $provider->get_config->{server_url} );
    return $cas->login_url($uri);
}

=head2 checkpw_cas

Validates a CAS service ticket.  The identity provider is identified by the
C<cas_provider> CGI parameter that CAS echoed back in the redirect URL.

Returns C<(1, cardnumber, userid, ticket, patron)> on success or C<0> on
failure.

=cut

sub checkpw_cas {
    my ( $ticket, $query, $type ) = @_;
    return 0 unless $ticket;

    my $provider = _get_cas_provider( $query->param('cas_provider') );
    return 0 unless $provider;

    my $config = $provider->get_config;
    my $uri    = _url_with_get_params_for_provider( $query, $type, $provider );
    my $cas    = Authen::CAS::Client->new( $config->{server_url} );

    my $val = $cas->service_validate( $uri, $ticket );

    if ( $val->is_success() ) {
        my $userid = $val->user();
        my $patron = Koha::Patrons->find_by_identifier($userid);
        if ($patron) {
            return ( 1, $patron->cardnumber, $patron->userid, $ticket, $patron );
        }
        Koha::Logger->get->info( "CAS provider '" . $provider->code . "': user $userid is not a valid Koha user" );
    } else {
        my $logger = Koha::Logger->get;
        $logger->debug( "CAS provider '" . $provider->code . "': problem validating ticket: $ticket" );
        $logger->debug( "Authen::CAS::Client::Response::Error: " . $val->error() )     if $val->is_error();
        $logger->debug( "Authen::CAS::Client::Response::Failure: " . $val->message() ) if $val->is_failure();
    }

    return 0;
}

=head2 check_api_auth_cas

Proxy CAS ticket validation used by the API auth path.

=cut

sub check_api_auth_cas {
    my ( $PT, $query, $type ) = @_;
    return 0 unless $PT;

    my $provider = _get_cas_provider( $query->param('cas_provider') );
    return 0 unless $provider;

    my $config = $provider->get_config;
    my $uri    = _url_with_get_params_for_provider( $query, $type, $provider );
    my $cas    = Authen::CAS::Client->new( $config->{server_url} );

    my $r = $cas->proxy_validate( $uri, $PT );

    if ( $r->is_success ) {
        my $userid = $r->user;
        my $patron = Koha::Patrons->find_by_identifier($userid);
        if ($patron) {
            return ( 1, $patron->cardnumber, $userid, $PT );
        }
        Koha::Logger->get->info("CAS proxy user $userid is not a valid Koha user");
    } else {
        Koha::Logger->get->debug("CAS proxy ticket authentication failed");
    }

    return 0;
}

=head2 logout_if_required

If using CAS, this subroutine will trigger single-signout of the CAS server.

=cut

sub logout_if_required {
    my ($query) = @_;

    # Check we haven't been hit by a logout call
    my $xml = $query->param('logoutRequest');
    return 0 unless $xml;

    my $dom = XML::LibXML->load_xml( string => $xml );
    my $ticket;
    foreach my $node ( $dom->findnodes('/samlp:LogoutRequest') ) {

        # We got a cas single logout request from a cas server;
        $ticket = $node->findvalue('./samlp:SessionIndex');
    }

    return 0 unless $ticket;

    # We've been called as part of the single logout destroy the session associated with the cas ticket
    my $params  = C4::Auth::_get_session_params();
    my $success = CGI::Session->find( $params->{dsn}, sub { delete_cas_session( @_, $ticket ) }, $params->{dsn_args} );

    print $query->header;
    exit;
}

=head2 delete_cas_session

Missing POD for delete_cas_session.

=cut

sub delete_cas_session {
    my $session = shift;
    my $ticket  = shift;
    if ( $session->param('cas_ticket') && $session->param('cas_ticket') eq $ticket ) {
        $session->delete;
        $session->flush;
    }
}

# Returns an enabled CAS identity provider by code, or the first enabled one
# when $code is not given.
sub _get_cas_provider {
    my ($code) = @_;
    if ($code) {
        return Koha::Auth::Identity::Providers->search( { code => $code, protocol => 'CAS', enabled => 1 } )->next;
    }
    return Koha::Auth::Identity::Providers->search(
        { protocol => 'CAS', enabled => 1 },
        { order_by => 'identity_provider_id' }
    )->next;
}

# Build the service URL for $provider, appending cas_provider=<code> so that
# CAS echoes it back in the redirect and we can identify the provider on return.
sub _url_with_get_params_for_provider {
    my ( $query, $type, $provider ) = @_;
    my $uri = _url_with_get_params( $query, $type );
    my $sep = ( $uri =~ /\?/ ) ? '&' : '?';
    return $uri . $sep . 'cas_provider=' . URI::Escape::uri_escape( $provider->code );
}

# Get the current URL with parameters contained directly in the URL (GET params).
# This method replaces $query->url() which gives both GET and POST params.
sub _url_with_get_params {
    my $query = shift;
    my $type  = shift;

    my $uri_base_part =
        ( $type eq 'opac' )
        ? C4::Context->preference('OPACBaseURL')
        : C4::Context->preference('staffClientBaseURL');
    $uri_base_part .= get_script_name();

    my $uri_params_part = '';
    foreach my $param ( $query->url_param() ) {

        # url_param() always returns parameters that were deleted by delete()
        # This additional check ensures that parameter was not deleted.
        my $uriPiece = $query->param($param);
        if ($uriPiece) {
            $uri_params_part .= '&' if $uri_params_part;
            $uri_params_part .= $param . '=';
            $uri_params_part .= URI::Escape::uri_escape($uriPiece);
        }
    }
    $uri_base_part .= '?' if $uri_params_part;

    return $uri_base_part . $uri_params_part;
}

1;
__END__

=head1 NAME

C4::Auth_with_cas - CAS authentication for Koha via Identity Providers

=head1 SYNOPSIS

  use C4::Auth_with_cas;

=head1 DESCRIPTION

CAS authentication is configured through the Identity Providers admin interface
(Admin > Identity providers).  Create a provider with protocol C<CAS> and set
C<server_url> (and optionally C<version>) in the configuration.

=head1 SEE ALSO

CGI(3), Authen::CAS::Client

=cut
