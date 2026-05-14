package Koha::Acquisition::Finances::FiscalPeriod;

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

use Koha::Acquisition::Finances::Ledgers;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::Finances::FiscalPeriod Object class

=head1 API

=head2 Class methods

=head3 store

    $fiscal_period->store;
    $fiscal_period->store({ no_cascade => 1 });

Saves the fiscal period record. Unless C<no_cascade> is set, cascades any status change to
all attached ledgers via C<cascade_to_ledgers>. Returns C<$self>.

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    $self->cascade_to_ledgers unless $args->{no_cascade};

    return $self;
}

=head3 cascade_to_ledgers

Propagates this fiscal period's C<status> to all attached ledgers. Ledgers whose status
differs are stored (which in turn cascades to their funds). Only changed ledgers are written.

=cut

sub cascade_to_ledgers {
    my ( $self, $args ) = @_;

    my @ledgers = $self->ledgers->as_list;
    my $status  = $self->status;

    foreach my $ledger (@ledgers) {
        my $status_updated = $self->cascade_status(
            {
                parent_status => $status,
                child         => $ledger
            }
        );
        $ledger->store() if $status_updated;
    }
}

=head3 managing_library

Returns the C<Koha::Library> that manages this fiscal period, or C<undef> if none is set.

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
        object   => 'fiscal_period',
        parent   => undef,
        child    => 'ledger',
        children => 'ledgers'
    };
}

=head2 Internal methods

=head3 _type

Returns the DBIx::Class result class name for fiscal periods (C<AcqFiscalPeriod>).

=cut

sub _type {
    return 'AcqFiscalPeriod';
}

1;
