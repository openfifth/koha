package Koha::Acquisition::Finances::Allocation;

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

Saves the allocation record. Returns C<$self>.

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    return $self;
}

=head3 delete

Deletes the allocation record. Returns C<$self>.

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}

=head3 _object_hierarchy

Returns a hashref describing this object's position in the finance hierarchy.
Used internally by C<BaseObject> methods to determine field names and relationships.

=cut

sub _object_hierarchy {
    return {
        object => 'allocation',
    };
}

=head2 Internal methods

=head3 _type

Returns the DBIx::Class result class name for allocations (C<AcqAllocation>).

=cut

sub _type {
    return 'AcqAllocation';
}

1;
