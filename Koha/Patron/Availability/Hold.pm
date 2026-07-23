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
use Koha::Cache::Memory::Lite;
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

=item skip_eligibility - skip the no-item-context gates (expired, debt_limit,
bad_address, card_lost, restricted, hold_limit) and go straight to the
item/rule-context count checks below (optional). Use this when the caller has
already surfaced patron eligibility separately (e.g. a per-item display loop
on a page that shows a patron-level warning banner once) and would otherwise
re-run those checks once per item for no benefit.

=item cache_counts - memoize the item/rule-context hold-count queries
(holds_per_record, holds_per_day, reservesallowed, max_holds) via
C<Koha::Cache::Memory::Lite> for the lifetime of the request (optional,
default off). Only safe when the caller won't place a hold between calls for
the same patron within the same request (e.g. a read-only per-item display
loop) - off by default so callers that do (including the test suite) always
see a fresh count.

=back

The C<debt_limit> and C<hold_limit> blockers carry a hashref payload
(C<{ total_outstanding =E<gt> $n, max_outstanding =E<gt> $n }> and
C<{ total_holds =E<gt> $n, max_holds =E<gt> $n }> respectively) rather than
a bare scalar, so callers (e.g. C<Koha::Patron-E<gt>can_place_holds>) can
report the relevant totals without a second query.

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
    my $skip_eligibility = $params->{skip_eligibility} // 0;
    my $cache_counts     = $params->{cache_counts}     // 0;

    my $result = Koha::Result::Availability->new();

    # --- Patron eligibility (no item context needed) ---
    # TODO: These checks are cheap (column lookups). Good candidates to run first
    # in any caller that chains patron + item checks.
    unless ($skip_eligibility) {

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
                    $result->add_blocker(
                        debt_limit => { total_outstanding => $balance, max_outstanding => $max_outstanding } );
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
        unless ( $overrides->{hold_limit} ) {
            my $max_holds = C4::Context->preference("maxreserves");
            if ($max_holds) {
                my $holds_count = $patron->holds->count;
                if ( $holds_count >= $max_holds ) {
                    $result->add_blocker( hold_limit => { total_holds => $holds_count, max_holds => $max_holds } );
                    return $result unless $no_short_circuit;
                }
            }
        }
    }

    # --- Count checks (need rule context) ---
    # These are cached per (patron, rule scope) via Koha::Cache::Memory::Lite
    # below, since the same combination repeats across every item of a
    # multi-item biblio within a request.
    return $result unless $library_id;

    require Koha::CirculationRules;

    my $memory_cache   = Koha::Cache::Memory::Lite->get_instance();
    my $borrowernumber = $patron->borrowernumber;

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
        my $record_holds;
        my $cache_key = "Hold_HoldsPerRecordCount:$borrowernumber:$biblio_id";
        $record_holds = $memory_cache->get_from_cache($cache_key) if $cache_counts;
        unless ( defined $record_holds ) {
            $record_holds = $patron->holds->search( { biblionumber => $biblio_id } )->count;
            $memory_cache->set_in_cache( $cache_key, $record_holds ) if $cache_counts;
        }
        if ( $record_holds >= $holds_per_record ) {
            $result->add_blocker( too_many_holds_for_this_record => $holds_per_record );
            return $result unless $no_short_circuit;
        }
    }

    # holds_per_day
    if ( defined $holds_per_day && $holds_per_day ne '' ) {
        my $today = dt_from_string()->date;
        my $today_holds;
        my $cache_key = "Hold_HoldsPerDayCount:$borrowernumber:$today";
        $today_holds = $memory_cache->get_from_cache($cache_key) if $cache_counts;
        unless ( defined $today_holds ) {
            $today_holds = $patron->holds->count_holds( { reservedate => $today } );
            $memory_cache->set_in_cache( $cache_key, $today_holds ) if $cache_counts;
        }
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

        my $total;
        my $cache_key = sprintf(
            "Hold_ReservesAllowedCount:%s:%s:%s:%s", $borrowernumber, $library_id,
            $rule_itemtype // '_ANY_', $controlbranch_pref
        );
        $total = $memory_cache->get_from_cache($cache_key) if $cache_counts;
        unless ( defined $total ) {
            $total = $patron->holds->count_holds( $search_params, $search_attrs );
            $memory_cache->set_in_cache( $cache_key, $total ) if $cache_counts;
        }
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
        my $total;
        my $cache_key = "Hold_TotalHoldsCount:$borrowernumber";
        $total = $memory_cache->get_from_cache($cache_key) if $cache_counts;
        unless ( defined $total ) {
            $total = $patron->holds->count_holds;
            $memory_cache->set_in_cache( $cache_key, $total ) if $cache_counts;
        }
        if ( $total >= $max_holds_rule->rule_value ) {
            $result->add_blocker( too_many_reserves => $max_holds_rule->rule_value );
            return $result unless $no_short_circuit;
        }
    }

    return $result;
}

1;
