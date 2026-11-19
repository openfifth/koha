package Koha::ILL::ISO18626::SupplyingAgency;

# Copyright Open Fifth 2026
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

Koha::ILL::ISO18626::SupplyingAgency - Koha ILL ISO18626 Supplying Agency Object class

=cut

=head1 API

=head2 Class methods

=head3 iso18626_agency_id

    my $agency_id = $supplying_agency->iso18626_agency_id;

Returns the agency ID of this supplying agency as an ISO 18626 C<agencyId>.

=cut

sub iso18626_agency_id {
    my ($self) = @_;

    return {
        agencyIdType  => $self->type,
        agencyIdValue => $self->agency_id,
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Iso18626SupplyingAgency';
}

1;
