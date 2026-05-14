package Koha::Acquisition::Finances::Fund;

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

use Koha::Acquisition::Finances::Allocations;
use Koha::Acquisition::Finances::FundSummaries;
use Koha::Acquisition::Finances::Ledger;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::Finances::Fund Object class

=head1 API

=head2 Class methods

=head3 store

    $fund->store;
    $fund->store({ no_cascade => 1 });

Saves the fund record. Unless C<no_cascade> is set, cascades any status change to all
attached sub-funds via C<cascade_to_sub_funds>. Returns C<$self>.

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

Deletes the fund record. Attached allocations and sub-funds are removed by database cascade.
Returns C<$self>.

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}

=head3 sub_funds

    my $sub_funds = $fund->sub_funds;
    my $sub_funds = $fund->sub_funds({ embed_children => 1 });

Returns a C<Koha::Acquisition::Finances::Funds> result set of direct child funds.

When C<embed_children> is true, returns a flattened arrayref of all nested sub-funds at
every depth (via C<_embed_child_funds>).

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

Returns the parent C<Koha::Acquisition::Finances::Fund> for this sub-fund, or C<undef> if
this fund has no parent.

=cut

sub parent_fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->parent_fund;
    return unless $fund_rs;
    return Koha::Acquisition::Finances::Fund->_new_from_dbic($fund_rs);
}

=head3 is_sub_fund

Returns 1 if this fund has a parent fund (C<parent_fund_id> is set), 0 otherwise.

=cut

sub is_sub_fund {
    my ( $self, $args ) = @_;

    return $self->parent_fund_id ? 1 : 0;
}

=head3 has_sub_funds

Returns 1 if this fund has at least one direct sub-fund, 0 otherwise.

=cut

sub has_sub_funds {
    my ( $self, $args ) = @_;

    my $sub_funds = $self->sub_funds( { embed_children => 0 } );

    return 1 if $sub_funds->count > 0;
    return 0;
}

=head3 cascade_to_sub_funds

Propagates this fund's C<status> to all direct sub-funds. Sub-funds whose status actually
changes are stored (cascading further down the hierarchy). Only changed sub-funds are written.

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

Returns a hashref describing this object's position in the finance hierarchy.
Used internally by C<BaseObject> methods to determine field names and relationships.

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

Returns the C<Koha::Library> that manages this fund, or C<undef> if none is set.

=cut

sub managing_library {
    my ($self) = @_;
    my $managing_library_rs = $self->_result->managing_branch;
    return unless $managing_library_rs;
    return Koha::Library->_new_from_dbic($managing_library_rs);
}

=head3 fiscal_period

Returns the C<Koha::Acquisition::Finances::FiscalPeriod> for this fund, resolved via its
parent ledger.

=cut

sub fiscal_period {
    my ($self) = @_;
    return $self->ledger->fiscal_period;
}

=head3 to_api

    my $json = $fund->to_api;
    my $json = $fund->to_api({ embed => { ... } });

Overloaded method returning a hashref representation of the fund suitable for API output.
Delegates to C<BaseObject::to_api> and appends a C<currency> field sourced from the parent ledger.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $response = $self->SUPER::to_api($params);

    $response->{currency} = $self->ledger->currency;

    my $overrides = {};

    return { %$response, %$overrides };
}

=head3 summary

Returns the C<Koha::Acquisition::Finances::FundSummary> view row for this fund (aggregating
ordered, spent, and pre-encumbered amounts), or C<undef> if no summary row exists.

=cut

sub summary {
    my ($self) = @_;
    return Koha::Acquisition::Finances::FundSummaries->search( { fund_id => $self->fund_id } )->single;
}

=head2 Internal methods

=head3 _type

Returns the DBIx::Class result class name for funds (C<AcqFund>).

=cut

sub _type {
    return 'AcqFund';
}

=head3 _embed_child_funds

    my $list = _embed_child_funds({ sub_funds => $funds_rs });
    my $list = _embed_child_funds({ sub_funds => $funds_rs, sub_fund_list => \@existing });

Recursively collects all sub-funds (and their sub-funds) into a flat arrayref. Internal
helper used by C<sub_funds> when C<embed_children> is true. Returns the accumulated arrayref.

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
