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
        $query->{biblionumber} = $c->param('biblionumber') if $c->param('biblionumber');
        $query->{barcode} = $c->param('barcode') if $c->param('barcode');

        return Koha::Database->new->schema->txn_do(
            sub {
                my $rs = Koha::Old::Items->search($query, { order_by => { -desc => 'timestamp' } });
                my $items = [];
                while (my $item = $rs->next) {
                    my $item_data = $c->objects->to_api($item);
                    $item_data->{itemnumber} = $item->itemnumber;
                    $item_data->{biblionumber} = $item->biblionumber;
                    $item_data->{barcode} = $item->barcode;
                    push @$items, $item_data;
                }
                warn "DeletedItems.pm list() returning: " . Data::Dumper::Dumper($items);
                return $c->render(
                    status  => 200,
                    openapi => $items
                );
            }
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

    $c->app->log->debug("TEST LOGGING: get method called");  # Using Mojolicious logging

    # Log all deleted items
    my $all_items = Koha::Old::Items->search;
    $c->app->log->debug("DEBUG: All deleted items: " . Dumper($all_items->as_list));

    my $item = Koha::Old::Items->find($c->param('item_id'));
    $c->app->log->debug("DEBUG: Item object: " . Dumper($item));
    my $result = $c->objects->find($item, $c->param('item_id'));
    $c->app->log->debug("DEBUG: Find result: " . Dumper($result));
    return $result;
}

1;