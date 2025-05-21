package Koha::REST::V1::DeletedItems;

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Old::Items;
use Koha::Old::Biblios;

use Try::Tiny qw( catch try );
use Data::Dumper;

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing deleted items

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $query = {};
        if ($c->param('biblionumber')) {
            $query->{biblionumber} = $c->param('biblionumber');
        }
        if ($c->param('barcode')) {
            $query->{barcode} = $c->param('barcode');
        }

        my $items = Koha::Old::Items->search($query, { order_by => { -desc => 'timestamp' } });
        my $items_with_embed = $c->objects->search($items);
        
        return $c->render(
            status  => 200,
            openapi => $items_with_embed
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single deleted item

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $item_id = $c->param('item_id');
        my $item = Koha::Old::Items->find($item_id);
        return $c->render_resource_not_found("Deleted item")
            unless $item;

        my $item_with_embed = $c->objects->to_api($item);
        return $c->render(
            status  => 200,
            openapi => $item_with_embed
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;