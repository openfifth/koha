package Koha::ILL::ISO18626::RequestingAgency;

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

Koha::ILL::ISO18626::RequestingAgency - Koha ILL ISO18626 Requesting Agency Object class

=cut

=head2 Internal methods

=head3 to_api_mapping

This method returns the mapping for representing a Koha::ILL::ISO18626::RequestingAgency
object on the API.

=cut

sub to_api_mapping {
    return {
        borrowernumber => 'patron_id',
    };
}

=head3 ill_partner

Return the ill_partner patron for this requesting agency

=cut

sub ill_partner {
    my ($self) = @_;
    my $patrons_rs = $self->_result->patron;
    return unless $patrons_rs;
    return Koha::Patron->_new_from_dbic($patrons_rs);
}

=head3 _type

=cut

sub _type {
    return 'Iso18626RequestingAgency';
}

1;
