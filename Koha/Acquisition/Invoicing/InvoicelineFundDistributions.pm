package Koha::Acquisition::Invoicing::InvoicelineFundDistributions;

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
use base qw(Koha::Objects);

use Koha::Acquisition::Invoicing::InvoicelineFundDistribution;

=head1 NAME

Koha::Acquisition::Invoicing::InvoicelineFundDistributions - Object set class for acq_invoiceline_fund_distributions

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqInvoicelineFundDistribution';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Acquisition::Invoicing::InvoicelineFundDistribution';
}

1;
