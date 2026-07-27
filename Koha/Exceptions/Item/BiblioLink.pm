package Koha::Exceptions::Item::BiblioLink;

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

use Koha::Exception;

use Exception::Class (
    'Koha::Exceptions::Item::BiblioLink' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::Item::BiblioLink::SameBiblio' => {
        isa         => 'Koha::Exceptions::Item::BiblioLink',
        description => "An item cannot be linked to the bibliographic record its item record lives on",
    },
    'Koha::Exceptions::Item::BiblioLink::HoldsExist' => {
        isa         => 'Koha::Exceptions::Item::BiblioLink',
        description => "The link cannot be removed because holds exist for the item on the linked bibliographic record",
    },
);

=head1 NAME

Koha::Exceptions::Item::BiblioLink - Base class for item/biblio link exceptions

=head1 Exceptions

=head2 Koha::Exceptions::Item::BiblioLink

Generic Item::BiblioLink exception

=head2 Koha::Exceptions::Item::BiblioLink::SameBiblio

Exception to be used when attempting to link an item to the bibliographic
record its item record already links to.

=head2 Koha::Exceptions::Item::BiblioLink::HoldsExist

Exception to be used when attempting to remove a link while holds exist for
the item on the linked bibliographic record. Removing the link would strand
those holds. Pass force => 1 to the delete to override.

=cut

1;
