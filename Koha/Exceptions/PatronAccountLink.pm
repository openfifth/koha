package Koha::Exceptions::PatronAccountLink;

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
    'Koha::Exceptions::PatronAccountLink' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::PatronAccountLink::AlreadyLinked' => {
        isa         => 'Koha::Exceptions::PatronAccountLink',
        description => "Patrons are already linked together",
    },
    'Koha::Exceptions::PatronAccountLink::DifferentGroups' => {
        isa         => 'Koha::Exceptions::PatronAccountLink',
        description => "Both patrons already belong to different link groups",
    },
);

=head1 NAME

Koha::Exceptions::PatronAccountLink - Base class for PatronAccountLink exceptions

=head1 Exceptions

=head2 Koha::Exceptions::PatronAccountLink

Generic PatronAccountLink exception

=head2 Koha::Exceptions::PatronAccountLink::AlreadyLinked

Exception to be used when patrons are already linked together.

=head2 Koha::Exceptions::PatronAccountLink::DifferentGroups

Exception to be used when both patrons already belong to different link groups.

=cut

1;
