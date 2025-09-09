package Koha::ILL::ISO18626::Requests;

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

use Koha::Database;
use Koha::ILL::ISO18626::Request;

use base qw(Koha::Objects);

=head1 NAME

Koha::ILL::Requests - Koha ISO18626 requests Object class

=cut

=head2 Internal methods

=head3 get_request_by_issue_id

    my $iso18626_request = Koha::ILL::ISO18626::Requests->get_request_by_issue_id( $c->{issue_id} );

Returns the request provided an issue_id.

=cut

sub get_request_by_issue_id {
    my ( $self, $issue_id ) = @_;

    return $self->find( { 'issue_id' => $issue_id } );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Iso18626Request';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ILL::ISO18626::Request';
}

1;
