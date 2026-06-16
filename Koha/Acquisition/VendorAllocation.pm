package Koha::Acquisition::VendorAllocation;

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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use C4::Budgets qw( FieldsForCalculatingFundValues );
use Koha::Database;

use base qw(Koha::Object);

=head1 NAME

Koha::Acquisition::VendorAllocation - Object class for vendor spend allocations

=head1 API

=head2 Class methods

=head3 spent

    my $spent = $vendor_allocation->spent;

Returns the total amount spent (received orders) for this vendor in this budget period.

=cut

sub spent {
    my ($self) = @_;

    my ( $unitprice_field, $ecost_field ) = FieldsForCalculatingFundValues();

    my $rs = Koha::Database->new->schema->resultset('Aqorder')->search(
        {
            'basketno.booksellerid'       => $self->booksellerid,
            'budget.budget_period_id'     => $self->budget_period_id,
            'me.quantityreceived'         => { '>' => 0 },
            'me.datecancellationprinted'  => undef,
        },
        {
            join   => [ 'basketno', 'budget' ],
            select => [ { sum => \"COALESCE(me.$unitprice_field, me.$ecost_field) * me.quantity" } ],
            as     => ['total'],
        }
    );

    return ( $rs->single->get_column('total') // 0 ) + 0;
}

=head3 ordered

    my $ordered = $vendor_allocation->ordered;

Returns the total amount on open (not yet received) orders for this vendor in this budget period.

=cut

sub ordered {
    my ($self) = @_;

    my ( undef, $ecost_field ) = FieldsForCalculatingFundValues();

    my $rs = Koha::Database->new->schema->resultset('Aqorder')->search(
        {
            'basketno.booksellerid'       => $self->booksellerid,
            'budget.budget_period_id'     => $self->budget_period_id,
            'me.quantityreceived'         => 0,
            'me.datecancellationprinted'  => undef,
        },
        {
            join   => [ 'basketno', 'budget' ],
            select => [ { sum => \"me.$ecost_field * me.quantity" } ],
            as     => ['total'],
        }
    );

    return ( $rs->single->get_column('total') // 0 ) + 0;
}

=head3 used

    my $used = $vendor_allocation->used;

Returns the total amount used (spent + ordered) for this vendor in this budget period.

=cut

sub used {
    my ($self) = @_;
    return $self->spent + $self->ordered;
}

=head3 remaining

    my $remaining = $vendor_allocation->remaining;

Returns the remaining allocation amount (allocation_amount - used).

=cut

sub remaining {
    my ($self) = @_;
    return $self->allocation_amount - $self->used;
}

=head3 to_api_mapping

=cut

sub to_api_mapping {
    return {
        id           => 'allocation_id',
        booksellerid => 'vendor_id',
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AqvendorAllocation';
}

1;
