package Koha::Auth::Identity::Providers;

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

use Koha::Auth::Identity::Provider;
use Koha::Auth::Identity::Provider::Hostnames;
use Koha::Auth::Identity::Provider::OAuth;
use Koha::Auth::Identity::Provider::OIDC;
use Koha::Auth::Identity::Provider::SAML2;

use base qw(Koha::Objects);

=head1 NAME

Koha::Auth::Identity::Providers - Koha Auth Provider Object class

=head1 API

=head2 Class methods

=head3 find_forced_provider

    my $provider = Koha::Auth::Identity::Providers->find_forced_provider($hostname);

Returns the I<Koha::Auth::Identity::Provider> object if the given I<hostname> is configured to
force SSO, or C<undef> if no forced provider is found.

=cut

sub find_forced_provider {
    my ( $self, $hostname ) = @_;
    return unless $hostname;

    my $hostname_link = Koha::Auth::Identity::Provider::Hostnames->search(
        {
            'hostname.hostname'         => $hostname,
            'identity_provider.enabled' => 1,
            'me.is_enabled'             => 1,
            'me.force_sso'              => 1,
        },
        { join => [ 'hostname', 'identity_provider' ] }
    )->next;

    return unless $hostname_link;

    my $ip_result = $hostname_link->_result->identity_provider;
    return $self->object_class($ip_result)->_new_from_dbic($ip_result);
}

=head2 Internal methods

=cut

=head3 _type

=cut

sub _type {
    return 'IdentityProvider';
}

=head3 _polymorphic_field

Return the field in the table that defines the polymorphic class to be built

=cut

sub _polymorphic_field {
    return 'protocol';
}

=head3 _polymorphic_map

Return the mapping from protocol value to implementing class name

=cut

sub _polymorphic_map {
    return {
        OAuth => 'Koha::Auth::Identity::Provider::OAuth',
        OIDC  => 'Koha::Auth::Identity::Provider::OIDC',
        SAML2 => 'Koha::Auth::Identity::Provider::SAML2',
    };
}

=head3 object_class

Return object class dynamically based on protocol

=cut

sub object_class {
    my ( $self, $object ) = @_;

    return 'Koha::Auth::Identity::Provider' unless $object;

    my $field = $self->_polymorphic_field;
    my $map   = $self->_polymorphic_map;

    return $map->{ $object->$field } || 'Koha::Auth::Identity::Provider';
}

1;

