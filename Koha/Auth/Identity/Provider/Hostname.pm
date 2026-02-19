package Koha::Auth::Identity::Provider::Hostname;

# Copyright Koha Community 2026
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

Koha::Auth::Identity::Provider::Hostname - Koha Auth Provider Hostname Object class

=head1 API

=head2 Class methods

=head3 to_api

Overrides the default serialization to embed the hostname string from the
related Hostname record alongside the hostname_id FK.

=cut

sub to_api {
    my ( $self, $params ) = @_;
    my $data = $self->SUPER::to_api($params);
    $data->{hostname} = $self->_result->hostname->hostname;
    return $data;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'IdentityProviderHostname';
}

1;
