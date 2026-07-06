package Koha::Patron::Availability::Hold;

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
use Koha::DateUtils qw( dt_from_string );
use Koha::Result::Availability;

=head1 NAME

Koha::Patron::Availability::Hold - Patron-level hold availability checks

=head1 SYNOPSIS

    # Eligibility only (no item context)
    my $availability = Koha::Patron::Availability::Hold->check({
        patron => $patron,
    });

    # Eligibility + count checks (with rule context)
    my $availability = Koha::Patron::Availability::Hold->check({
        patron       => $patron,
        item_type_id => $itemtype,
        library_id   => $branchcode,
        biblio_id    => $biblionumber,
    });

=head1 DESCRIPTION

Validates patron-level hold eligibility and count limits.
Returns L<Koha::Result::Availability>.

When C<item_type_id> and C<library_id> are provided, count-based checks
are performed. Without them, only eligibility checks run.

=head1 API

=head2 Class methods

=head3 check

Parameters (hashref):

=over 4

=item patron - Koha::Patron object (required)

=item item_type_id - itemtype for rule resolution (optional)

=item library_id - branchcode for rule resolution (optional)

=item biblio_id - biblionumber for per-record limit (optional)

=item rule_itemtype - itemtype from the matching reservesallowed rule (optional, for scoped counting)

=item no_short_circuit - collect all blockers (optional)

=back

=cut

sub check {
    my ( $class, $params ) = @_;

    my $patron           = $params->{patron};
    my $item_type_id     = $params->{item_type_id};
    my $library_id       = $params->{library_id};
    my $biblio_id        = $params->{biblio_id};
    my $rule_itemtype    = $params->{rule_itemtype};
    my $no_short_circuit = $params->{no_short_circuit} // 0;
    my $overrides        = $params->{overrides}        // {};

    my $result = Koha::Result::Availability->new();

    # --- Patron eligibility (no item context needed) ---
    # TODO: These checks are cheap (column lookups). Good candidates to run first
    # in any caller that chains patron + item checks.

    # Expired
    unless ( $overrides->{expired} ) {
        if ( $patron->is_expired && $patron->category->effective_BlockExpiredPatronOpacActions_contains('hold') ) {
            $result->add_blocker( expired => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Debt
    unless ( $overrides->{debt_limit} ) {
        my $max_outstanding = C4::Context->preference("maxoutstanding");
        if ($max_outstanding) {
            my $balance = $patron->account->balance;
            if ( $balance && $balance > $max_outstanding ) {
                $result->add_blocker( debt_limit => $balance );
                return $result unless $no_short_circuit;
            }
        }
    }

    # Bad address
    unless ( $overrides->{bad_address} ) {
        if ( $patron->gonenoaddress ) {
            $result->add_blocker( bad_address => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Card lost
    unless ( $overrides->{card_lost} ) {
        if ( $patron->lost ) {
            $result->add_blocker( card_lost => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Restricted
    unless ( $overrides->{restricted} ) {
        if ( $patron->is_debarred ) {
            $result->add_blocker( restricted => 1 );
            return $result unless $no_short_circuit;
        }
    }

    # Global hold limit (maxreserves syspref)
    # FIXME: This does a DB count ($patron->holds->count). Could be deferred after
    # the cheaper eligibility checks above, but before the rule-based counts below.
    unless ( $overrides->{hold_limit} ) {
        my $max_holds = C4::Context->preference("maxreserves");
        if ($max_holds) {
            my $holds_count = $patron->holds->count;
            if ( $holds_count >= $max_holds ) {
                $result->add_blocker( hold_limit => $max_holds );
                return $result unless $no_short_circuit;
            }
        }
    }

    # --- Count checks (need rule context) ---
    # FIXME: Multiple $patron->holds->count / ->search calls below. These could
    # share a single count query or be cached for the request lifetime.
    return $result unless $library_id;

    require Koha::CirculationRules;

    my $rights = Koha::CirculationRules->get_effective_rules(
        {
            categorycode => $patron->categorycode,
            itemtype     => $item_type_id,
            branchcode   => $library_id,
            rules        => [ 'reservesallowed', 'holds_per_record', 'holds_per_day' ]
        }
    );

    my $reservesallowed  = $rights->{reservesallowed};
    my $holds_per_record = $rights->{holds_per_record} // 1;
    my $holds_per_day    = $rights->{holds_per_day};

    # holds_per_record
    if ( defined $holds_per_record && $holds_per_record ne '' && $biblio_id ) {
        if ( $holds_per_record == 0 ) {
            $result->add_blocker( no_reserves_allowed => 1 );
            return $result unless $no_short_circuit;
        }
        my $record_holds = $patron->holds->search( { biblionumber => $biblio_id } )->count;
        if ( $record_holds >= $holds_per_record ) {
            $result->add_blocker( too_many_holds_for_this_record => $holds_per_record );
            return $result unless $no_short_circuit;
        }
    }

    # holds_per_day
    if ( defined $holds_per_day && $holds_per_day ne '' ) {
        my $today_holds = $patron->holds->count_holds( { reservedate => dt_from_string()->date } );
        if ( $today_holds >= $holds_per_day ) {
            $result->add_blocker( too_many_reserves_today => $holds_per_day );
            return $result unless $no_short_circuit;
        }
    }

    # reservesallowed
    if ( defined $reservesallowed && $reservesallowed ne '' ) {
        if ( $reservesallowed == 0 ) {
            $result->add_blocker( no_reserves_allowed => 1 );
            return $result unless $no_short_circuit;
        }

        # Count existing holds filtered by branch and (optionally) itemtype,
        # matching the scope of the rule that applies to this item.
        # This mirrors the old C4::Reserves logic: a per-itemtype rule only
        # counts holds for items of that itemtype.
        my $rule_itemtype = $params->{rule_itemtype};

        my $search_params = {};
        my $search_attrs  = {};

        # Filter by control branch
        my $controlbranch_pref = C4::Context->preference('ReservesControlBranch');
        if ( $controlbranch_pref eq 'ItemHomeLibrary' ) {
            $search_params->{'item.homebranch'} = [ $library_id, undef ];
            $search_attrs->{join}               = [ 'item', { biblio => 'biblioitem' } ];
        } else {

            # PatronLibrary: all patron's holds count (same as old behavior).
            # Join only needed when filtering by itemtype.
            $search_attrs->{join} = [ 'item', { biblio => 'biblioitem' } ] if defined $rule_itemtype;
        }

        # Filter by itemtype when the matching rule is itemtype-specific.
        # Join biblioitems via biblio (not via item) so biblio-level holds
        # without an item still match on the biblio's itemtype.
        if ( defined $rule_itemtype ) {
            $search_attrs->{join} //= [ 'item', { biblio => 'biblioitem' } ];
            if ( C4::Context->preference('item-level_itypes') ) {
                $search_params->{'-or'} = [
                    { 'item.itype'          => $rule_itemtype },
                    { 'biblioitem.itemtype' => $rule_itemtype },
                    { 'me.itemtype'         => $rule_itemtype },
                ];
            } else {
                $search_params->{'-or'} = [
                    { 'biblioitem.itemtype' => $rule_itemtype },
                    { 'me.itemtype'         => $rule_itemtype },
                ];
            }
        }

        my $total = $patron->holds->count_holds( $search_params, $search_attrs );
        if ( $total >= $reservesallowed ) {
            $result->add_blocker( too_many_reserves => $reservesallowed );
            return $result unless $no_short_circuit;
        }
    }

    # max_holds (per category)
    my $max_holds_rule = Koha::CirculationRules->get_effective_rule(
        {
            categorycode => $patron->categorycode,
            branchcode   => $library_id,
            rule_name    => 'max_holds',
        }
    );
    if ( $max_holds_rule && defined( $max_holds_rule->rule_value ) && $max_holds_rule->rule_value ne '' ) {
        my $total = $patron->holds->count_holds;
        if ( $total >= $max_holds_rule->rule_value ) {
            $result->add_blocker( too_many_reserves => $max_holds_rule->rule_value );
            return $result unless $no_short_circuit;
        }
    }

    return $result;
}

1;
