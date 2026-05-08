package Koha::Biblio::Availability::Hold;

# Copyright 2026 Koha Development Team
#
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

use C4::Items qw( get_hostitemnumbers_of );
use Koha::Items;
use Koha::Item::Availability::Hold;
use Koha::Result::Availability;

=head1 NAME

Koha::Biblio::Availability::Hold - Biblio-level hold availability

=head1 SYNOPSIS

    my $availability = Koha::Biblio::Availability::Hold->check({
        biblio         => $biblio,
        patron         => $patron,
        pickup_library => $pickup_library,
    });

=head1 DESCRIPTION

Checks whether a patron can place a biblio-level hold. Runs patron
eligibility once, then iterates items looking for at least one that
is holdable. Returns L<Koha::Result::Availability>.

=head1 API

=head2 Class methods

=head3 check

Parameters (hashref):

=over 4

=item biblio - Koha::Biblio object (required)

=item patron - Koha::Patron object (required)

=item pickup_library - Koha::Library object (optional)

=item item_type_id - limit to specific itemtype (optional)

=item overrides - hashref of checks to skip (optional)

=item no_short_circuit - collect all blockers (optional)

=back

=cut

sub check {
    my ( $class, $params ) = @_;

    my $biblio           = $params->{biblio};
    my $patron           = $params->{patron};
    my $pickup_library   = $params->{pickup_library};
    my $item_type_id     = $params->{item_type_id};
    my $overrides        = $params->{overrides}        // {};
    my $no_short_circuit = $params->{no_short_circuit} // 0;

    # Patron eligibility + count checks
    my $patron_check_params = {
        patron           => $patron,
        overrides        => $overrides,
        no_short_circuit => $no_short_circuit,
        biblio_id        => $biblio->biblionumber,
        library_id       => $pickup_library ? $pickup_library->branchcode : $patron->branchcode,
    };
    $patron_check_params->{item_type_id} = $item_type_id if $item_type_id;
    my $patron_result = Koha::Patron::Availability::Hold->check($patron_check_params);

    my $result = Koha::Result::Availability->new();

    if ( !$patron_result->available ) {
        for my $key ( keys %{ $patron_result->blockers } ) {
            $result->add_blocker( $key => $patron_result->blockers->{$key} );
        }
        return $result unless $no_short_circuit;
    }

    # Iterate items looking for at least one holdable
    # TODO: Consider fetching items with a JOIN to avoid N+1 queries in the loop
    # (e.g., prefetch homebranch for hold group validation).
    my $items_search = {};
    $items_search->{itype} = $item_type_id if $item_type_id;

    my @items = $biblio->items->search($items_search)->as_list;

    # Include items linked via host records (analytics)
    my @hostitemnumbers = C4::Items::get_hostitemnumbers_of( $biblio->biblionumber );
    if (@hostitemnumbers) {
        my @host_items = Koha::Items->search( { itemnumber => { -in => \@hostitemnumbers }, %$items_search } )->as_list;
        push @items, @host_items;
    }

    for my $item (@items) {
        my $item_result = Koha::Item::Availability::Hold->check(
            {
                item               => $item,
                patron             => $patron,
                pickup_library     => $pickup_library,
                overrides          => $overrides,
                skip_patron_checks => 1,
            }
        );
        if ( $item_result->available ) {
            $result->set_context( available_item => $item );
            return $result;
        }
    }

    # No item available
    $result->add_blocker( no_item_available => 1 ) unless @items == 0;
    $result->add_blocker( no_items          => 1 ) if @items == 0;

    return $result;
}

1;
