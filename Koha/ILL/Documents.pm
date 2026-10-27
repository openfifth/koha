package Koha::ILL::Documents;

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
use Koha::Exceptions;
use Koha::ILL::Document;

use base qw(Koha::Objects);

=head1 NAME

Koha::ILL::Documents - Koha ILL documents Object class

=cut

=head2 Class methods

=head3 filter_by_purgeable_supplied

    my $purgeable = Koha::ILL::Documents->filter_by_purgeable_supplied( { days => 30 } );

Returns a I<Koha::ILL::Documents> resultset filtered to documents of
CopyCompleted requests whose receipt was confirmed more than the specified number of
days ago.

The caller can then use C<< ->count >> for reporting or C<< ->delete >> to purge.

=cut

sub filter_by_purgeable_supplied {
    my ( $self, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw( parameter => 'days' )
        unless defined $params->{days};

    return $self->search(
        {
            'iso18626_request.status'      => 'CopyCompleted',
            'iso18626_request.received_on' => { '<' => \[ 'DATE_SUB(NOW(), INTERVAL ? DAY)', $params->{days} ] },
        },
        { join => 'iso18626_request' }
    );
}

=head3 filter_by_purgeable_patron

    my $purgeable = Koha::ILL::Documents->filter_by_purgeable_patron( { days => 30 } );

Returns a I<Koha::ILL::Documents> resultset filtered to documents delivered to
patrons that were first downloaded more than the specified number of days ago, or
uploaded more than the specified number of days ago if never downloaded.

The caller can then use C<< ->count >> for reporting or C<< ->delete >> to purge.

=cut

sub filter_by_purgeable_patron {
    my ( $self, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw( parameter => 'days' )
        unless defined $params->{days};

    my $cutoff = \[ 'DATE_SUB(NOW(), INTERVAL ? DAY)', $params->{days} ];

    return $self->search(
        {
            illrequest_id => { '!=' => undef },
            -or           => [
                downloaded_on => { '<' => $cutoff },
                -and          => [ downloaded_on => undef, uploaded_on => { '<' => $cutoff } ],
            ],
        }
    );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'IllDocument';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ILL::Document';
}

1;
