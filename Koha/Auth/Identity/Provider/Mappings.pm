package Koha::Auth::Identity::Provider::Mappings;

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

use base qw(Koha::Objects);

use Koha::Auth::Identity::Provider::Mapping;

=head1 NAME

Koha::Auth::Identity::Provider::Mappings - Koha Identity Provider field mappings collection

=head1 API

=head2 Class methods

=head3 as_auth_mapping

    my $mapping_hashref = $mappings->as_auth_mapping;

Returns a hashref suitable for use by the authentication layer:
C<{ koha_field => { is => provider_field, content => default_content }, ... }>.
The matchpoint is stored on the provider itself (C<identity_providers.matchpoint>).

=cut

sub as_auth_mapping {
    my ($self) = @_;

    my %mapping;

    while ( my $m = $self->next ) {
        $mapping{ $m->koha_field } = {
            is               => $m->provider_field,
            content          => $m->default_content,
            sync_on_creation => $m->sync_on_creation,
            sync_on_update   => $m->sync_on_update,
        };
    }

    return \%mapping;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'IdentityProviderMapping';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Auth::Identity::Provider::Mapping';
}

1;
