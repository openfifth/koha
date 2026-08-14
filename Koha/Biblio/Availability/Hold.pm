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

use C4::Context;
use C4::Items qw( get_hostitemnumbers_of );
use Koha::Items;
use Koha::Item::Availability::Hold;
use Koha::Policy::Biblio::AgeRestriction;
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

Patron/biblio context that doesn't vary by item (currently-held,
checked-out, and recalled itemnumbers, and biblio-level age restriction) is
fetched once before the item loop and passed into each
L<Koha::Item::Availability::Hold> call, so the per-item check does an
in-memory lookup instead of a fresh query - the item search itself is not
yet prefetch-joined (homebranch/transfer-limit lookups still query
per-item), see bug 43124.

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

=item items - arrayref of pre-fetched L<Koha::Item> objects to check
(optional). When supplied, skips this class's own item/host-item fetch
entirely - for callers that already have the biblio's item list in hand and
want to reuse it across multiple C<check()> calls (e.g. checking several
patrons for the same club hold), rather than re-fetching per call.

=item summarise_items - check every item rather than stopping at the first
holdable one, and record the verdict for each in
C<< context->{item_results} >> as
C<< [ { itemnumber => $id, available => 0|1, blockers => {...} } ] >>
(optional, default off).

Off by default because the whole point of the item loop is to stop as soon as
one item can fill the hold - a caller that only needs a yes/no answer must not
pay for the rest of the record. Turn it on for a caller that reports how many
items are holdable, e.g. C<GET /biblios/{biblio_id}/holdability>.

The extra items cost no extra queries beyond the per-item checks themselves:
the patron/biblio context is still fetched once before the loop, exactly as it
is when this option is off.

C<< context->{available_item} >> still holds the first holdable item, and the
C<no_item_available> blocker is still set only when no item is holdable.

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
    my $summarise_items  = $params->{summarise_items}  // 0;

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
    # TODO: homebranch/hold-group validation and can_be_transferred still
    # query per unique branch combination (memoized in
    # Koha::Item::Availability::Hold, but not prefetched here via JOIN).
    my @items = $params->{items} ? @{ $params->{items} } : $class->fetch_items( $biblio, $item_type_id );

    # Pre-warm patron/biblio context that's constant across every item on
    # this record, so Koha::Item::Availability::Hold->check does an in-memory
    # lookup per item instead of a fresh query - the whole point of this
    # class existing rather than callers looping CanItemBeReserved directly.
    my %held_itemnumbers =
        map { $_ => 1 } $patron->holds->search( { itemnumber => { '!=' => undef } } )->get_column('itemnumber');

    my %checked_out_itemnumbers;
    unless ( C4::Context->preference('AllowHoldsOnPatronsPossessions') ) {
        %checked_out_itemnumbers = map { $_ => 1 } $patron->checkouts->get_column('itemnumber');
    }

    my %recalled_itemnumbers =
        map { $_ => 1 } $patron->recalls->filter_by_current->get_column('item_id');

    my $age_restriction_ok = Koha::Policy::Biblio::AgeRestriction->check( $biblio, $patron );

    my @item_failures;
    my @item_results;
    my $available_item;

    for my $item (@items) {
        my $item_result = Koha::Item::Availability::Hold->check(
            {
                item                     => $item,
                patron                   => $patron,
                pickup_library           => $pickup_library,
                overrides                => $overrides,
                skip_patron_count_checks => 1,
                held_itemnumbers         => \%held_itemnumbers,
                checked_out_itemnumbers  => \%checked_out_itemnumbers,
                recalled_itemnumbers     => \%recalled_itemnumbers,
                age_restriction_ok       => $age_restriction_ok,
                cache_transfers          => 1,
            }
        );

        if ( $item_result->available ) {

            # Keep the first holdable item, so the context is the same whether
            # or not the loop runs on.
            unless ($available_item) {
                $available_item = $item;
                $result->set_context( available_item => $item );
            }

            return $result unless $summarise_items;
        } else {
            push @item_failures, {
                itemnumber => $item->itemnumber,
                blockers   => $item_result->blockers,
            };
        }

        push @item_results, {
            itemnumber => $item->itemnumber,
            available  => $item_result->available ? 1 : 0,
            blockers   => $item_result->blockers,
            }
            if $summarise_items;
    }

    # No item available
    unless ($available_item) {
        $result->add_blocker( no_item_available => 1 ) unless @items == 0;
        $result->add_blocker( no_items          => 1 ) if @items == 0;
    }
    $result->set_context( item_failures => \@item_failures ) if @item_failures;
    $result->set_context( item_results  => \@item_results )  if $summarise_items;

    return $result;
}

=head3 fetch_items

    my @items = Koha::Biblio::Availability::Hold->fetch_items( $biblio, $item_type_id );

Fetches the biblio's items, including items linked via host records
(analytics), optionally filtered to a single itemtype. This is the same
list C<check()> builds internally when no C<items> param is given - exposed
so a caller checking the same biblio against several patrons (e.g. club
holds) can fetch once and pass the result via C<check()>'s C<items> param to
every call instead of repeating the fetch per patron.

=cut

sub fetch_items {
    my ( $class, $biblio, $item_type_id ) = @_;

    my $items_search = {};
    $items_search->{itype} = $item_type_id if $item_type_id;

    my @items = $biblio->items->search($items_search)->as_list;

    my @hostitemnumbers = C4::Items::get_hostitemnumbers_of( $biblio->biblionumber );
    if (@hostitemnumbers) {
        my @host_items = Koha::Items->search( { itemnumber => { -in => \@hostitemnumbers }, %$items_search } )->as_list;
        push @items, @host_items;
    }

    return @items;
}

1;
