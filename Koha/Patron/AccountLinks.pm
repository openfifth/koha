package Koha::Patron::AccountLinks;

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

use Koha::Patron::AccountLink;

use base qw(Koha::Objects);

=head1 NAME

Koha::Patron::AccountLinks - Koha Patron Account Link Object set class

=head1 API

=head2 Class Methods

=head3 get_next_group_id

Returns the next available link_group_id for creating new link groups

=cut

sub get_next_group_id {
    my ($class) = @_;
    my $max = $class->_resultset->get_column('link_group_id')->max || 0;
    return $max + 1;
}

=head3 _type

=cut

sub _type {
    return 'PatronAccountLink';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Patron::AccountLink';
}

1;
