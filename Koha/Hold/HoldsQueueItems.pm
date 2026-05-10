package Koha::Hold::HoldsQueueItems;

# Copyright 2023 Koha development team
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

use Koha::Biblios;
use Koha::Hold::HoldsQueueItem;

use base qw(Koha::Objects);

=head1 NAME

Koha::Hold::HoldsQueueItems - Koha holds queue items object set class

=head1 API

=head2 Class methods

=head3 api_query_fixer

    $query = $holds_queue_items->api_query_fixer( $query, $context, $no_quotes );

Delegates to L<Koha::Biblios> to rewrite biblioitem attribute names
(e.g. C<biblio.publisher>) into their DBIC-resolvable form
(e.g. C<biblio.biblioitem.publishercode>).

=cut

sub api_query_fixer {
    my ( $self, $query, $context, $no_quotes ) = @_;

    return Koha::Biblios->new->api_query_fixer( $query, 'biblio', $no_quotes );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'TmpHoldsqueue';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Hold::HoldsQueueItem';
}

=head1 AUTHORS

Kyle Hall <kyle@bywatersolutions.com>

=cut

1;
