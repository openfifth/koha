package Koha::Auth::SAML2;

# Copyright 2026 Koha Development Team
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

use Carp            qw( croak );
use File::Temp      qw();
use Koha::DateUtils qw( dt_from_string );

use Koha::Logger;

=head1 NAME

Koha::Auth::SAML2 - Native SAML2 Service Provider for Koha

=head1 SYNOPSIS

  use Koha::Auth::SAML2;

  # From a provider object (preferred - reads config from identity providers DB)
  my $sp = Koha::Auth::SAML2->new({ provider => $provider_obj });

  # From a direct config hashref (backward compat / testing)
  my $sp = Koha::Auth::SAML2->new(\%config);

  my $redirect_url = $sp->authn_request_redirect($target_url);

=head1 DESCRIPTION

This module implements a native SAML2 Service Provider using L<Net::SAML2>.
It is used by L<Koha::App::Controller::SAML2> to handle SAML2 authentication
without requiring the OS-level Shibboleth SP package (mod_shib).

Configuration can be provided either via a C<Koha::Auth::Identity::Provider>
object (native mode, config stored in identity providers DB) or directly as a
config hashref (for backward compatibility and testing).

=head1 CONFIGURATION

When passing a config hashref, the following keys are supported:

=over 4

=item C<sp_entity_id> (required)

The Service Provider entity ID.

=item C<sp_cert> or C<sp_cert_path> (required)

SP certificate, either as an inline PEM string (C<sp_cert>) or a file path
(C<sp_cert_path>).

=item C<sp_key> or C<sp_key_path> (required)

SP private key, either as an inline PEM string (C<sp_key>) or a file path
(C<sp_key_path>).

=item C<idp_metadata> or C<idp_metadata_path> (required)

IdP metadata, either as an inline XML string (C<idp_metadata>) or a file path
(C<idp_metadata_path>).

=item C<sign_authn_requests> (optional, default 1)

Whether to sign outgoing AuthnRequests.

=back

=cut

=head1 METHODS

=head2 new

  my $sp = Koha::Auth::SAML2->new({ provider => $provider_obj });
  my $sp = Koha::Auth::SAML2->new(\%config);

Constructor. Accepts either a hashref with a C<provider> key pointing to a
C<Koha::Auth::Identity::Provider::SAML2> object, or a direct config hashref.

When given a provider object, config is read from C<< $provider->get_config() >>.

=cut

our $NET_SAML2_LOADED;

=head2 _require_net_saml2

Loads the Net::SAML2 modules on first use. Croaks with an informative message
when the optional dependency is not installed.

=cut

sub _require_net_saml2 {
    return if $NET_SAML2_LOADED;

    # Net::SAML2 is an optional (cpanfile 'recommends') dependency; loading it
    # lazily keeps this module compilable on installations without native
    # SAML2 support
    my $ok = eval {
        require Net::SAML2;
        require Net::SAML2::SP;
        require Net::SAML2::IdP;
        require Net::SAML2::Object::Response;
        require Net::SAML2::Protocol::AuthnRequest;
        require Net::SAML2::Binding::POST;
        require Net::SAML2::Binding::Redirect;
        require URN::OASIS::SAML2;
        1;
    };
    croak "SAML2 support requires the optional Net::SAML2 dependency: $@" unless $ok;

    $NET_SAML2_LOADED = 1;
    return;
}

sub new {
    my ( $class, $args ) = @_;

    _require_net_saml2();

    my $self = bless {}, $class;

    if ( ref $args eq 'HASH' && $args->{provider} ) {

        # Provider object mode: read config from the identity provider DB record
        my $provider = $args->{provider};
        $self->{config}   = $provider->get_config // {};
        $self->{hostname} = $args->{hostname};
    } else {

        # Direct config hashref mode (backward compat / testing)
        $self->{config} = $args // {};
    }

    $self->_init_sp();

    return $self;
}

=head2 authn_request_redirect

  my $idp_url = $sp->authn_request_redirect($target_url);

Generates a SAML2 AuthnRequest, encodes it using the redirect binding
(Deflate + Base64 + URL-encode), and returns the full IdP URL to redirect to.
The C<$target_url> is passed as SAML2 RelayState.

=cut

sub authn_request_redirect {
    my ( $self, $target_url ) = @_;

    croak 'target_url required' unless defined $target_url;

    my $logger = Koha::Logger->get;

    croak 'IdP metadata not configured' unless $self->{idp};
    my $idp     = $self->{idp};
    my $sso_url = $idp->sso_url('urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect');

    # Build AuthnRequest directly so we control whether NameIDPolicy is
    # included.  SP->authn_request always sets nameidpolicy_format (even to
    # ''), which produces <NameIDPolicy Format=""/> that many IdPs reject.
    # Default: omit NameIDPolicy entirely (broadest compatibility with
    # Keycloak, Azure AD, Okta, etc.).  Operators may set nameid_format in
    # the provider config to force a specific format when required.
    my $nameid_format = $self->{config}{nameid_format};
    my $authn_request = Net::SAML2::Protocol::AuthnRequest->new(
        issueinstant  => dt_from_string(),
        issuer        => $self->{sp}->issuer,
        destination   => $sso_url,
        assertion_url => $self->{acs_url},
        defined $nameid_format ? ( nameidpolicy_format => $nameid_format ) : (),
    );

    my $redirect = $self->{sp}->sso_redirect_binding( $idp, 'SAMLRequest' );
    my $url      = $redirect->get_redirect_uri( $authn_request->as_xml, $target_url );

    $logger->debug("SAML2: AuthnRequest redirect to $sso_url (RelayState=$target_url)");

    return $url;
}

=head2 process_response

  my $result = $sp->process_response( $saml_response_base64, $relay_state );

Decodes and validates a SAML2 Response from the IdP (ACS endpoint). On success
returns a hashref:

  {
    matchpoint_value => '...',   # value of the configured matchpoint attribute
    all_attributes   => { ... }, # all SAML attributes from the assertion
    relay_state      => '...',   # the RelayState parameter
  }

Dies on validation failure.

=cut

sub process_response {
    my ( $self, $saml_response_b64, $relay_state ) = @_;

    croak 'saml_response_b64 required' unless defined $saml_response_b64;

    my $logger = Koha::Logger->get;

    # Verify the response signature using the IdP signing cert.
    # handle_response() expects the raw base64 string from the POST body;
    # it decodes and verifies the XML signature internally.
    # cert('signing') returns an ArrayRef; POST->new wants a plain Str.
    my $idp_cert_arr = $self->{idp}                  ? $self->{idp}->cert('signing') : undef;
    my $idp_cert     = ref($idp_cert_arr) eq 'ARRAY' ? $idp_cert_arr->[0]            : $idp_cert_arr;
    my $post         = Net::SAML2::Binding::POST->new(
        sp => $self->{sp},
        $idp_cert ? ( cert_text => $idp_cert ) : (),
    );

    my $xml = eval { $post->handle_response($saml_response_b64) };
    croak 'SAML2 response validation failed' unless $xml;

    # Parse the Response status and extract the Assertion.
    my $response = Net::SAML2::Object::Response->new_from_xml( xml => $xml );
    croak 'SAML2 response status failure: ' . $response->status
        unless $response->status eq URN::OASIS::SAML2::STATUS_SUCCESS();

    my $assertion = $response->to_assertion;

    $logger->debug( 'SAML2: assertion received for subject: ' . ( $assertion->nameid // 'unknown' ) );

    # attributes is a HashRef[ArrayRef]: { name => [val, ...], ... }
    my $attr_hash = $assertion->attributes;
    my %attrs     = map { $_ => $attr_hash->{$_}[0] } keys %$attr_hash;

    $logger->info("SAML2: assertion processed, returning all_attributes for caller to resolve matchpoint");

    return {
        all_attributes => \%attrs,
        relay_state    => $relay_state,
        nameid         => $assertion->nameid,
        session_index  => $assertion->session,
    };
}

=head2 logout_request_redirect

  my $idp_url = $sp->logout_request_redirect($name_id, $session_index, $return_url);

Builds a SAML2 Single Logout Request using the redirect binding and returns
the IdP URL to redirect to.

=cut

sub logout_request_redirect {
    my ( $self, $name_id, $session_index, $return_url ) = @_;

    croak 'name_id required' unless defined $name_id;

    my $config = $self->{config};
    my $logger = Koha::Logger->get;
    croak 'IdP metadata not configured' unless $self->{idp};
    my $idp = $self->{idp};

    my $slo_url = $idp->slo_url('urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect');
    croak 'IdP does not support SLO via redirect binding' unless $slo_url;

    my $logout_request = $self->{sp}->logout_request(
        $slo_url,          # destination (positional)
        $name_id,          # nameid (positional)
        '',                # nameid_format (positional, empty)
        $session_index,    # session (positional)
    );

    my $redirect = $self->{sp}->slo_redirect_binding( $idp, 'SAMLRequest' );
    my $url      = $redirect->get_redirect_uri( $logout_request->as_xml, $return_url );

    $logger->debug("SAML2: LogoutRequest redirect to $slo_url");

    return $url;
}

=head2 process_logout_response

  $sp->process_logout_response( $saml_response_query_string );

Validates a SAML2 Logout Response (from IdP in response to our LogoutRequest).
Dies on validation failure.

=cut

sub process_logout_response {
    my ( $self, $query_string ) = @_;

    croak 'query_string required' unless defined $query_string;

    croak 'IdP metadata not configured' unless $self->{idp};
    my $redirect = Net::SAML2::Binding::Redirect->new(
        cert  => $self->{idp}->cert('signing'),
        param => 'SAMLResponse',
    );

    my ( $response, $relay_state ) = eval { $redirect->verify($query_string) };
    croak 'SAML2 logout response validation failed' unless $response;

    Koha::Logger->get->debug('SAML2: logout response validated');

    return $relay_state;
}

=head2 sp_metadata_xml

  my $xml = $sp->sp_metadata_xml();

Returns the SP metadata XML string, suitable for publishing at
C</cgi-bin/koha/saml2/metadata>. Includes entityID, ACS URL, SLO URL,
and the SP signing certificate.

=cut

sub sp_metadata_xml {
    my ($self) = @_;

    return $self->{sp}->metadata;
}

# -------------------------------------------------------------------------
# Private methods
# -------------------------------------------------------------------------

=head2 _init_sp

Initialises the L<Net::SAML2::SP> object from the instance config. Handles
inline PEM data by writing it to temporary files. Also loads IdP metadata
when provided. Called by C<new>.

=cut

sub _init_sp {
    my ($self) = @_;

    my $config   = $self->{config};
    my $hostname = $self->{hostname};

    # Derive entity ID from hostname if not explicitly configured.
    # When a hostname is available the ACS and SLS URLs are always
    # built from the /cgi-bin/koha/saml2/* paths on that hostname
    # so that the Koha::Middleware::SAML2 routing is consistent.
    my $entity_id;
    if ( $config->{sp_entity_id} ) {
        $entity_id = $config->{sp_entity_id};
    } elsif ($hostname) {
        $entity_id = 'https://' . $hostname;
    } else {
        croak 'sp_entity_id not configured and no hostname provided';
    }

    my $acs_url;
    my $sls_url;
    if ($hostname) {
        $acs_url = 'https://' . $hostname . '/cgi-bin/koha/saml2/acs';
        $sls_url = 'https://' . $hostname . '/cgi-bin/koha/saml2/sls';
    } else {
        $acs_url = $entity_id . '/cgi-bin/koha/saml2/acs';
        $sls_url = $entity_id . '/cgi-bin/koha/saml2/sls';
    }

    # Store ACS URL for use by authn_request_redirect
    $self->{acs_url} = $acs_url;

    # Net::SAML2::SP expects file paths for cert and key, not inline PEM data.
    # When inline PEM is configured, write it to a temp file for the duration
    # of this object's life.
    my ( $cert_path, $key_path );

    if ( $config->{sp_cert_path} ) {
        croak "SP cert file not found: $config->{sp_cert_path}" unless -f $config->{sp_cert_path};
        $cert_path = $config->{sp_cert_path};
    } elsif ( $config->{sp_cert} ) {
        $self->{_cert_tmp} = File::Temp->new( SUFFIX => '.pem', UNLINK => 1 );
        print { $self->{_cert_tmp} } $config->{sp_cert};
        $self->{_cert_tmp}->flush;
        $cert_path = $self->{_cert_tmp}->filename;
    } else {
        croak 'sp_cert or sp_cert_path not configured';
    }

    if ( $config->{sp_key_path} ) {
        croak "SP key file not found: $config->{sp_key_path}" unless -f $config->{sp_key_path};
        $key_path = $config->{sp_key_path};
    } elsif ( $config->{sp_key} ) {
        $self->{_key_tmp} = File::Temp->new( SUFFIX => '.pem', UNLINK => 1 );
        print { $self->{_key_tmp} } $config->{sp_key};
        $self->{_key_tmp}->flush;
        $key_path = $self->{_key_tmp}->filename;
    } else {
        croak 'sp_key or sp_key_path not configured';
    }

    # Build the Net::SAML2 SP object.
    # Use the modern assertion_consumer_service / single_logout_service ArrayRef
    # API rather than the deprecated acs_url_post / sls_url_redirect shorthands.
    # The shorthands prepend the 'url' parameter to the provided path, which
    # would corrupt an already-absolute ACS/SLS URL.
    $self->{sp} = Net::SAML2::SP->new(
        issuer                     => $entity_id,
        url                        => $entity_id,
        error_url                  => $entity_id,
        cert                       => $cert_path,
        authnreq_signed            => ( $config->{sign_authn_requests} // 1 ) ? 1 : 0,
        key                        => $key_path,
        assertion_consumer_service => [
            {
                Binding   => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
                Location  => $acs_url,
                isDefault => 'true',
            },
        ],
        single_logout_service => [
            {
                Binding  => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
                Location => $sls_url,
            },
        ],
        org_name         => 'Koha Library System',
        org_display_name => 'Koha Library System',
        org_contact      => 'admin@example.com',
    );

    # Load IdP metadata - support both inline XML and file paths
    # IdP metadata is optional at init time: sp_metadata_xml() works without it.
    # authn_request_redirect(), logout_request_redirect(), and
    # process_logout_response() will croak if called before IdP metadata is set.
    if ( defined $config->{idp_metadata} && length $config->{idp_metadata} ) {
        $self->{idp} = Net::SAML2::IdP->new_from_xml( xml => $config->{idp_metadata} );
    } elsif ( $config->{idp_metadata_path} ) {
        my $idp_metadata_path = $config->{idp_metadata_path};
        croak "IdP metadata file not found: $idp_metadata_path" unless -f $idp_metadata_path;
        $self->{idp} = Net::SAML2::IdP->new_from_file($idp_metadata_path);
    }

    return;
}

1;

=head1 SEE ALSO

L<Koha::Middleware::SAML2>, L<Koha::Auth::Client::SAML2>, L<Net::SAML2>

=head1 AUTHORS

Koha Development Team

=cut
