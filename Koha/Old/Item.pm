package Koha::Old::Item;

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
use Koha::Biblios;
use Koha::Old::Biblios;

=head1 NAME

Koha::Old::Item - Koha Old Item Object class

=head1 API

=head2 Class Methods

=cut

=head3 _type

=cut

sub _type {
    return 'Deleteditem';
}

=head3 biblio

    my $biblio = $item->biblio;

Returns the related biblio object for this item. Checks both the regular biblio table
and the deletedbiblio table, returning whichever one contains the record.

=cut

sub biblio {
    my ($self) = @_;
    my $biblionumber = $self->_result->biblionumber;
    return unless $biblionumber;

    # First check if the biblio exists in the regular biblio table
    my $biblio = Koha::Biblios->find($biblionumber);
    return $biblio if $biblio;

    # If not found in regular biblio table, check deletedbiblio
    return Koha::Old::Biblios->find($biblionumber);
}

1;
