package Koha::Auth::Client::SAML2;

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

# Note: 'use parent' triggers a Perl C3 MRO merge issue with this specific
# package name ending in a digit (SAML2). Using @ISA directly works around it.
our @ISA = ('Koha::Auth::Client');

require Koha::Auth::Client;

use Carp qw( carp );
use JSON qw( decode_json );
use Try::Tiny;
use URI;
use URI::Escape qw( uri_escape_utf8 );

use C4::Context;
use C4::Letters qw( GetPreparedLetter EnqueueLetter SendQueuedMessages );
use C4::Members::Messaging;

use Koha::Auth::Identity::Provider::Hostnames;
use Koha::Auth::Identity::Providers;
use Koha::AuthUtils qw( get_script_name );
use Koha::Exceptions::Auth;
use Koha::Logger;
use Koha::Patron;
use Koha::Patron::Attribute;
use Koha::Patron::Attributes;
use Koha::Patrons;
use Koha::Session;

=encoding utf8

=head1 NAME

Koha::Auth::Client::SAML2 - Koha SAML2/Shibboleth auth client

=head1 SYNOPSIS

  use Koha::Auth::Client::SAML2;

  my $client = Koha::Auth::Client::SAML2->new;
  my ( $ok, $cardnumber, $userid, $patron ) =
      $client->checkpw( $match_value, $hostname );

=head1 DESCRIPTION

This module bridges the Shibboleth/SAML2 authentication path (both native and
IPC modes) with Koha's identity provider framework. It handles patron lookup
by matchpoint, autocreation of new patrons, data synchronisation, and welcome
emails, delegating to the identity provider's DB configuration.

Attribute loading is explicit and mode-driven:

=over 4

=item B<native> mode (C<is_native()> true)

SAML attributes are stored in the CGI session by L<Koha::Middleware::SAML2>
after assertion validation, and read back from there.

=item B<IPC> mode (C<is_native()> false)

Attributes are read directly from HTTP environment variables set by mod_shib /
libshibsp.

=back

There is no silent fallback between modes.

=head1 API

=head2 Class methods

=head3 is_enabled

    my $enabled = Koha::Auth::Client::SAML2->is_enabled;

Returns true if at least one enabled SAML2 identity provider is configured for
the current request hostname. Equivalent to the former C<C4::Auth_with_shibboleth::shib_ok>.

=cut

sub is_enabled {
    return try { _get_shib_config() ? 1 : 0 } catch { 0 };
}

=head3 get_matchpoint_value

    my $value = Koha::Auth::Client::SAML2->get_matchpoint_value;

Returns the matchpoint attribute value for the current request by reading the
appropriate HTTP environment variable.  Only meaningful in IPC (mod_shib) mode;
in native mode the value is resolved from the CGI session inside C<authenticate()>
and this method returns an empty string.

Equivalent to the former C<C4::Auth_with_shibboleth::get_login_shib>.

=cut

sub get_matchpoint_value {
    my $config = try { _get_shib_config() } catch { undef };
    return '' unless $config;

    my $matchAttribute = $config->{mapping}->{ $config->{matchpoint} }->{is};
    return '' unless $matchAttribute;

    if ( C4::Context->psgi_env ) {
        return $ENV{ 'HTTP_' . uc($matchAttribute) } || '';
    } else {
        return $ENV{$matchAttribute} || '';
    }
}

=head3 authenticate

    my ( $patron, $error_msg ) = $client->authenticate(
        {
            provider  => $provider_obj,
            data      => \%saml_attributes,  # or {} to trigger mode-based loading
            hostname  => $hostname,
            interface => 'opac',             # or 'staff'
        }
    );

Authenticates a SAML2/Shibboleth user against the identity provider database.
Returns C<($patron, undef)> on success, or C<(undef, $error_message)> on
failure.

When C<data> is empty, attributes are loaded from the source appropriate for
the provider's mode (native session or IPC environment variables). Pass the
SAML assertion attributes directly (as returned by L<Koha::Auth::SAML2>
C<process_response>) when calling from the ACS handler.

On success the patron's data is synced if the domain has C<update_on_auth>
enabled (via the base class C<get_user()>). If no patron is found, autocreation
is attempted when permitted by the provider config or domain settings.

=cut

sub authenticate {
    my ( $self, $params ) = @_;

    my $provider  = $params->{provider};
    my $data      = $params->{data} // {};
    my $hostname  = $params->{hostname};
    my $interface = $params->{interface} // 'opac';

    my $logger = Koha::Logger->get;

    # Resolve matchpoint upfront — needed to extract the match_value from
    # mapped_data for autocreate when no patron is found.
    # Use a fresh query (not the provider's prefetched resultset) to avoid
    # cursor-exhaustion issues when $provider was loaded with prefetch.
    # Walk hostname candidates in preference order (full host, bare host, '*')
    # so a wildcard-only hostname entry is still matched when no specific row
    # exists for this hostname.
    my $hostname_link;
    for my $candidate ( Koha::Auth::Identity::Providers->hostname_candidates($hostname) ) {
        $hostname_link = Koha::Auth::Identity::Provider::Hostnames->search(
            {
                'me.identity_provider_id' => $provider->id,
                'hostname.hostname'       => $candidate,
            },
            { join => 'hostname' }
        )->next;
        last if $hostname_link;
    }
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    unless ($matchpoint) {
        $logger->warn("SAML2: matchpoint not defined for hostname '$hostname'");
        return ( undef, 'Matchpoint not configured' );
    }

    # Delegate data mapping, patron lookup, sync, and plugin hooks to the
    # base class get_user().  _get_data_and_patron() handles attribute loading.
    my ( $patron, $mapped_data, $domain );
    eval {
        ( $patron, $mapped_data, $domain ) = $self->get_user(
            {
                provider  => $provider->code,
                data      => $data,
                interface => $interface,
                hostname  => $hostname,
            }
        );
    };

    if ( my $e = $@ ) {
        if ( ref $e && $e->isa('Koha::Exceptions::Auth::NoValidDomain') ) {
            $logger->warn("SAML2: no valid domain config for interface '$interface'");
            return ( undef, 'No valid domain configuration' );
        }
        if ( ref $e && $e->isa('Koha::Exceptions::Auth::DuplicateMatchpoint') ) {
            $logger->warn(
                "SAML2: multiple patrons match " . $e->matchpoint . "='" . $e->value . "', cannot authenticate" );
            return ( undef, 'Multiple patrons match — matchpoint must be unique' );
        }

        # Callers (C4::Auth::checkpw, the ACS controller) treat this method as
        # a yes/no authentication check and do not wrap it in try/catch; an
        # unexpected exception must degrade to a clean auth failure, not a 500
        $logger->error("SAML2: unexpected error during authentication: $e");
        return ( undef, 'Authentication service error' );
    }

    return ( $patron, undef ) if $patron;

    # No patron found — check whether autocreation is permitted
    my $saml2_config     = $provider->get_config // {};
    my $auto_register    = "auto_register_$interface";
    my $allow_autocreate = $saml2_config->{autocreate}
        || ( $domain && $domain->$auto_register );

    unless ($allow_autocreate) {
        $logger->warn("SAML2: patron not found and autocreate is disabled");
        if ( $saml2_config->{debug} && $mapped_data && %$mapped_data ) {
            my $dump =
                join( ', ', map { "$_=" . ( $mapped_data->{$_} // '(undef)' ) } sort keys %$mapped_data );
            $logger->warn("SAML2: mapped data: $dump");
            $logger->warn("SAML2: Hint - visit /cgi-bin/koha/saml2/attributes to see the attribute debug page");
        }
        return ( undef, 'Patron not found' );
    }

    my $match_value = $mapped_data->{$matchpoint};
    unless ( defined $match_value ) {
        $logger->warn("SAML2: matchpoint '$matchpoint' has no value in SAML attributes");
        return ( undef, 'Matchpoint value missing in SAML attributes' );
    }

    my $mapping = $provider->mappings->as_auth_mapping;
    my ( $ok, undef, undef, $new_patron ) = $self->_autocreate(
        {
            config      => $saml2_config,
            matchpoint  => $matchpoint,
            match_value => $match_value,
            mapped_data => $mapped_data,
            mapping     => $mapping,
            domain      => $domain,
        }
    );

    return $ok
        ? ( $new_patron, undef )
        : ( undef, 'Autocreate failed' );
}

=head3 checkpw

    my ( $ok, $cardnumber, $userid, $patron ) =
        $client->checkpw( $match_value, $hostname );

Main authentication entry point called from C<C4::Auth>. Looks up the enabled
SAML2 provider for C<$hostname> and delegates to L</authenticate>.

Attributes are loaded automatically from the source appropriate for the
provider's configured mode (native session or IPC environment variables).

Returns a four-element list on success:

  ( 1, $cardnumber, $userid, $patron )

Returns C<0> on failure.

=cut

sub checkpw {
    my ( $self, $match_value, $hostname ) = @_;

    $hostname //= _request_hostname();

    my $logger = Koha::Logger->get;

    my $provider = Koha::Auth::Identity::Providers->search(
        {
            'me.protocol'          => 'SAML2',
            'me.enabled'           => 1,
            'hostname.hostname'    => $hostname,
            'hostnames.is_enabled' => 1,
        },
        { prefetch => [ 'mappings', { 'hostnames' => 'hostname' } ], rows => 1 }
    )->next;

    unless ($provider) {
        $logger->warn("SAML2: no enabled provider found for hostname '$hostname'");
        return 0;
    }

    my $ctx_interface = C4::Context->interface // 'opac';
    my $interface     = $ctx_interface eq 'intranet' ? 'staff' : 'opac';

    my ( $patron, $error ) = $self->authenticate(
        {
            provider  => $provider,
            data      => {},           # empty triggers mode-based loading in _get_data_and_patron
            hostname  => $hostname,
            interface => $interface,
        }
    );

    return 0 if $error || !$patron;
    return ( 1, $patron->cardnumber, $patron->userid, $patron );
}

=head3 login_url

    my $url = $client->login_url($query);

Returns the SSO login URL for the current interface and query, pointing
to C</cgi-bin/koha/saml2/login>.

=cut

sub login_url {
    my ( $self, $query ) = @_;

    my $target = _get_return($query);
    my $uri    = _get_uri() . '/cgi-bin/koha/saml2/login?target=' . $target;

    return $uri;
}

=head3 logout_url

    my $url = $client->logout_url($query);

Returns the SSO logout URL for the current interface and query, pointing
to C</cgi-bin/koha/saml2/logout>.

=cut

sub logout_url {
    my ( $self, $query ) = @_;

    my $return = _get_return($query);
    my $uri    = _get_uri() . '/cgi-bin/koha/saml2/logout?return=' . $return;

    return $uri;
}

# -------------------------------------------------------------------------
# Overridden base-class method
# -------------------------------------------------------------------------

=head3 _get_data_and_patron

    my ( $mapped_data, $patron ) = $client->_get_data_and_patron(
        {
            provider => $provider,
            data     => \%saml_attributes,   # or {} to trigger mode-based loading
            hostname => $hostname,
        }
    );

Maps SAML attribute names to Koha patron fields using the provider's mapping
configuration and attempts to find the matching patron.

When C<data> is non-empty it is used directly (e.g. when called from the ACS
handler with the fresh assertion). When C<data> is empty, attributes are loaded
explicitly based on the provider's configured mode:

=over 4

=item native mode — read from the CGI session key C<saml2_all_attributes>

=item IPC mode — read from HTTP environment variables set by mod_shib

=back

There is no silent fallback between modes.

=cut

sub _get_data_and_patron {
    my ( $self, $params ) = @_;

    my $provider = $params->{provider};
    my $data     = $params->{data} // {};
    my $hostname = $params->{hostname};

    # Load attributes from the mode-appropriate source when not provided directly
    my $attrs;
    if (%$data) {

        # Caller supplied attributes explicitly (e.g. ACS middleware with fresh assertion)
        $attrs = $data;
    } elsif ( $provider->is_native ) {
        $attrs = _load_native_attributes() // {};
    } else {
        $attrs = _load_ipc_attributes($provider) // {};
    }

    my $mapping = $provider->mappings->as_auth_mapping;

    my $hostname_link = $hostname
        ? Koha::Auth::Identity::Provider::Hostnames->search(
        {
            'me.identity_provider_id' => $provider->id,
            'hostname.hostname'       => $hostname,
        },
        { join => 'hostname' }
        )->next
        : undef;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    my %mapped_data;
    for my $koha_field ( keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is};
        next unless defined $saml_attr;
        my $value = $attrs->{$saml_attr};
        $mapped_data{$koha_field} = $value if defined $value;
    }

    my $patron;
    if ($matchpoint) {
        $patron = $self->_find_patron_by_matchpoint( $matchpoint, $mapped_data{$matchpoint} );
    }

    return ( \%mapped_data, $patron );
}

# -------------------------------------------------------------------------
# Private helpers
# -------------------------------------------------------------------------

=head2 _autocreate

Creates a new patron from the SAML2 assertion data. Applies matchpoint, mapped
attributes, sync-on-creation defaults, and domain defaults. Sends a welcome
email if configured. Returns C<(1, $cardnumber, $userid, $patron)> on success.

=cut

sub _autocreate {
    my ( $self, $args ) = @_;

    my $config      = $args->{config};
    my $matchpoint  = $args->{matchpoint};
    my $match_value = $args->{match_value};
    my $mapped_data = $args->{mapped_data} // {};
    my $mapping     = $args->{mapping};
    my $domain      = $args->{domain};

    my ( %borrower, %patron_attrs );

    # Seed matchpoint field first
    if ( $matchpoint =~ /^patron_attribute:(.+)$/ ) {
        $patron_attrs{$1} = $match_value;
    } else {
        $borrower{$matchpoint} = $match_value;
    }

    # Apply already-mapped Koha fields from the IdP assertion
    for my $koha_field ( keys %$mapped_data ) {
        my $value = $mapped_data->{$koha_field};
        next unless defined $value;
        if ( $koha_field =~ /^patron_attribute:(.+)$/ ) {
            $patron_attrs{$1} //= $value;
        } else {
            $borrower{$koha_field} //= $value;
        }
    }

    # Apply sync_on_creation defaults for fields not present in the assertion
    if ($mapping) {
        for my $koha_field ( keys %$mapping ) {
            next unless $mapping->{$koha_field}{sync_on_creation};
            next if exists $mapped_data->{$koha_field};
            my $value = $mapping->{$koha_field}{content} // '';
            if ( $koha_field =~ /^patron_attribute:(.+)$/ ) {
                $patron_attrs{$1} //= $value;
            } else {
                $borrower{$koha_field} //= $value;
            }
        }
    }

    # Domain defaults (get_user() already sets categorycode/branchcode in
    # mapped_data from the domain, but apply here as a safety net)
    if ($domain) {
        $borrower{categorycode} //= $domain->default_category_id if $domain->default_category_id;
        $borrower{branchcode}   //= $domain->default_library_id  if $domain->default_library_id;
    }

    my $patron = Koha::Patron->new( \%borrower )->store;

    for my $code ( keys %patron_attrs ) {
        Koha::Patron::Attribute->new(
            { borrowernumber => $patron->borrowernumber, code => $code, attribute => $patron_attrs{$code} } )->store;
    }
    $patron->discard_changes;

    C4::Members::Messaging::SetMessagingPreferencesFromDefaults(
        {
            borrowernumber => $patron->borrowernumber,
            categorycode   => $patron->categorycode,
        }
    );

    # Send welcome email if enabled (provider config flag OR domain setting)
    my $send_welcome = $config->{welcome}
        || ( $domain && $domain->send_welcome_email );

    if ($send_welcome) {
        my $emailaddr = $patron->notice_email_address;
        if ($emailaddr) {
            my $letter = C4::Letters::GetPreparedLetter(
                module      => 'members',
                letter_code => 'WELCOME',
                branchcode  => $patron->branchcode,
                lang        => $patron->lang || 'default',
                tables      => {
                    'branches'  => $patron->branchcode,
                    'borrowers' => $patron->borrowernumber,
                },
                want_librarian => 1,
            );
            if ($letter) {
                my $message_id = C4::Letters::EnqueueLetter(
                    {
                        letter                 => $letter,
                        borrowernumber         => $patron->id,
                        to_address             => $emailaddr,
                        message_transport_type => 'email',
                    }
                );
                C4::Letters::SendQueuedMessages( { message_id => $message_id } )
                    if $message_id;
            }
        }
    }

    return ( 1, $patron->cardnumber, $patron->userid, $patron );
}

=head2 _load_native_attributes

Reads SAML2 assertion attributes from the current CGI session (stored there by
L<Koha::App::Controller::SAML2> after assertion validation in native mode).
Returns a hashref of attribute name/value pairs, or undef if unavailable.

=cut

sub _load_native_attributes {

    # Read SAML attributes stored by Koha::Middleware::SAML2 in the CGI session
    my $session_id = _get_session_id_from_env();
    return unless $session_id;

    my $result;
    eval {
        my $session = Koha::Session->get_session( { sessionID => $session_id } );
        if ( $session && $session->id ) {
            my $json = $session->param('saml2_all_attributes');
            $result = decode_json($json) if $json;
        }
    };
    return $result;
}

=head2 _load_ipc_attributes

Reads SAML2/Shibboleth attribute values from HTTP environment variables set by
mod_shib (IPC mode). Returns a hashref of SAML attribute name/value pairs.

=cut

sub _load_ipc_attributes {
    my ($provider) = @_;

    # Read attribute values from HTTP environment variables set by mod_shib
    my $mapping = $provider->mappings->as_auth_mapping;
    my %attrs;
    while ( my ( $koha_field, $entry ) = each %$mapping ) {
        my $attr_name = $entry->{is};
        next unless $attr_name;
        my $value =
            C4::Context->psgi_env
            ? ( $ENV{ 'HTTP_' . uc($attr_name) } // $entry->{content} )
            : ( $ENV{$attr_name} // $entry->{content} );
        $attrs{$attr_name} = $value if defined $value;
    }
    return \%attrs;
}

=head2 _request_hostname

Returns the bare hostname for the current request (no port), preferring
HTTP_HOST over SERVER_NAME to get the actual virtual host name.

=cut

sub _request_hostname {

    # Prefer HTTP_HOST (actual vhost name) over SERVER_NAME (proxy target).
    # Strip any port suffix.
    my $hostname = $ENV{HTTP_HOST} // $ENV{SERVER_NAME} // '';
    $hostname =~ s/:\d+$//;
    return $hostname;
}

=head2 _get_shib_config

Returns a hashref of SAML2/Shibboleth configuration for the current request
hostname, or 0 if no enabled provider is configured. Used by C<is_enabled>.

=cut

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
    my $hostname_link = $provider->hostname_link($hostname);
    my $matchpoint    = $hostname_link ? $hostname_link->matchpoint : undef;

    unless ($matchpoint) {
        carp 'shibboleth matchpoint not defined';
        return 0;
    }

    unless ( defined $mapping->{$matchpoint}->{is} ) {
        carp 'shibboleth matchpoint not mapped';
        return 0;
    }

    my $saml2_config = $provider->get_config // {};
    my $config       = {
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

=head2 _get_session_id_from_env

Extracts the CGISESSID value from the HTTP_COOKIE environment variable.
Returns the session ID string or undef if not present.

=cut

sub _get_session_id_from_env {
    my $cookie_str = $ENV{HTTP_COOKIE} // '';
    if ( $cookie_str =~ /(?:^|;\s*)CGISESSID=([^;]+)/ ) {
        return $1;
    }
    return;
}

=head2 _get_uri

Returns the base HTTPS URI for the current interface (OPACBaseURL or
staffClientBaseURL) with a trailing slash stripped.

=cut

sub _get_uri {
    my $protocol  = 'https://';
    my $interface = C4::Context->interface;

    my $uri =
        $interface eq 'intranet'
        ? C4::Context->preference('staffClientBaseURL')
        : C4::Context->preference('OPACBaseURL');

    $uri or Koha::Logger->get->warn('Syspref staffClientBaseURL or OPACBaseURL not set!');
    $uri ||= '';

    if ( $uri =~ m{^([^:]+)://(.+)$} ) {
        my $oldprotocol = $1;
        if ( $oldprotocol ne 'https' ) {
            Koha::Logger->get->warn('Shibboleth requires OPACBaseURL/staffClientBaseURL to use the https protocol!');
        }
        $uri = $2;
    }

    $uri =~ s{/+$}{};    # strip trailing slash(es) to avoid double-slash in URLs

    return $protocol . $uri;
}

=head2 _get_return

Builds the return URL for SSO login/logout redirects from the current CGI
query parameters.

=cut

sub _get_return {
    my ($query) = @_;

    my $uri_base_part = _get_uri() . ( get_script_name() // '' );

    my $uri_params_part = '';
    for my $param ( sort { ( $a // '' ) cmp( $b // '' ) } $query->url_param() ) {
        my $uriPiece = $query->param($param);
        if ($uriPiece) {
            $uri_params_part .= '%26' if $uri_params_part;
            $uri_params_part .= uri_escape_utf8($param) . '%3D' . uri_escape_utf8($uriPiece);
        }
    }
    $uri_base_part .= '%3F' if $uri_params_part;

    return $uri_base_part . $uri_params_part;
}

1;

=head1 SEE ALSO

L<Koha::Auth::Client>, L<Koha::Auth::SAML2>

=head1 AUTHORS

Koha Development Team

=cut
