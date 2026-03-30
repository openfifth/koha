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
use URI;
use URI::Escape qw( uri_escape_utf8 );

use C4::Context;
use C4::Letters qw( GetPreparedLetter EnqueueLetter SendQueuedMessages );
use C4::Members::Messaging;

use Koha::Auth::Identity::Providers;
use Koha::AuthUtils qw( get_script_name );
use Koha::Logger;
use Koha::Patron;
use Koha::Patron::Attribute;
use Koha::Patron::Attributes;
use Koha::Patrons;

=head1 NAME

Koha::Auth::Client::SAML2 - Koha SAML2/Shibboleth auth client

=head1 SYNOPSIS

  use Koha::Auth::Client::SAML2;

  my $client = Koha::Auth::Client::SAML2->new;
  my ( $ok, $cardnumber, $userid, $patron ) =
      $client->checkpw( $match_value, \%saml_attributes, $hostname );

=head1 DESCRIPTION

This module bridges the Shibboleth/SAML2 authentication path (both native and
IPC modes) with Koha's identity provider framework. It handles patron lookup
by matchpoint, autocreation of new patrons, data synchronisation, and welcome
emails, delegating to the identity provider's DB configuration.

=head1 API

=head2 Class methods

=head3 _get_data_and_patron

    my ( $mapped_data, $patron ) = $client->_get_data_and_patron(
        {
            provider => $provider,
            data     => \%saml_attributes,
            hostname => $hostname,
        }
    );

Maps SAML attribute names to Koha patron fields using the provider's mapping
configuration, and attempts to find the matching patron using the hostname's
configured matchpoint.

=cut

sub _get_data_and_patron {
    my ( $self, $params ) = @_;

    my $provider = $params->{provider};
    my $data     = $params->{data} // {};
    my $hostname = $params->{hostname};

    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $hostname
        ? $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
        )->next
        : undef;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    my %mapped_data;
    for my $koha_field ( keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is};
        next unless defined $saml_attr;
        my $value = $data->{$saml_attr};
        $mapped_data{$koha_field} = $value if defined $value;
    }

    my $patron;
    if ($matchpoint) {
        $patron = $self->_find_patron_by_matchpoint( $matchpoint, $mapped_data{$matchpoint} );
    }

    return ( \%mapped_data, $patron );
}

=head3 _find_patron_by_matchpoint

    my $patron = $client->_find_patron_by_matchpoint( $matchpoint, $value );

Finds a patron by the given matchpoint field and value. Supports
C<patron_attribute:CODE> syntax for extended patron attributes.

Returns the patron object if exactly one is found, undef otherwise.

=cut

sub _find_patron_by_matchpoint {
    my ( $self, $matchpoint, $value ) = @_;

    return unless defined $value;

    my $patron_rs;
    if ( $matchpoint =~ /^patron_attribute:(.+)$/ ) {
        my $code = $1;
        $patron_rs = Koha::Patrons->search(
            { 'borrower_attributes.code' => $code, 'borrower_attributes.attribute' => $value },
            { join                       => 'borrower_attributes' }
        );
    } else {
        $patron_rs = Koha::Patrons->search( { $matchpoint => $value } );
    }

    return $patron_rs->count ? $patron_rs->next : undef;
}

=head3 checkpw

    my ( $ok, $cardnumber, $userid, $patron ) =
        $client->checkpw( $match_value, \%saml_attributes, $hostname );

Main authentication entry point. Looks up the enabled SAML2 provider for
C<$hostname>, maps SAML attributes to Koha patron fields, and tries to find a
matching patron.

If no patron is found and autocreation is permitted (either by the provider's
C<autocreate> config flag or the domain's C<auto_register_opac> /
C<auto_register_staff> setting), a new patron is created.

Returns a four-element list on success:

  ( 1, $cardnumber, $userid, $patron )

Returns C<0> on failure.

C<$saml_attributes> may be C<undef> or an empty hashref for IPC mode, where
the matchpoint value comes from the Shibboleth environment variable rather than
from the SAML assertion.

=cut

sub checkpw {
    my ( $self, $match_value, $saml_attributes, $hostname ) = @_;

    $hostname        //= $ENV{SERVER_NAME} // '';
    $saml_attributes //= {};

    my $logger = Koha::Logger->get;

    # Find the enabled SAML2 provider for this hostname
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

    my $saml2_config  = $provider->get_config // {};
    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
    )->next;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    unless ($matchpoint) {
        carp 'SAML2: matchpoint not defined for hostname';
        return 0;
    }

    unless ( defined $mapping->{$matchpoint}->{is} || $matchpoint =~ /^patron_attribute:/ ) {
        carp "SAML2: matchpoint '$matchpoint' is not mapped";
        return 0;
    }

    # Find patron by matchpoint
    my $patron_rs;
    if ( $matchpoint =~ /^patron_attribute:(.+)$/ ) {
        my $code = $1;
        $patron_rs = Koha::Patrons->search(
            { 'borrower_attributes.code' => $code, 'borrower_attributes.attribute' => $match_value },
            { join                       => 'borrower_attributes' }
        );
    } else {
        $patron_rs = Koha::Patrons->search( { $matchpoint => $match_value } );
    }

    if ( $patron_rs->count > 1 ) {
        $logger->warn("There are several users with $matchpoint of $match_value, matchpoints must be unique");
        return 0;
    }

    my $patron = $patron_rs->next;

    # Map C4::Context interface ('intranet' -> 'staff', 'opac' -> 'opac') so it
    # matches the allow_opac / allow_staff columns on the domain record.
    my $ctx_interface = C4::Context->interface // 'opac';
    my $interface     = $ctx_interface eq 'intranet' ? 'staff' : 'opac';

    # Resolve domain config (needed for both sync and autocreate)
    my $domain = eval {
        $self->get_valid_domain_config(
            { provider => $provider, email => $saml_attributes->{mail} // '', interface => $interface } );
    };

    if ($patron) {

        # Sync patron data if the domain has "Update on login" enabled
        if ( $domain && $domain->update_on_auth ) {
            $self->_sync_patron( $patron, $mapping, $saml_attributes );
        }
        return ( 1, $patron->cardnumber, $patron->userid, $patron );
    }

    # Patron not found - check if we should autocreate
    my $auto_register = $interface eq 'staff' ? 'auto_register_staff' : 'auto_register_opac';

    my $allow_autocreate = $saml2_config->{autocreate}
        || ( $domain && $domain->$auto_register );

    if ($allow_autocreate) {
        return $self->_autocreate(
            {
                config          => $saml2_config,
                matchpoint      => $matchpoint,
                match_value     => $match_value,
                mapping         => $mapping,
                saml_attributes => $saml_attributes,
                domain          => $domain,
            }
        );
    }

    $logger->warn("SAML2: No patron found with $matchpoint='$match_value' and autocreate is disabled");
    if ( $saml2_config->{debug} && %$saml_attributes ) {
        my $attr_dump =
            join( ', ', map { "$_=" . ( $saml_attributes->{$_} // '(undef)' ) } sort keys %$saml_attributes );
        $logger->warn("SAML2: Received attributes: $attr_dump");
        $logger->warn("SAML2: Hint - visit /cgi-bin/koha/saml2/attributes to see the attribute debug page");
    }
    return 0;
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
# Private helpers
# -------------------------------------------------------------------------

sub _autocreate {
    my ( $self, $args ) = @_;

    my $config          = $args->{config};
    my $matchpoint      = $args->{matchpoint};
    my $match_value     = $args->{match_value};
    my $mapping         = $args->{mapping};
    my $saml_attributes = $args->{saml_attributes} // {};
    my $domain          = $args->{domain};

    my ( %borrower, %patron_attrs );

    # Set matchpoint value
    if ( $matchpoint =~ /^patron_attribute:(.+)$/ ) {
        $patron_attrs{$1} = $match_value;
    } else {
        $borrower{$matchpoint} = $match_value;
    }

    # Map SAML attributes to Koha fields.
    # When sync_on_creation is set, always apply. Otherwise apply only when a
    # value is actually present in saml_attributes (IPC mode compat: caller
    # populates saml_attributes from env vars for all mapped fields).
    for my $koha_field ( keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is};
        my $value;
        if ( $saml_attr && defined $saml_attributes->{$saml_attr} ) {
            $value = $saml_attributes->{$saml_attr};
        } elsif ( $mapping->{$koha_field}{sync_on_creation} ) {
            $value = $mapping->{$koha_field}{content} // '';
        } else {
            next;
        }
        if ( $koha_field =~ /^patron_attribute:(.+)$/ ) {
            $patron_attrs{$1} = $value;
        } else {
            $borrower{$koha_field} = $value;
        }
    }

    # Apply domain defaults if available
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

sub _sync_patron {
    my ( $self, $patron, $mapping, $saml_attributes ) = @_;

    my ( %borrower, %patron_attrs );
    $borrower{borrowernumber} = $patron->borrowernumber;

    for my $koha_field ( keys %$mapping ) {
        my $saml_attr = $mapping->{$koha_field}{is};
        next unless $saml_attr && defined $saml_attributes->{$saml_attr};
        next unless $mapping->{$koha_field}{sync_on_update};
        my $value = $saml_attributes->{$saml_attr};
        if ( $koha_field =~ /^patron_attribute:(.+)$/ ) {
            $patron_attrs{$1} = $value;
        } else {
            $borrower{$koha_field} = $value;
        }
    }

    $patron->set( \%borrower )->store if keys %borrower > 1;    # >1 because borrowernumber is always there

    for my $code ( keys %patron_attrs ) {
        my $existing = Koha::Patron::Attributes->search( { borrowernumber => $patron->borrowernumber, code => $code } );
        $existing->delete;
        Koha::Patron::Attribute->new(
            { borrowernumber => $patron->borrowernumber, code => $code, attribute => $patron_attrs{$code} } )->store;
    }

    return;
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

sub _get_return {
    my ($query) = @_;

    my $uri_base_part = _get_uri() . get_script_name();

    my $uri_params_part = '';
    for my $param ( sort $query->url_param() ) {
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

=head1 SEE ALSO

L<Koha::Auth::Client>, L<C4::Auth_with_shibboleth>, L<Koha::Auth::SAML2>

=head1 AUTHORS

Koha Development Team

=cut
