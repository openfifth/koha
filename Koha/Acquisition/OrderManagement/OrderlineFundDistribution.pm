package Koha::Acquisition::OrderManagement::OrderlineFundDistribution;

# Copyright 2026 Open Fifth

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

use Koha::Acquisition::Finances::Fund;

=head1 NAME

Koha::Acquisition::OrderManagement::OrderlineFundDistribution - Object class for acq_orderline_fund_distributions

=head1 API

=head2 Class methods

=head3 fund

Returns the C<Koha::Acquisition::Finances::Fund> for this distribution, or C<undef>
if the fund record no longer exists.

=cut

sub fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->fund;
    return unless $fund_rs;
    return Koha::Acquisition::Finances::Fund->_new_from_dbic($fund_rs);
}

=head2 Internal methods

=head3 _type

Returns the DBIx::Class result class name for orderline fund distributions
(C<AcqOrderlineFundDistribution>).

=cut

sub _type {
    return 'AcqOrderlineFundDistribution';
}

1;
