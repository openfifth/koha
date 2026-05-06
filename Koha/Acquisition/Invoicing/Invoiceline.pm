package Koha::Acquisition::Invoicing::Invoiceline;

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

use Koha::Acquisition::Invoicing::Invoice;
use Koha::Acquisition::Invoicing::InvoicelineFundDistributions;
use Koha::Acquisition::Invoicing::Accessions;

=head1 NAME

Koha::Acquisition::Invoicing::Invoiceline - Object class for acq_invoicelines

=head1 API

=head2 Class methods

=head3 invoice

Returns the invoice for this invoiceline.

=cut

sub invoice {
    my ($self) = @_;
    my $invoice_rs = $self->_result->invoice;
    return unless $invoice_rs;
    return Koha::Acquisition::Invoicing::Invoice->_new_from_dbic($invoice_rs);
}

=head3 fund_distributions

Returns the fund distributions for this invoiceline.

=cut

sub fund_distributions {
    my ($self) = @_;
    my $fund_distributions_rs = $self->_result->acq_invoiceline_fund_distributions;
    return Koha::Acquisition::Invoicing::InvoicelineFundDistributions->_new_from_dbic($fund_distributions_rs);
}

=head3 accessions

Returns the accessions for this invoiceline.

=cut

sub accessions {
    my ($self) = @_;
    my $accessions_rs = $self->_result->acq_accessions;
    return Koha::Acquisition::Invoicing::Accessions->_new_from_dbic($accessions_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqInvoiceline';
}

1;
