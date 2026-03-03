package Koha::Acquisition::Order::Item;

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

use Try::Tiny;

use C4::Context;
use Koha::Acquisition::Order;

use base qw(Koha::Object);

=head1 NAME

Koha::Acquisition::Order::Item - Koha Order Item Object class

=head1 API

=head2 Class methods

=head3 order

    my $order = $order_item->order;

Returns the I<Koha::Acquisition::Order> object for the order associated to this item.

=cut

sub order {
    my ($self) = @_;
    my $order_rs = $self->_result->ordernumber;
    return unless $order_rs;
    return Koha::Acquisition::Order->_new_from_dbic($order_rs);
}

=head3 record_physical_receipt

    $order_item->record_physical_receipt;

Called on circulation check-in. Stamps C<received> with the current datetime if
not already set (first check-in only), then attempts to auto-close the associated
invoice if the C<AutoCloseInvoicesOnCheckin> system preference is enabled.

Only meaningful when the basket's effective item-creation policy is C<ordering>
(i.e. items exist in C<aqorders_items> before physical receipt). For C<receiving>
or C<cataloguing> policies the C<aqorders_items> row either does not exist or is
not populated by circulation, so this method silently no-ops in those cases.

Also silently no-ops if the linked order is cancelled or has no invoice.
Exceptions from DB operations are caught and logged so a write failure never
aborts a check-in.

=cut

sub record_physical_receipt {
    my ($self) = @_;

    my $order = $self->order;
    return unless $order && $order->orderstatus ne 'cancelled';

    return unless $order->basket->effective_create_items eq 'ordering';

    my $invoice = $order->invoice;
    return unless $invoice;

    try {
        $self->update( { received => \'NOW()' } ) unless $self->received;
        $invoice->check_and_close if C4::Context->preference('AutoCloseInvoicesOnCheckin');
    } catch {
        warn sprintf( "Failed to record physical receipt for item %s: %s", $self->itemnumber, $_ );
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AqordersItem';
}

1;
