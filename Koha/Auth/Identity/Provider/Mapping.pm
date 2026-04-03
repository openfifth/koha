package Koha::Auth::Identity::Provider::Mapping;

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

use Koha::Exceptions;
use Koha::Auth::Identity::Provider::Mappings;

=head1 NAME

Koha::Auth::Identity::Provider::Mapping - Koha Identity Provider field mapping object

=head1 API

=head2 Class methods

=head3 store

Override store to validate that at least one of C<provider_field> or
C<default_content> is supplied.

=cut

sub store {
    my ($self) = @_;

    unless ( defined $self->provider_field || defined $self->default_content ) {
        Koha::Exceptions::MissingParameter->throw( parameter => 'provider_field or default_content' );
    }

    return $self->SUPER::store();
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'IdentityProviderMapping';
}

1;
