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
use Koha::Cache::Memory::Lite;
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

=item skip_patron_checks - skip patron-level checks entirely (eligibility and
counts), AND skip the item_already_on_hold check (optional). This matches the
legacy C<ignore_hold_counts> semantics used by callers checking whether an
item can fill a hold the patron already placed on it - where the patron's own
existing hold on this exact item must not block the check.

=item skip_patron_count_checks - skip only the chained
L<Koha::Patron::Availability::Hold> call (eligibility + counts), without
touching the item_already_on_hold check above (optional). Used by
L<Koha::Biblio::Availability::Hold> when it has already run patron-level
checks once before looping items - item_already_on_hold is still genuinely
item-specific and must still run per item.

=item skip_eligibility_checks - skip only the patron's no-item-context
eligibility gates (expired, debt_limit, bad_address, card_lost, restricted,
hold_limit), while still running the item/rule-context count checks
(optional, for per-item display loops on a page that already shows patron
eligibility once, separately)

=item cache_counts - memoize the item/rule-context hold-count queries for the
request lifetime (optional, default off). See
L<Koha::Patron::Availability::Hold/check> - only safe for read-only per-item
display loops that won't place a hold between calls.

=item cache_transfers - memoize can_be_transferred for the request lifetime,
keyed on the (holdingbranch, pickup branch, itemtype-or-ccode) combination
that determines it (optional, default off). Off by default for the same
reason as cache_counts: a caller that creates/deletes transfer limits
between calls (as the test suite does) must see a fresh result.

=item held_itemnumbers - hashref of C<< { itemnumber => 1 } >> for every item
the patron currently holds (optional). When supplied, the
item_already_on_hold check does an in-memory lookup instead of a fresh
C<< $patron->holds->search >> query. Used by L<Koha::Biblio::Availability::Hold>
to compute this once per patron rather than once per item.

=item checked_out_itemnumbers - same shape and purpose as
C<held_itemnumbers>, for the already_possession check (optional).

=item recalled_itemnumbers - same shape and purpose as C<held_itemnumbers>,
for the recall check (optional).

=item age_restriction_ok - boolean, the precomputed result of
C<< Koha::Policy::Biblio::AgeRestriction->check($item->biblio, $patron) >>
for the item's biblio (optional; true means the patron is NOT age
restricted, matching that method's own return convention). When defined,
skips that check (and the C<< $item->biblio >> fetch it requires) entirely -
safe whenever every item being checked belongs to the same biblio, since age
restriction only depends on the biblio and patron, never the item.

=back

=cut

sub check {
    my ( $class, $params ) = @_;

    my $item                     = $params->{item};
    my $patron                   = $params->{patron};
    my $pickup_library           = $params->{pickup_library};
    my $no_short_circuit         = $params->{no_short_circuit}         // 0;
    my $overrides                = $params->{overrides}                // {};
    my $skip_patron_checks       = $params->{skip_patron_checks}       // 0;
    my $skip_patron_count_checks = $params->{skip_patron_count_checks} // 0;
    my $skip_eligibility_checks  = $params->{skip_eligibility_checks}  // 0;
    my $cache_counts             = $params->{cache_counts}             // 0;
    my $cache_transfers          = $params->{cache_transfers}          // 0;
    my $held_itemnumbers         = $params->{held_itemnumbers};
    my $checked_out_itemnumbers  = $params->{checked_out_itemnumbers};
    my $recalled_itemnumbers     = $params->{recalled_itemnumbers};
    my $age_restriction_ok       = $params->{age_restriction_ok};

    my $result = Koha::Result::Availability->new();

    # TODO: Reorder checks so cheap (column lookups) run before expensive (DB queries).
    # Current order preserves legacy CanItemBeReserved behavior for backward compat.
    # Ideal order: syspref gates → column checks (damaged, item fields) →
    # rule lookups → DB count queries → transfer/pickup validation (most expensive).

    # FIXME: The reservesallowed == 0 check is duplicated: once here (item-level, as
    # policy gate) and once in Koha::Patron::Availability::Hold (as count check).
    # The item-level copy exists because skip_patron_count_checks/skip_patron_checks
    # must not skip the "not allowed" policy gate itself.

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
    # age_restriction_ok, when supplied, is precomputed once per biblio by
    # the caller (age restriction never varies by item) - avoids both the
    # check and the $item->biblio fetch it requires.
    unless ( $overrides->{age_restricted} ) {
        my $age_check =
            defined $age_restriction_ok
            ? $age_restriction_ok
            : Koha::Policy::Biblio::AgeRestriction->check( $item->biblio, $patron );
        if ( !$age_check ) {
            $result->add_blocker( age_restricted => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Already has hold on this item
    # Skipped when skip_patron_checks is set (legacy ignore_hold_counts
    # semantics): callers use that flag specifically to check whether an item
    # can fill a hold the patron already placed on it, where this check would
    # otherwise always (incorrectly) block.
    unless ($skip_patron_checks) {
        my $already_on_hold =
            $held_itemnumbers
            ? exists $held_itemnumbers->{ $item->itemnumber }
            : $patron->holds->search( { itemnumber => $item->itemnumber } )->count;
        if ($already_on_hold) {
            $result->add_blocker( item_already_on_hold => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Patron already has this biblio checked out
    unless ( $overrides->{already_possession} ) {
        if ( !C4::Context->preference('AllowHoldsOnPatronsPossessions') ) {
            my $in_possession =
                $checked_out_itemnumbers
                ? exists $checked_out_itemnumbers->{ $item->itemnumber }
                : $patron->checkouts->search( { itemnumber => $item->itemnumber } )->count;
            if ($in_possession) {
                $result->add_blocker( already_possession => 1 );
                return $result unless $no_short_circuit;
            }
        }
    }

    # Active recall on this item
    my $recalled =
        $recalled_itemnumbers
        ? exists $recalled_itemnumbers->{ $item->itemnumber }
        : $patron->recalls->filter_by_current->search( { item_id => $item->itemnumber } )->count;
    if ($recalled) {
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
    unless ( $skip_patron_checks || $skip_patron_count_checks ) {

        # Retrieve the rule object to get the itemtype the rule was defined for.
        # A rule with itemtype=undef (wildcard) means all holds count against it;
        # a specific itemtype means only holds for that itemtype count.
        #
        # Fetched here rather than with the rule values above because it is only
        # ever used to scope the hold counting below, and get_effective_rule is
        # not memoized the way get_effective_rule_value is. A caller that skips
        # the count checks - notably the per-item loop in
        # Koha::Biblio::Availability::Hold - would otherwise pay for this query
        # once per item and discard the answer.
        my $reservesallowed_rule_obj = Koha::CirculationRules->get_effective_rule(
            {
                categorycode => $patron->categorycode,
                branchcode   => $reserves_control_branch,
                itemtype     => $item->effective_itemtype,
                rule_name    => 'reservesallowed',
            }
        );
        my $rule_itemtype = $reservesallowed_rule_obj ? $reservesallowed_rule_obj->itemtype : undef;

        my $patron_result = Koha::Patron::Availability::Hold->check(
            {
                patron           => $patron,
                item_type_id     => $item->effective_itemtype,
                library_id       => $reserves_control_branch,
                biblio_id        => $item->biblionumber,
                rule_itemtype    => $rule_itemtype,
                no_short_circuit => $no_short_circuit,
                overrides        => $overrides,
                skip_eligibility => $skip_eligibility_checks,
                cache_counts     => $cache_counts,
            }
        );

        # Merge patron blockers into our result
        for my $key ( keys %{ $patron_result->blockers } ) {
            $result->add_blocker( $key => $patron_result->blockers->{$key} );
        }
        return $result if !$result->available && !$no_short_circuit;
    }

    # Pickup location validation (last, matching legacy order)
    # can_be_transferred is memoized per request, keyed on the (holdingbranch,
    # pickup branch, itemtype-or-ccode) combination that actually determines
    # its result - multiple items on the same record commonly share a
    # homebranch, so this avoids re-querying transfer limits for each one.
    if ($pickup_library) {
        if ( !$pickup_library->pickup_location ) {
            $result->add_blocker( library_not_pickup_location => 1 );
            return $result unless $no_short_circuit;
        } else {
            my $can_transfer;
            my $cache_key;
            if ($cache_transfers) {
                my $limittype = C4::Context->preference('BranchTransferLimitsType') // '';
                $cache_key = sprintf(
                    "Hold_CanBeTransferred:%s:%s:%s:%s", $item->holdingbranch, $pickup_library->branchcode,
                    $limittype, $limittype eq 'itemtype' ? $item->effective_itemtype : $item->ccode // ''
                );
                $can_transfer = Koha::Cache::Memory::Lite->get_instance()->get_from_cache($cache_key);
            }
            unless ( defined $can_transfer ) {
                $can_transfer = $item->can_be_transferred( { to => $pickup_library } ) ? 1 : 0;
                Koha::Cache::Memory::Lite->get_instance()->set_in_cache( $cache_key, $can_transfer )
                    if $cache_transfers;
            }
            unless ($can_transfer) {
                $result->add_blocker( cannot_be_transferred => 1 );
                return $result unless $no_short_circuit;
            }
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
