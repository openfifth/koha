package Koha::Auth::Client;

# Copyright Theke Solutions 2022
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

use C4::Context;

use Koha::Exceptions;
use Koha::Exceptions::Auth;
use Koha::Auth::Identity::Providers;
use Koha::Logger;
use Koha::Patron::Attribute;
use Koha::Patron::Attribute::Types;
use Koha::Patron::Attributes;

=head1 NAME

Koha::Auth::Client - Base Koha auth client

=head1 API

=head2 Methods

=head3 new

    my $auth_client = Koha::Auth::Client->new();

=cut

sub new {
    my ($class) = @_;
    my $self = {};

    bless( $self, $class );
}

=head3 for_protocol

    my $client = Koha::Auth::Client->for_protocol( $provider->protocol );

Factory method returning an instance of the I<Koha::Auth::Client> subclass that
implements the given protocol, so callers dispatch on the C<protocol> column
without hard-coding class names. Throws
I<Koha::Exceptions::Auth::UnsupportedProtocol> for unknown protocols.

=cut

sub for_protocol {
    my ( $class, $protocol ) = @_;

    Koha::Exceptions::MissingParameter->throw( parameter => 'protocol' )
        unless $protocol;

    my $map = {
        OAuth => 'Koha::Auth::Client::OAuth',
        OIDC  => 'Koha::Auth::Client::OAuth',
        SAML2 => 'Koha::Auth::Client::SAML2',
    };

    my $subclass = $map->{$protocol}
        or Koha::Exceptions::Auth::UnsupportedProtocol->throw( protocol => $protocol );

    eval "require $subclass";
    return $subclass->new;
}

=head3 get_user

    $auth_client->get_user($provider, $data)

Get user data according to provider's mapping configuration

=cut

sub get_user {
    my ( $self, $params ) = @_;
    my $provider_code = $params->{provider};
    my $data          = $params->{data};
    my $interface     = $params->{interface};
    my $config        = $params->{config};
    my $hostname      = $params->{hostname};

    my $provider = Koha::Auth::Identity::Providers->search( { code => $provider_code } )->next;

    my ( $mapped_data, $patron ) =
        $self->_get_data_and_patron(
        { provider => $provider, data => $data, config => $config, hostname => $hostname } );

    $mapped_data //= {};

    my $domain = $self->has_valid_domain_config(
        { provider => $provider, email => $mapped_data->{email}, interface => $interface } );

    my $args = {
        provider    => $provider,
        data        => $data,
        config      => $config,
        mapped_data => $mapped_data,
        patron      => $patron,
        domain      => $domain,
    };

    # Call the plugin hook "auth_client_get_user" of all plugins.
    Koha::Plugins->call( 'auth_client_get_user', $args );
    $mapped_data = $args->{'mapped_data'};
    $patron      = $args->{'patron'};
    $domain      = $args->{'domain'};

    if ( $patron && $domain->update_on_auth ) {
        $self->_update_patron_from_mapped_data( { patron => $patron, mapped_data => $mapped_data } );
    }

    $mapped_data->{categorycode} = $domain->default_category_id;
    $mapped_data->{branchcode}   = $domain->default_library_id;

    return ( $patron, $mapped_data, $domain );
}

=head3 get_valid_domain_config

    my $domain = Koha::Auth::Client->get_valid_domain_config(
        {   provider  => $provider,
            email     => $user_email,
            interface => $interface
        }
    );

Gets the best suited valid domain configuration for the given provider.

=cut

sub get_valid_domain_config {

    # FIXME: Should be a hashref param
    my ( $self, $params ) = @_;
    my $provider   = $params->{provider};
    my $user_email = $params->{email};
    my $interface  = $params->{interface};

    my $domains = $provider->domains;
    my $allow   = "allow_$interface";
    my @subdomain_matches;
    my $perfect_match;
    my $response;

    while ( my $domain = $domains->next ) {

        my $pattern     = '@';
        my $domain_text = $domain->domain;
        unless ( defined $domain_text && $domain_text ne '' ) {
            $response = $domain;
            next;
        }
        my ( $asterisk, $domain_name ) = ( $domain_text =~ /^(\*)?(.+)$/ );
        if ( defined $asterisk && $asterisk eq '*' ) {
            $pattern .= '.*';
        }
        $domain_name = quotemeta($domain_name);
        $pattern .= $domain_name . '$';
        if ( $user_email =~ /$pattern/ ) {
            if ( defined $asterisk && $asterisk eq '*' ) {
                push @subdomain_matches, { domain => $domain, match_length => length $domain_name };
            } else {
                $perfect_match = $domain;
            }
        }
    }

    if ( !$perfect_match && @subdomain_matches ) {
        @subdomain_matches = sort { $b->{match_length} <=> $a->{match_length} } @subdomain_matches
            unless scalar @subdomain_matches == 1;
        $response = $subdomain_matches[0]->{domain};
    } elsif ($perfect_match) {
        $response = $perfect_match;
    }

    return unless $response && $response->$allow;

    return $response;
}

=head3 has_valid_domain_config

    my $has_valid_domain = Koha::Auth::Client->has_valid_domain_config(
        {   provider  => $provider,
            email     => $user_email,
            interface => $interface
        }
    );

Checks if provider has a valid domain for user email. If has, returns that domain.

=cut

sub has_valid_domain_config {

    # FIXME: Should be a hashref param
    my ( $self, $params ) = @_;
    my $domain = $self->get_valid_domain_config($params);

    Koha::Exceptions::Auth::NoValidDomain->throw( code => 401 )
        unless $domain;

    return $domain;
}

=head3 _get_data_and_patron

    my $mapping = $auth_client->_get_data_and_patron(
        {   provider => $provider,
            data     => $data,
            config   => $config
        }
    );

Generic method that maps raw data to patron schema, and returns a patron if it can.

Note: this only returns an empty I<hashref>. Each class should have its
own mapping returned.

=cut

sub _get_data_and_patron {
    return {};
}

=head3 _update_patron_from_mapped_data

    $self->_update_patron_from_mapped_data( { patron => $patron, mapped_data => $mapped_data } );

Updates the patron from the mapped data, including core borrower fields
and extended patron attributes.

=cut

sub _update_patron_from_mapped_data {
    my ( $self, $params ) = @_;
    my $patron      = $params->{patron};
    my $mapped_data = $params->{mapped_data};

    my $logger = Koha::Logger->get;

    my ( %patron_attrs, %borrower_data );
    for my $key ( keys %$mapped_data ) {
        my $value = $mapped_data->{$key};
        if ( ref $value eq 'ARRAY' && $key !~ /^patron_attribute:/ ) {

            # Core borrower fields are single-value DB columns; a mapping that
            # resolves to multiple values here is a configuration error, not
            # something we can store. Fall back to the first value rather than
            # storing a stringified reference or dying mid-login.
            $logger->warn("SAML2/OAuth mapping: multiple values supplied for core field '$key'; using the first one");
            $value = $value->[0];
        }
        if ( $key =~ /^patron_attribute:(.+)$/ ) {
            $patron_attrs{$1} = $value;
        } else {
            $borrower_data{$key} = $value;
        }
    }
    $patron->set( \%borrower_data )->store;

    for my $code ( keys %patron_attrs ) {
        my $value = $patron_attrs{$code};

        # Dedupe while preserving order, in case the IdP sends the same value twice.
        my ( %seen, @values );
        @values = grep { !$seen{$_}++ } ref $value eq 'ARRAY' ? @$value : ($value);

        my $type = Koha::Patron::Attribute::Types->find($code);
        if ( @values > 1 && !( $type && $type->repeatable ) ) {
            $logger->warn(
                "SAML2/OAuth mapping: multiple values supplied for non-repeatable attribute '$code'; using the first one"
            );
            @values = ( $values[0] );
        }

        # The IdP is authoritative for whatever it maps to this code: replace
        # the whole set every sync (not just add to it), so a value that
        # changed or disappeared at the IdP is reflected here too.
        Koha::Patron::Attributes->search( { borrowernumber => $patron->borrowernumber, code => $code } )->delete;
        for my $v (@values) {
            Koha::Patron::Attribute->new( { borrowernumber => $patron->borrowernumber, code => $code, attribute => $v } )
                ->store;
        }
    }
}

=head3 _find_patron_by_matchpoint

    my $patron = $client->_find_patron_by_matchpoint( $matchpoint, $value );

Internal method to find a patron by the given matchpoint and value.
Returns the patron object if found, undef otherwise.

=cut

sub _find_patron_by_matchpoint {
    my ( $self, $matchpoint, $value ) = @_;

    return unless defined $value && $value ne '';

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

    if ( $patron_rs->count > 1 ) {
        Koha::Exceptions::Auth::DuplicateMatchpoint->throw(
            matchpoint => $matchpoint,
            value      => $value
        );
    }

    return $patron_rs->count ? $patron_rs->next : undef;
}

=head3 _get_mapped_data

    my $mapped_data = $self->_get_mapped_data( { provider => $provider, raw_data => $raw_data } );

Internal method to map raw IdP data to Koha borrower fields using the
configured provider mappings.

=cut

sub _get_mapped_data {
    my ( $self, $params ) = @_;
    my $provider = $params->{provider};
    my $raw_data = $params->{raw_data};

    my $mapped_data;
    my $mappings = $provider->mappings;

    while ( my $mapping = $mappings->next ) {
        my $koha_field     = $mapping->koha_field;
        my $provider_field = $mapping->provider_field;

        my $value = $self->_traverse_hash( { base => $raw_data, keys => $provider_field } );
        $value //= $mapping->default_content;

        $mapped_data->{$koha_field} = $value if defined $value;
    }

    return $mapped_data;
}

=head3 _traverse_hash

    my $value = $auth_client->_traverse_hash( { base => $base_hash, keys => $key_string } );

Get deep nested value in a hash.

=cut

sub _traverse_hash {
    my ( $self, $params ) = @_;
    my $base = $params->{base};
    my $keys = $params->{keys};
    my ( $key, $rest ) = ( $keys =~ /^([^.]+)(?:\.(.*))?/ );
    return unless defined $key;
    my $value = ref $base eq 'HASH' ? $base->{$key} : $base->[$key];
    return $value unless $rest;
    return $self->_traverse_hash( { base => $value, keys => $rest } );
}

1;
