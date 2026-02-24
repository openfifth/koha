package Koha::Auth::Identity::Provider::Domain;

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

use base qw(Koha::Object);

=head1 NAME

Koha::Auth::Identity::Provider::Domain - Koha Auth Provider Domain Object class

=head1 API

=head2 Class methods

=head3 identity_provider

    my $provider = $domain->identity_provider;

Returns the related I<Koha::Auth::Identity::Provider> object.

=cut

sub identity_provider {
    my ($self) = @_;

    require Koha::Auth::Identity::Provider;
    my $provider_rs = $self->_result->identity_provider;
    return Koha::Auth::Identity::Provider->_new_from_dbic($provider_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'IdentityProviderDomain';
}

1;
