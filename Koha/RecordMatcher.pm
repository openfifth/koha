package Koha::RecordMatcher;

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

Koha::RecordMatcher - Koha RecordMatcher Object class

=head1 API

=head2 Class Methods

=head3 to_api_mapping

This method returns the mapping for representing a Koha::RecordMatcher object
on the API.

=cut

sub to_api_mapping {
    return { matcher_id => 'record_matcher_id' };
}

=head3 _type

=cut

sub _type {
    return 'MarcMatcher';
}

1;
