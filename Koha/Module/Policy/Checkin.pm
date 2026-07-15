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

In addition to the keys listed below, the policy hashref includes the
C<global> namespace inherited from L<Koha::Module::Policy> (e.g.,
C<audio_alerts>, C<catalog_concerns>). See the base class documentation
for the full list of global keys.

=head2 Policy keys

=over 4

=item B<exempt_fine> - User can exempt fines on return (pref + permission)

=item B<specify_return_date> - Return date override field available

=item B<dropbox_mode> - Book drop mode available

=item B<forgive_hold_fees> - Can forgive manual hold expiration charges

=item B<recalls_enabled> - Recall feature active

=item B<holds_auto_fill> - Holds automatically filled on checkin

=item B<holds_auto_fill_print_slip> - Auto-print slip when hold auto-filled

=item B<transfers_block> - Transfer modals are blocking (must be acted on)

=item B<auto_confirm_transfer> - Transfers auto-confirmed without modal

=item B<confirm_item_parts> - Multi-part items require confirmation

=item B<show_all_checkins> - Display items scanned but not actually returned

=item B<max_returned_items> - Max items to display in the checked-in table

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

        # Blockers (informational - the API enforces these, but the client
        # can use them to show warnings or adjust messaging)
        block_return_withdrawn => C4::Context->preference('BlockReturnOfWithdrawnItems') ? 1 : 0,
        block_return_lost      => C4::Context->preference('BlockReturnOfLostItems')      ? 1 : 0,
    };
}

=head1 NOTES

=head2 Policy delivery

The policy is delivered to the client in two ways:

=over 4

=item * B<Page load> - The .tt template injects the policy hashref as a
JSON window global. The Vue app reads it on mount.

=item * B<API response header> - When the controller rejects a request
because a client-asserted capability is no longer valid (e.g.,
C<exempt_fine> sent but permission revoked), it attaches the updated
policy as a JWT in the C<X-Koha-Module-Policy> response header. The
client decodes the payload and updates its state reactively.

=back

=head2 Permissions in the template shell

The .tt shell injects C<CAN_user_*> flags for page chrome (header,
sidebar navigation). This is separate from the module policy which
governs the module's functional capabilities.

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
