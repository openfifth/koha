package Koha::Item::Availability::Hold;

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

use C4::Context;
use Koha::Policy::Biblio::AgeRestriction;
use Koha::Policy::Holds;
use Koha::Patron::Availability::Hold;
use Koha::Result::Availability;

=head1 NAME

Koha::Item::Availability::Hold - Item-level hold availability checks

=head1 SYNOPSIS

    my $availability = Koha::Item::Availability::Hold->check({
        item             => $item,
        patron           => $patron,
        pickup_library   => $pickup_library,   # Koha::Library, optional
        no_short_circuit => 1,                 # optional
    });

    if ( $availability->available ) { ... }

=head1 DESCRIPTION

Validates whether a specific item can have a hold placed on it by a given
patron. Returns a L<Koha::Result::Availability> object.

=head1 API

=head2 Class methods

=head3 check

    my $availability = Koha::Item::Availability::Hold->check({
        item             => $item,
        patron           => $patron,
        pickup_library   => $pickup_library,
        no_short_circuit => 0,
    });

Parameters (hashref):

=over 4

=item item - Koha::Item object (required)

=item patron - Koha::Patron object (required)

=item pickup_library - Koha::Library object for pickup location validation (optional)

=item no_short_circuit - collect all blockers instead of returning on first (optional)

=item skip_patron_checks - skip patron-level checks (optional, for biblio-level loop)

=back

=cut

sub check {
    my ( $class, $params ) = @_;

    my $item             = $params->{item};
    my $patron           = $params->{patron};
    my $pickup_library   = $params->{pickup_library};
    my $no_short_circuit = $params->{no_short_circuit} // 0;
    my $overrides        = $params->{overrides}        // {};

    my $result = Koha::Result::Availability->new();

    # TODO: Reorder checks so cheap (column lookups) run before expensive (DB queries).
    # Current order preserves legacy CanItemBeReserved behavior for backward compat.
    # Ideal order: syspref gates → column checks (damaged, item fields) →
    # rule lookups → DB count queries → transfer/pickup validation (most expensive).

    # FIXME: The reservesallowed == 0 check is duplicated: once here (item-level, as
    # policy gate) and once in Koha::Patron::Availability::Hold (as count check).
    # The item-level copy exists because skip_patron_checks must not skip the "not
    # allowed" policy. Consider a dedicated 'skip_count_checks' flag instead.

    # IndependentBranches check
    if ( C4::Context->preference('IndependentBranches')
        and !C4::Context->preference('canreservefromotherbranches') )
    {
        if ( $item->homebranch ne $patron->branchcode ) {
            $result->add_blocker( cannot_reserve_from_other_branches => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Damaged item check
    unless ( $overrides->{damaged} ) {
        if ( $item->damaged && !C4::Context->preference('AllowHoldsOnDamagedItems') ) {
            $result->add_blocker( damaged => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Age restriction
    # FIXME: This loads $item->biblio — consider moving after cheaper column checks
    unless ( $overrides->{age_restricted} ) {
        my $age_check = Koha::Policy::Biblio::AgeRestriction->check( $item->biblio, $patron );
        if ( !$age_check ) {
            $result->add_blocker( age_restricted => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Already has hold on this item
    # FIXME: DB query — could be deferred after rule lookups (which are cached)
    if ( $patron->holds->search( { itemnumber => $item->itemnumber } )->count ) {
        $result->add_blocker( item_already_on_hold => 1 );
        return $result unless $no_short_circuit;
    }

    # Patron already has this biblio checked out
    unless ( $overrides->{already_possession} ) {
        if ( !C4::Context->preference('AllowHoldsOnPatronsPossessions')
            && $patron->checkouts->search( { itemnumber => $item->itemnumber } )->count )
        {
            $result->add_blocker( already_possession => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Active recall on this item
    if ( $patron->recalls->filter_by_current->search( { item_id => $item->itemnumber } )->count ) {
        $result->add_blocker( recall => 1 );
        return $result unless $no_short_circuit;
    }

    # Circ rules: hold policy
    my $reserves_control_branch = Koha::Policy::Holds->holds_control_library( $item, $patron );

    require Koha::CirculationRules;
    my $branchitemrule = Koha::CirculationRules->get_effective_rules(
        {
            branchcode => $reserves_control_branch,
            itemtype   => $item->effective_itemtype,
            rules      => [ 'holdallowed', 'hold_fulfillment_policy' ]
        }
    );
    $branchitemrule->{holdallowed}             //= 'from_any_library';
    $branchitemrule->{hold_fulfillment_policy} //= 'any';

    # reservesallowed == 0 means holds are not allowed (policy, not count)
    my $reservesallowed_rule = Koha::CirculationRules->get_effective_rules(
        {
            categorycode => $patron->categorycode,
            branchcode   => $reserves_control_branch,
            itemtype     => $item->effective_itemtype,
            rules        => ['reservesallowed']
        }
    );
    if (   defined $reservesallowed_rule->{reservesallowed}
        && $reservesallowed_rule->{reservesallowed} ne ''
        && $reservesallowed_rule->{reservesallowed} == 0 )
    {
        $result->add_blocker( no_reserves_allowed => 1 );
        return $result unless $no_short_circuit;
    }

    unless ( $overrides->{not_reservable} ) {
        if ( $branchitemrule->{holdallowed} eq 'not_allowed' ) {
            $result->add_blocker( not_reservable => 1 );
            return $result unless $no_short_circuit;
        }

        if (   $branchitemrule->{holdallowed} eq 'from_home_library'
            && $patron->branchcode ne $item->homebranch )
        {
            $result->add_blocker( cannot_reserve_from_other_branches => 1 );
            return $result unless $no_short_circuit;
        }

        if ( $branchitemrule->{holdallowed} eq 'from_local_hold_group' ) {
            unless ( $item->home_branch->validate_hold_sibling( { branchcode => $patron->branchcode } ) ) {
                $result->add_blocker( branch_not_in_hold_group => 1 );
                return $result unless $no_short_circuit;
            }
        }
    }

    # Patron-level checks (counts) — run after item checks
    unless ( $params->{skip_patron_checks} ) {
        my $patron_result = Koha::Patron::Availability::Hold->check(
            {
                patron           => $patron,
                item_type_id     => $item->effective_itemtype,
                library_id       => $reserves_control_branch,
                biblio_id        => $item->biblionumber,
                no_short_circuit => $no_short_circuit,
                overrides        => $overrides,
            }
        );

        # Merge patron blockers into our result
        for my $key ( keys %{ $patron_result->blockers } ) {
            $result->add_blocker( $key => $patron_result->blockers->{$key} );
        }
        return $result if !$result->available && !$no_short_circuit;
    }

    # Pickup location validation (last, matching legacy order)
    # TODO: can_be_transferred is the most expensive check (queries transfer limits).
    # Keeping it last is correct for short-circuit mode. For no_short_circuit mode,
    # consider lazy evaluation or caching transfer limit results.
    if ($pickup_library) {
        if ( !$pickup_library->pickup_location ) {
            $result->add_blocker( library_not_pickup_location => 1 );
            return $result unless $no_short_circuit;
        } elsif ( !$item->can_be_transferred( { to => $pickup_library } ) ) {
            $result->add_blocker( cannot_be_transferred => 1 );
            return $result unless $no_short_circuit;
        }

        if ( $branchitemrule->{hold_fulfillment_policy} eq 'holdgroup'
            && !$pickup_library->validate_hold_sibling( { branchcode => $item->homebranch } ) )
        {
            $result->add_blocker( pickup_not_in_hold_group => 1 );
            return $result unless $no_short_circuit;
        }

        if ( $branchitemrule->{hold_fulfillment_policy} eq 'patrongroup'
            && !$pickup_library->validate_hold_sibling( { branchcode => $patron->branchcode } ) )
        {
            $result->add_blocker( pickup_not_in_hold_group => 1 );
            return $result unless $no_short_circuit;
        }
    }

    return $result;
}

1;
