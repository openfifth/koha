package Koha::Acquisition::FundManagement::Ledger;

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

use Koha::Acquisition::FundManagement::Funds;
use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::Allocations;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::FundManagement::Ledger Object class

=head1 API

=head2 Class methods

=head3 store

=cut 

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    $self->cascade_to_funds unless $args->{no_cascade};

    return $self;
}

=head3 cascade_to_funds

This method cascades changes to the values of the "status" property to all funds attached to this ledger

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
        my @data_to_cascade = ( 'fiscal_period_id', 'currency', 'owner_id' );
        my $data_updated    = $self->cascade_data(
            {
                parent     => $self,
                child      => $fund,
                properties => \@data_to_cascade
            }
        );
        $fund->store() if $status_updated || $data_updated;
    }
}

=head3 managing_library

=cut

sub managing_library {
    my ($self) = @_;
    my $managing_library_rs = $self->_result->managing_branch;
    return unless $managing_library_rs;
    return Koha::Library->_new_from_dbic($managing_library_rs);
}

=head3 _object_hierarchy

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

=cut

sub _type {
    return 'AcqLedger';
}

1;
