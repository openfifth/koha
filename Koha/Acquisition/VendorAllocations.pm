package Koha::Acquisition::VendorAllocations;

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

use Koha::Acquisition::VendorAllocation;

use base qw(Koha::Objects);

=head1 NAME

Koha::Acquisition::VendorAllocations - Object set class for vendor spend allocations

=head1 API

=head2 Class methods

=head3 clone_for_period

    Koha::Acquisition::VendorAllocations->clone_for_period({
        from_budget_period_id         => $old_id,
        to_budget_period_id           => $new_id,
        reset                         => 0,
        amount_change_percentage      => 5,
        amount_change_round_increment => 100,
    });

Copies all vendor allocations from one budget period to another. If C<reset> is true,
all allocation amounts on the cloned records are set to zero. Otherwise the
C<amount_change_percentage> (if set) is applied and amounts are rounded to
C<amount_change_round_increment>.

=cut

sub clone_for_period {
    my ( $class, $params ) = @_;

    my $allocations = $class->search( { budget_period_id => $params->{from_budget_period_id} } );

    while ( my $allocation = $allocations->next ) {
        my $amount;
        if ( $params->{reset} ) {
            $amount = 0;
        } elsif ( $params->{amount_change_percentage} ) {
            $amount = $allocation->allocation_amount;
            $amount += $amount * $params->{amount_change_percentage} / 100;
            if ( $params->{amount_change_round_increment} ) {
                my $increment = $params->{amount_change_round_increment};
                $amount = int( $amount / $increment + 0.5 ) * $increment;
            }
        } else {
            $amount = $allocation->allocation_amount;
        }

        Koha::Acquisition::VendorAllocation->new(
            {
                budget_period_id   => $params->{to_budget_period_id},
                booksellerid       => $allocation->booksellerid,
                allocation_amount  => $amount,
                warn_at_percentage => $allocation->warn_at_percentage,
                warn_at_amount     => $allocation->warn_at_amount,
            }
        )->store;
    }
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AqvendorAllocation';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Acquisition::VendorAllocation';
}

1;
