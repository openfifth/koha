package Koha::Acquisition::FundManagement::FiscalPeriod;

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
use base qw(Koha::Acquisition::FundManagement::BaseObject);

use Koha::Acquisition::FundManagement::Ledgers;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::FundManagement::FiscalPeriod Object class

=head1 API

=head2 Class methods

=head3 store

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    $self->cascade_to_ledgers unless $args->{no_cascade};

    return $self;
}

=head3 cascade_to_ledgers

This method cascades changes to the values of the "status" property to all ledgers attached to this fiscal period

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

=head3 _object_hierarchy

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

=cut

sub _type {
    return 'FiscalPeriod';
}

1;
