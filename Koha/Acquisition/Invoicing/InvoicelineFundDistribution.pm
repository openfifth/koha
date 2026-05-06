package Koha::Acquisition::Invoicing::InvoicelineFundDistribution;

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

use Koha::Acquisition::Invoicing::Invoiceline;
use Koha::Acquisition::Finances::Fund;

=head1 NAME

Koha::Acquisition::Invoicing::InvoicelineFundDistribution - Object class for acq_invoiceline_fund_distributions

=head1 API

=head2 Class methods

=head3 invoiceline

Returns the invoiceline for this fund distribution.

=cut

sub invoiceline {
    my ($self) = @_;
    my $invoiceline_rs = $self->_result->invoiceline;
    return unless $invoiceline_rs;
    return Koha::Acquisition::Invoicing::Invoiceline->_new_from_dbic($invoiceline_rs);
}

=head3 fund

Returns the fund for this distribution.

=cut

sub fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->fund;
    return unless $fund_rs;
    return Koha::Acquisition::Finances::Fund->_new_from_dbic($fund_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqInvoicelineFundDistribution';
}

1;
