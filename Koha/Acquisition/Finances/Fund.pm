package Koha::Acquisition::Finances::Fund;

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

use Koha::Acquisition::Finances::Allocations;
use Koha::Acquisition::Finances::FundSummaries;
use Koha::Acquisition::Finances::Ledger;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::Finances::Fund Object class

=head1 API

=head2 Class methods

=head3 store

=cut 

sub store {
    my ( $self, $args ) = @_;

    $self->SUPER::store;

    unless ( $args->{no_cascade} ) {
        $self->cascade_to_sub_funds;
    }

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

    my $sub_funds = Koha::Acquisition::Finances::Funds->search( { parent_fund_id => $self->fund_id } );

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
    return Koha::Acquisition::Finances::Fund->_new_from_dbic($fund_rs);
}

=head3 is_sub_fund

Checks if a fund is a sub fund

=cut

sub is_sub_fund {
    my ( $self, $args ) = @_;

    return $self->parent_fund_id ? 1 : 0;
}

=head3 has_sub_funds

Checks if a fund has sub funds

=cut

sub has_sub_funds {
    my ( $self, $args ) = @_;

    my $sub_funds = $self->sub_funds( { embed_children => 0 } );

    return 1 if $sub_funds->count > 0;
    return 0;
}

=head3 cascade_to_sub_funds

This method cascades changes to the values of the "status" properties to all sub_funds attached to this fund

=cut

sub cascade_to_sub_funds {
    my ( $self, $args ) = @_;

    my @sub_funds = $self->sub_funds->as_list;
    my $status    = $self->status;

    foreach my $sub_fund (@sub_funds) {
        my $status_updated = $self->cascade_status(
            {
                parent_status => $status,
                child         => $sub_fund
            }
        );
        $sub_fund->store() if $status_updated;
    }
}

=head3 _object_hierarchy

=cut

sub _object_hierarchy {
    return {
        object   => 'fund',
        parent   => 'ledger',
        child    => 'fund',
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

=head3 fiscal_period

=cut

sub fiscal_period {
    my ($self) = @_;
    return $self->ledger->fiscal_period;
}

=head3 to_api

    my $json = $av->to_api;

Overloaded method that returns a JSON representation of the object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $response = $self->SUPER::to_api($params);

    $response->{currency} = $self->ledger->currency;

    my $overrides = {};

    return { %$response, %$overrides };
}

=head3 summary

=cut

sub summary {
    my ($self) = @_;
    return Koha::Acquisition::Finances::FundSummaries->search( { fund_id => $self->fund_id } )->single;
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
        my $child_funds = Koha::Acquisition::Finances::Funds->search( { parent_fund_id => $sub_fund->fund_id } );
        push( @$sub_fund_list, $sub_fund );
        _embed_child_funds( { sub_funds => $child_funds, sub_fund_list => $sub_fund_list } );
    }

    return $sub_fund_list;
}

1;
