package Koha::VendorEdiAccount;

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

use Koha::Acquisition::Bookseller;
use Koha::File::Transport;

use base qw( Koha::Object );

=head1 NAME

Koha::VendorEdiAccount - Koha Vendor EDI Account Object class

=head1 API

=head2 Class Methods

=cut

=head3 vendor

=cut

sub vendor {
    my ($self) = @_;
    my $vendor_rs = $self->_result->vendor;
    return unless $vendor_rs;
    return Koha::Acquisition::Bookseller->_new_from_dbic($vendor_rs);
}

=head3 file_transport

=cut

sub file_transport {
    my ($self) = @_;
    my $ft_rs = $self->_result->file_transport;
    return unless $ft_rs;
    return Koha::File::Transport->_new_from_dbic($ft_rs);
}

=head3 to_api_mapping

=cut

sub to_api_mapping {
    return { id => 'vendor_edi_account_id' };
}

=head3 _type

=cut

sub _type {
    return 'VendorEdiAccount';
}

1;
