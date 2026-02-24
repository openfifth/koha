package Koha::Auth::Client::OAuth;

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

use JSON         qw( decode_json );
use MIME::Base64 qw{ decode_base64url };
use Koha::Patrons;
use Mojo::UserAgent;
use Mojo::Parameters;

use base qw( Koha::Auth::Client );

=head1 NAME

Koha::Auth::Client::OAuth - Koha OAuth Client

=head1 API

=head2 Class methods

=head3 _get_data_and_patron

    my $mapping = $object->_get_data_and_patron(
        {   provider => $provider,
            data     => $data,
            config   => $config
        }
    );

Maps OAuth raw data to a patron schema, and returns a patron if it can.

=cut

sub _get_data_and_patron {
    my ( $self, $params ) = @_;

    my $provider = $params->{provider};
    my $data     = $params->{data};
    my $config   = $params->{config};
    my $hostname = $params->{hostname};

    my $patron;
    my $mapped_data;

    my $mapping       = $provider->mappings->as_auth_mapping;
    my $hostname_link = $hostname
        ? $provider->hostnames->search(
        { 'hostname.hostname' => $hostname },
        { join                => 'hostname' }
        )->next
        : undef;
    my $matchpoint = $hostname_link ? $hostname_link->matchpoint : undef;

    if ( $data->{id_token} ) {
        my ( $header_part, $claims_part, $footer_part ) = split( /\./, $data->{id_token} );

        my $claim = decode_json( decode_base64url($claims_part) );

        foreach my $koha_field ( keys %$mapping ) {
            my $pkey  = $mapping->{$koha_field}{is};
            my $value = defined $pkey ? $claim->{$pkey} : undef;

            # Note: We don't apply default here yet, because we need to know if it's a create or update.
            # But we should at least store what we got.
            $mapped_data->{$koha_field} = $value
                if defined $value;
        }

        $patron = $self->_find_patron_by_matchpoint( $matchpoint, $mapped_data->{$matchpoint} );
    }

    if ( defined $config->{userinfo_url} ) {
        my $access_token = $data->{access_token};
        my $ua           = Mojo::UserAgent->new;
        my $tx           = $ua->get( $config->{userinfo_url} => { Authorization => "Bearer $access_token" } );
        my $code         = $tx->res->code || 'No response';

        return if $code ne '200';
        my $claim =
              $tx->res->headers->content_type =~ m!^(application/json|text/javascript)(;\s*charset=\S+)?$!
            ? $tx->res->json
            : Mojo::Parameters->new( $tx->res->body )->to_hash;

        foreach my $koha_field ( keys %$mapping ) {
            my $pkey  = $mapping->{$koha_field}{is};
            my $value = defined $pkey ? $self->_traverse_hash( { base => $claim, keys => $pkey } ) : undef;
            $mapped_data->{$koha_field} = $value
                if defined $value;
        }

        unless ($patron) {
            $patron = $self->_find_patron_by_matchpoint( $matchpoint, $mapped_data->{$matchpoint} );
        }

    }

    return ( $mapped_data, $patron );
}

=head3 _find_patron_by_matchpoint

    my $patron = $client->_find_patron_by_matchpoint( $matchpoint, $value );

Internal method to find a patron by the given matchpoint and value.
Returns the patron object if found, undef otherwise.

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

1;
