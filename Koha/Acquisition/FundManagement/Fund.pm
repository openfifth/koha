package Koha::Acquisition::FundManagement::Fund;

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

use Koha::Acquisition::FundManagement::Allocations;
use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::Ledger;
use Koha::Acquisition::FundManagement::FundGroup;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::FundManagement::Fund Object class

=head1 API

=head2 Class methods

=head3 store

=cut 

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    # unless ( $args->{no_cascade} ) {
    #     $self->cascade_to_sub_funds;
    # }

    return $self;
}

=head3 delete

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}

=head3 sub_funds

Returns any sub funds with any further nested funds embedded

=cut

sub sub_funds {
    my ( $self, $args ) = @_;

    my $embed_children = $args->{embed_children} || 0;

    my $sub_funds = Koha::Acquisition::FundManagement::Funds->search( { fund_parent_id => $self->fund_id } );

    if ($embed_children) {
        $sub_funds = _embed_child_funds( { sub_funds => $sub_funds } );
    }

    return $sub_funds;
}

=head3 parent_fund

Embeds the parent fund to a child fund

=cut

sub parent_fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->parent_fund;
    return unless $fund_rs;
    return Koha::Acquisition::FundManagement::Fund->_new_from_dbic($fund_rs);
}

=head3 has_sub_funds

Checks if a fund has sub funds

=cut

sub has_sub_funds {
    my ( $self, $args ) = @_;

    my $sub_funds = $self->sub_funds( { embed_children => 0 } );

    return 1 if scalar( @{$sub_funds} ) > 0;
    return 0;
}

=head3 cascade_to_fund_allocations

This method cascades changes to the values of the "status" property to all fund_allocations attached to this fund

=cut

sub cascade_to_fund_allocations {
    my ( $self, $args ) = @_;

    my @fund_allocations = $self->fund_allocations->as_list;

    foreach my $fund_allocation (@fund_allocations) {
        my @data_to_cascade = ( 'fiscal_period_id', 'currency', 'owner_id', 'ledger_id' );
        my $data_updated    = $self->cascade_data(
            {
                parent     => $self,
                child      => $fund_allocation,
                properties => \@data_to_cascade
            }
        );
        $fund_allocation->store() if $data_updated;
    }
}

=head3 cascade_to_sub_funds

This method cascades changes to the values of the "status" properties to all sub_funds attached to this fund

=cut

sub cascade_to_sub_funds {
    my ( $self, $args ) = @_;

    my $sub_funds = $self->sub_funds;
    my $status    = $self->status;

    foreach my $sub_fund (@$sub_funds) {
        my $status_updated = $self->cascade_status(
            {
                parent_status => $status,
                child         => $sub_fund
            }
        );
        my @data_to_cascade = ( 'fiscal_period_id', 'currency', 'owner_id', 'ledger_id' );
        my $data_updated    = $self->cascade_data(
            {
                parent     => $self,
                child      => $sub_fund,
                properties => \@data_to_cascade
            }
        );
        $sub_fund->store() if $status_updated || $data_updated;
    }
}

=head3 _object_hierarchy

=cut

sub _object_hierarchy {
    return {
        object   => 'fund',
        parent   => 'ledger',
        child    => 'sub_fund',
        children => 'sub_funds'
    };
}

=head3 managing_library

=cut

sub managing_library {
    my ($self) = @_;
    my $managing_library_rs = $self->_result->managing_branch;
    return unless $managing_library_rs;
    return Koha::Library->_new_from_dbic($managing_library_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqFund';
}

=head3 _embed_child_funds

Recursively finds child funds and adds them to an array for embedding

=cut

sub _embed_child_funds {
    my ($args) = @_;

    my $sub_funds     = $args->{sub_funds};
    my $sub_fund_list = $args->{sub_fund_list} || [];

    foreach my $sub_fund ( $sub_funds->as_list ) {
        my $child_funds = Koha::Acquisition::FundManagement::Funds->search( { fund_parent_id => $sub_fund->fund_id } );
        push( @$sub_fund_list, $sub_fund );
        _embed_child_funds( { sub_funds => $child_funds, sub_fund_list => $sub_fund_list } );
    }

    return $sub_fund_list;
}

1;
