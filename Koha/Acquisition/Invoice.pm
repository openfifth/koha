package Koha::Acquisition::Invoice;

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

use Koha::Acquisition::Order::Items;
use Koha::Acquisition::Orders;
use Koha::DateUtils qw( dt_from_string );

use base qw(Koha::Object Koha::Object::Mixin::AdditionalFields);

=head1 NAME

Koha::Acquisition::Invoice object class

=head1 API

=head2 Class methods

=head3 to_api

    my $json = $invoice->to_api;

Overloaded method that returns a JSON representation of the Koha::Acquisition::Invoice object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $json_invoice = $self->SUPER::to_api($params);
    return unless $json_invoice;

    $json_invoice->{closed} =
        ( $self->closedate )
        ? Mojo::JSON->true
        : Mojo::JSON->false;

    return $json_invoice;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Acquisition::Invoice object
on the API.

=cut

sub to_api_mapping {
    return {
        invoiceid             => 'invoice_id',
        invoicenumber         => 'invoice_number',
        booksellerid          => 'vendor_id',
        shipmentdate          => 'shipping_date',
        billingdate           => 'invoice_date',
        closedate             => 'closed_date',
        shipmentcost          => 'shipping_cost',
        shipmentcost_budgetid => 'shipping_fund_id',
        message_id            => undef
    };
}

=head3 orders

    my $orders = $invoice->orders;

Returns a I<Koha::Acquisition::Orders> resultset for the orders associated
to this invoice.

=cut

sub orders {
    my ($self) = @_;
    my $orders_rs = $self->_result->aqorders;
    return Koha::Acquisition::Orders->_new_from_dbic($orders_rs);
}

=head3 check_and_close

    my $closed = $invoice->check_and_close;

Closes the invoice if all items on non-cancelled order lines have been
physically received (aqorders_items.received IS NOT NULL).

Returns 1 if the invoice was closed, 0 otherwise.
Does nothing if the invoice is already closed or has no linked items.

=cut

sub check_and_close {
    my ($self) = @_;

    return 0 if $self->closedate;

    my @active_order_numbers =
        $self->orders->search( { orderstatus => { '!=' => 'cancelled' } } )->get_column('ordernumber');

    return 0 unless @active_order_numbers;

    my $order_items = Koha::Acquisition::Order::Items->search( { ordernumber => \@active_order_numbers } );

    return 0 unless $order_items->count;
    return 0 if $order_items->search( { received => undef } )->count;

    $self->update( { closedate => dt_from_string()->ymd } );
    return 1;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Aqinvoice';
}

1;
