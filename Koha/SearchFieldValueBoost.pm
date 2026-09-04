package Koha::SearchFieldValueBoost;

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

use Koha::Database;
use Koha::SearchField;

use base qw(Koha::Object);

=head1 NAME

Koha::SearchFieldValueBoost - Koha SearchFieldValueBoost Object class

=head1 API

=head2 Class Methods

=cut

=head3 search_field

Returns the associated Koha::SearchField for this value boost.

=cut

sub search_field {
    my ($self) = @_;
    my $search_field_rs = $self->_result->search_field;
    return Koha::SearchField->_new_from_dbic($search_field_rs);
}

=head3 _type

=cut

sub _type {
    return 'SearchFieldValueBoost';
}

1;
