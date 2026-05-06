package Koha::Acquisition::Invoicing::Accession;

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

use Koha::Acquisition::OrderManagement::Orderline;
use Koha::Acquisition::Invoicing::Invoiceline;

=head1 NAME

Koha::Acquisition::Invoicing::Accession - Object class for acq_accessions

=head1 API

=head2 Class methods

=head3 orderline

Returns the orderline for this accession.

=cut

sub orderline {
    my ($self) = @_;
    my $orderline_rs = $self->_result->orderline;
    return unless $orderline_rs;
    return Koha::Acquisition::OrderManagement::Orderline->_new_from_dbic($orderline_rs);
}

=head3 invoiceline

Returns the invoiceline for this accession.

=cut

sub invoiceline {
    my ($self) = @_;
    my $invoiceline_rs = $self->_result->invoiceline;
    return unless $invoiceline_rs;
    return Koha::Acquisition::Invoicing::Invoiceline->_new_from_dbic($invoiceline_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqAccession';
}

1;
