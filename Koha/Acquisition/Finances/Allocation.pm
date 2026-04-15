package Koha::Acquisition::Finances::Allocation;

# Copyright 2024 PTFS Europe

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
use base qw(Koha::Acquisition::Finances::BaseObject);

use Koha::Acquisition::Finances::Fund;
use Koha::Acquisition::Finances::FiscalPeriod;
use Koha::Acquisition::Finances::Ledger;
use Koha::Patron;
use Koha::Exceptions::Acquisition::Finances;

=head1 NAME

Koha::Acquisition::Finances::Allocation Object class

=head1 API

=head2 Class methods

=head3 store

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    return $self;
}

=head3 delete

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}

=head3 _object_hierarchy

=cut

sub _object_hierarchy {
    return {
        object => 'allocation',
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqAllocation';
}

1;
