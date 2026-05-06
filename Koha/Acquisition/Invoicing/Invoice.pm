package Koha::Acquisition::Invoicing::Invoice;

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
use base qw(Koha::Object);

use Koha::Acquisition::Invoicing::Invoicelines;
use Koha::Acquisition::Bookseller;

=head1 NAME

Koha::Acquisition::Invoicing::Invoice - Object class for acq_invoices

=head1 API

=head2 Class methods

=head3 invoicelines

Returns the invoicelines for this invoice.

=cut

sub invoicelines {
    my ($self) = @_;
    my $invoicelines_rs = $self->_result->acq_invoicelines;
    return Koha::Acquisition::Invoicing::Invoicelines->_new_from_dbic($invoicelines_rs);
}

=head3 vendor

Returns the vendor for this invoice.

=cut

sub vendor {
    my ($self) = @_;
    my $vendor_rs = $self->_result->vendor;
    return unless $vendor_rs;
    return Koha::Acquisition::Bookseller->_new_from_dbic($vendor_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqInvoice';
}

1;
