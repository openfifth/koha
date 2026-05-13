package Koha::REST::V1::Acquisitions::OrderManagement::PurchaseOrders;

# Copyright 2025 PTFS Europe

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
use Try::Tiny;

use Koha::Acquisition::OrderManagement::PurchaseOrder;
use Koha::Acquisition::OrderManagement::PurchaseOrders;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $purchase_orders = $c->objects->search( Koha::Acquisition::OrderManagement::PurchaseOrders->new );
        return $c->render( status => 200, openapi => $purchase_orders );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $purchase_order = Koha::Acquisition::OrderManagement::PurchaseOrders->find( $c->param('purchase_order_id') );
        return $c->render_resource_not_found("Purchase order")
            unless $purchase_order;

        return $c->render( status => 200, openapi => $c->objects->to_api($purchase_order) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body                = $c->req->json;
        my $extended_attributes = delete $body->{extended_attributes} // [];

        my $purchase_order = Koha::Acquisition::OrderManagement::PurchaseOrder->new_from_api($body)->store->discard_changes;

        my @extended_attributes =
            map { { 'id' => $_->{field_id}, 'value' => $_->{value} } } @{$extended_attributes};
        $purchase_order->extended_attributes( \@extended_attributes );

        $c->res->headers->location( $c->req->url->to_string . '/' . $purchase_order->purchase_order_id );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($purchase_order)
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $purchase_order = Koha::Acquisition::OrderManagement::PurchaseOrders->find( $c->param('purchase_order_id') );

    return $c->render_resource_not_found("Purchase order")
        unless $purchase_order;

    return try {
        my $body                = $c->req->json;
        my $extended_attributes = delete $body->{extended_attributes} // [];

        $purchase_order->set_from_api($body)->store;

        my @extended_attributes =
            map { { 'id' => $_->{field_id}, 'value' => $_->{value} } } @{$extended_attributes};
        $purchase_order->extended_attributes( \@extended_attributes );

        $c->res->headers->location( $c->req->url->to_string . '/' . $purchase_order->purchase_order_id );
        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($purchase_order)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $purchase_order = Koha::Acquisition::OrderManagement::PurchaseOrders->find( $c->param('purchase_order_id') );
    return $c->render_resource_not_found("Purchase order")
        unless $purchase_order;

    return try {
        $purchase_order->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
