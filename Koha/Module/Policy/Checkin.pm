package Koha::Module::Policy::Checkin;

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
use base 'Koha::Module::Policy';

use C4::Context;

=head1 NAME

Koha::Module::Policy::Checkin - Policy contract for the checkin module

=head1 SYNOPSIS

    my $policy = Koha::Module::Policy::Checkin->new(
        {
            user    => $patron,
            library => $branchcode,
        }
    );

    # As JWT for the X-Koha-Module-Policy response header
    my $jwt = $policy->as_jwt;

    # As hashref for inspection/testing
    my $caps = $policy->to_hashref;

=head1 DESCRIPTION

Defines what the checkin module UI should offer to the current user at the
current library. This is the intersection of system preferences, user
permissions, and library context.

The client decodes the JWT payload and uses it to show/hide controls.
The server still enforces every action - this is informational, not an
authorization token.

=head2 Policy keys

=over 4

=item B<exempt_fine> - User can exempt fines on return (pref + permission)

=item B<specify_return_date> - Return date override field available

=item B<dropbox_mode> - Book drop mode available

=item B<forgive_hold_fees> - Can forgive manual hold expiration charges

=item B<audio_alerts> - Audio alerts enabled

=item B<recalls_enabled> - Recall feature active

=item B<holds_auto_fill> - Holds automatically filled on checkin

=item B<holds_auto_fill_print_slip> - Auto-print slip when hold auto-filled

=item B<transfers_block> - Transfer modals are blocking (must be acted on)

=item B<auto_confirm_transfer> - Transfers auto-confirmed without modal

=item B<confirm_item_parts> - Multi-part items require confirmation

=item B<show_all_checkins> - Display items scanned but not actually returned

=item B<max_returned_items> - Max items to display in the checked-in table

=item B<catalog_concerns> - "Report a concern" feature available

=item B<fine_notify_at_checkin> - Show patron balance after checkin

=item B<waiting_notify_at_checkin> - Show waiting holds after checkin

=item B<display_hold_groups> - Show hold group info in hold modals

=item B<block_return_withdrawn> - Withdrawn items are blocked (informational)

=item B<block_return_lost> - Lost items are blocked (informational)

=back

=head1 API

=head2 Methods

=head3 _build_hashref

Builds the policy hashref for the checkin module.

=cut

sub _build_hashref {
    my ($self) = @_;

    my $user = $self->user;

    # Fines mode is production AND user has writeoff permission
    my $fines_active =
        ( C4::Context->preference('finesMode') && C4::Context->preference('finesMode') eq 'production' ) ? 1 : 0;

    my $can_writeoff = $user->has_permission( { updatecharges => 'writeoff' } ) ? 1 : 0;

    return {
        # Fines & charges
        exempt_fine            => ( $fines_active && $can_writeoff )                                            ? 1 : 0,
        fine_notify_at_checkin => C4::Context->preference('FineNotifyAtCheckin')                                ? 1 : 0,
        forgive_hold_fees => ( C4::Context->preference('ExpireReservesMaxPickUpDelayCharge') && $can_writeoff ) ? 1 : 0,

        # Return date
        specify_return_date => C4::Context->preference('SpecifyReturnDate') ? 1 : 0,
        dropbox_mode        => 1,                                                      # always available as a UI option

        # Confirmations
        confirm_item_parts => C4::Context->preference('CircConfirmItemParts') ? 1 : 0,

        # Holds
        holds_auto_fill            => C4::Context->preference('HoldsAutoFill')          ? 1 : 0,
        holds_auto_fill_print_slip => C4::Context->preference('HoldsAutoFillPrintSlip') ? 1 : 0,
        waiting_notify_at_checkin  => C4::Context->preference('WaitingNotifyAtCheckin') ? 1 : 0,
        display_hold_groups        => C4::Context->preference('DisplayAddHoldGroups')   ? 1 : 0,

        # Recalls
        recalls_enabled => C4::Context->preference('UseRecalls') ? 1 : 0,

        # Transfers
        transfers_block       => C4::Context->preference('TransfersBlockCirc')       ? 1 : 0,
        auto_confirm_transfer => C4::Context->preference('AutomaticConfirmTransfer') ? 1 : 0,

        # Display
        show_all_checkins  => C4::Context->preference('ShowAllCheckins') ? 1 : 0,
        max_returned_items => ( C4::Context->preference('numReturnedItemsToShow') || 8 ),
        audio_alerts       => C4::Context->preference('AudioAlerts')     ? 1 : 0,
        catalog_concerns   => C4::Context->preference('CatalogConcerns') ? 1 : 0,

        # Blockers (informational - the API enforces these, but the client
        # can use them to show warnings or adjust messaging)
        block_return_withdrawn => C4::Context->preference('BlockReturnOfWithdrawnItems') ? 1 : 0,
        block_return_lost      => C4::Context->preference('BlockReturnOfLostItems')      ? 1 : 0,
    };
}

=head1 NOTES

=head2 Staleness and re-evaluation

The JWT is generated fresh on every API response. If a preference or
permission changes mid-session, the very next response will carry the
updated policy. The client compares with its current state and updates
the UI reactively.

This replaces the need for a dedicated GET /config endpoint and solves
the stale-config problem inherent in such patterns.

=head2 Initial hydration

For the initial page load (before any API call), the thin .tt wrapper
can inject the policy JWT (or its decoded payload) as a JS variable.
This gives the Vue app immediate access to capabilities without a
bootstrapping request. The same Koha::Module::Policy::Checkin class
is used in both contexts.

=head2 Permissions in the template shell

The .tt shell may also need to inject user permissions for the page
chrome (header, sidebar navigation). This is a separate concern from
the module policy - the policy governs the module's functional area,
while the template chrome uses CAN_user_* flags for navigation visibility.
Over time, the chrome itself can become a Vue component reading from
the policy or a broader session contract.

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
