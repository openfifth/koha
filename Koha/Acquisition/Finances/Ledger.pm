package Koha::Acquisition::Finances::Ledger;

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

use Koha::Acquisition::Finances::Funds;
use Koha::Acquisition::Finances::FiscalPeriod;
use Koha::Acquisition::Finances::Allocations;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::Finances::Ledger Object class

=head1 API

=head2 Class methods

=head3 store

    $ledger->store;
    $ledger->store({ no_cascade => 1 });

Saves the ledger record. Unless C<no_cascade> is set, cascades any status change to all
attached funds via C<cascade_to_funds>. Returns C<$self>.

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    $self->cascade_to_funds unless $args->{no_cascade};

    return $self;
}

=head3 cascade_to_funds

Propagates this ledger's C<status> to all attached funds. Funds whose status differs are
stored (which in turn cascades to their sub-funds). Only changed funds are written.

=cut

sub cascade_to_funds {
    my ( $self, $args ) = @_;

    my @funds  = $self->funds->as_list;
    my $status = $self->status;

    foreach my $fund (@funds) {
        my $status_updated = $self->cascade_status(
            {
                parent_status => $status,
                child         => $fund
            }
        );
        $fund->store() if $status_updated;
    }
}

=head3 managing_library

Returns the C<Koha::Library> that manages this ledger, or C<undef> if none is set.

=cut

sub managing_library {
    my ($self) = @_;
    my $managing_library_rs = $self->_result->managing_branch;
    return unless $managing_library_rs;
    return Koha::Library->_new_from_dbic($managing_library_rs);
}

=head3 _object_hierarchy

Returns a hashref describing this object's position in the finance hierarchy.
Used internally by C<BaseObject> methods to determine field names and relationships.

=cut

sub _object_hierarchy {
    return {
        object   => 'ledger',
        parent   => 'fiscal_period',
        child    => 'fund',
        children => 'funds'
    };
}

=head2 Internal methods

=head3 _type

Returns the DBIx::Class result class name for ledgers (C<AcqLedger>).

=cut

sub _type {
    return 'AcqLedger';
}

1;
