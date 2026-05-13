package Koha::Acquisition::OrderManagement::PurchaseOrder;

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

use Koha::Acquisition::Bookseller;
use Koha::Acquisition::Contract;
use Koha::Library;

=head1 NAME

Koha::Acquisition::OrderManagement::PurchaseOrder - Object class for purchase orders

=head1 API

=head2 Class methods

=head3 vendor

=cut

sub vendor {
    my ($self) = @_;
    my $vendor_rs = $self->_result->vendor;
    return unless $vendor_rs;
    return Koha::Acquisition::Bookseller->_new_from_dbic($vendor_rs);
}

=head3 contract

=cut

sub contract {
    my ($self) = @_;
    my $contract_rs = $self->_result->contract;
    return unless $contract_rs;
    return Koha::Acquisition::Contract->_new_from_dbic($contract_rs);
}

=head3 billing_library

=cut

sub billing_library {
    my ($self) = @_;
    my $rs = $self->_result->billing_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 delivery_library

=cut

sub delivery_library {
    my ($self) = @_;
    my $rs = $self->_result->delivery_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqPurchaseOrder';
}

1;
