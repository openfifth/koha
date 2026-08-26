package Koha::Checkin;

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

use Koha::Database;
use Koha::Account::Credits;
use Koha::Account::Debits;
use Koha::DateUtils qw( dt_from_string );
use Koha::Desks;
use Koha::Holds;
use Koha::Items;
use Koha::Item::Transfers;
use Koha::Libraries;
use Koha::Old::Checkouts;
use Koha::Patron::Restrictions;
use Koha::Patrons;
use Koha::Recalls;
use Koha::Checkouts::ReturnClaims;

use C4::Reserves qw( ModReserveAffect );

use base qw(Koha::Object);

=head1 NAME

Koha::Checkin - Koha Checkin object class

=head1 API

=head2 Relations

=head3 item

    my $item = $checkin->item;

Returns the related L<Koha::Item> object.

=cut

sub item {
    my ($self) = @_;
    my $rs = $self->_result->item;
    return unless $rs;
    return Koha::Item->_new_from_dbic($rs);
}

=head3 user

    my $user = $checkin->user;

Returns the L<Koha::Patron> who processed the checkin.

=cut

sub user {
    my ($self) = @_;
    my $rs = $self->_result->user;
    return unless $rs;
    return Koha::Patron->_new_from_dbic($rs);
}

=head3 library

    my $library = $checkin->library;

Returns the related L<Koha::Library> object.

=cut

sub library {
    my ($self) = @_;
    my $rs = $self->_result->library;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 desk

    my $desk = $checkin->desk;

Returns the related L<Koha::Desk> object, if set.

=cut

sub desk {
    my ($self) = @_;
    my $rs = $self->_result->desk;
    return unless $rs;
    return Koha::Desk->_new_from_dbic($rs);
}

=head3 checkout

    my $checkout = $checkin->checkout;

Returns the related L<Koha::Old::Checkout> object, if this checkin returned a checkout.

=cut

sub checkout {
    my ($self) = @_;
    my $rs = $self->_result->checkout;
    return unless $rs;
    return Koha::Old::Checkout->_new_from_dbic($rs);
}

=head3 transfer

    my $transfer = $checkin->transfer;

Returns the related L<Koha::Item::Transfer> object, if this checkin triggered a transfer.

=cut

sub transfer {
    my ($self) = @_;
    my $rs = $self->_result->transfer;
    return unless $rs;
    return Koha::Item::Transfer->_new_from_dbic($rs);
}

=head3 hold

    my $hold = $checkin->hold;

Returns the related L<Koha::Hold> object, if this checkin filled a hold.

=cut

sub hold {
    my ($self) = @_;
    my $rs = $self->_result->hold;
    return unless $rs;
    return Koha::Hold->_new_from_dbic($rs);
}

=head3 recall

    my $recall = $checkin->recall;

Returns the related L<Koha::Recall> object, if this checkin filled a recall.

=cut

sub recall {
    my ($self) = @_;
    my $rs = $self->_result->recall;
    return unless $rs;
    return Koha::Recall->_new_from_dbic($rs);
}

=head3 restriction

    my $restriction = $checkin->restriction;

Returns the related L<Koha::Patron::Restriction> object, if this checkin triggered a restriction.

=cut

sub restriction {
    my ($self) = @_;
    my $rs = $self->_result->restriction;
    return unless $rs;
    return Koha::Patron::Restriction->_new_from_dbic($rs);
}

=head3 claim

    my $claim = $checkin->claim;

Returns the related L<Koha::Checkouts::ReturnClaim> object, if this checkin resolved a return claim.

=cut

sub claim {
    my ($self) = @_;
    my $rs = $self->_result->claim;
    return unless $rs;
    return Koha::Checkouts::ReturnClaim->_new_from_dbic($rs);
}

=head3 debits

    my $debits = $checkin->debits;

Returns the debit L<Koha::Account::Debits> linked to this checkin.

=cut

sub debits {
    my ($self) = @_;
    my $rs = $self->_result->debits;
    return Koha::Account::Debits->_new_from_dbic($rs);
}

=head3 credits

    my $credits = $checkin->credits;

Returns the credit L<Koha::Account::Credits> linked to this checkin.

=cut

sub credits {
    my ($self) = @_;
    my $rs = $self->_result->credits;
    return Koha::Account::Credits->_new_from_dbic($rs);
}

=head2 Actions

=head3 confirm_hold

    $checkin->confirm_hold;

Sets the trapped hold to waiting. If the pickup library differs from the
checkin library, creates a transfer and sets it in transit.


Returns the C<Koha::Checkin> object for chaining.

=cut

sub confirm_hold {
    my ($self) = @_;

    my $hold            = $self->hold;
    my $item            = $self->item;
    my $checkin_library = $self->library_id;
    my $pickup_library  = $hold->branchcode;

    # If pickup branch differs, a transfer is needed
    my $diff_branch = ( $checkin_library ne $pickup_library ) ? $pickup_library : undef;

    ModReserveAffect( $item->itemnumber, $hold->borrowernumber, $diff_branch, $hold->id );

    # Create transfer if needed
    if ($diff_branch) {
        my $transfer = $item->request_transfer( { to => $hold->pickup_library, reason => 'Reserve', enqueue => 1 } );
        $transfer->transit;
        $self->set( { transfer_id => $transfer->id } )->store;
    }

    return $self;
}

=head3 cancel_hold

    $checkin->cancel_hold;
    $checkin->cancel_hold( { reason => 'PATRON_REQUEST' } );

Cancels the hold associated with this checkin and clears the hold_id.


Returns the C<Koha::Checkin> object for chaining.

=cut

sub cancel_hold {
    my ( $self, $params ) = @_;

    my $hold = $self->hold;

    $hold->cancel(
        {
            cancellation_reason => $params->{reason},
            ( $params->{forgive_hold_fees} ? () : ( charge_cancel_fee => 1 ) ),
        }
    );

    $self->set( { hold_id => undef } )->store;

    return $self;
}

=head3 confirm_transfer

    $checkin->confirm_transfer;

Sets the transfer associated with this checkin in transit (populates datesent).


Returns the C<Koha::Checkin> object for chaining.

=cut

sub confirm_transfer {
    my ($self) = @_;

    my $transfer = $self->transfer;

    $transfer->transit unless $transfer->datesent;

    return $self;
}

=head3 cancel_transfer

    $checkin->cancel_transfer;

Cancels the transfer associated with this checkin and clears the transfer_id.

If the item has a recall in transit, it reverts the recall transfer as well.


Returns the C<Koha::Checkin> object for chaining.

=cut

sub cancel_transfer {
    my ($self) = @_;

    my $transfer = $self->transfer;

    $transfer->cancel( { reason => 'Manual', force => 1 } );

    # If there's a recall in transit for this item, revert it
    if ( C4::Context->preference('UseRecalls') ) {
        my $item   = $self->item;
        my $recall = Koha::Recalls->find( { item_id => $item->itemnumber, status => 'in_transit' } );
        $recall->revert_transfer if $recall;
    }

    $self->set( { transfer_id => undef } )->store;

    return $self;
}

=head3 confirm_recall

    $checkin->confirm_recall;

Resolves the recall associated with this checkin. If the recall's pickup
library is the same as the checkin library, sets the recall to waiting.
Otherwise, starts a transfer to the pickup library.


Returns the C<Koha::Checkin> object for chaining.

=cut

sub confirm_recall {
    my ($self) = @_;

    my $recall = $self->recall;
    my $item   = $self->item;

    if ( $recall->pickup_library_id ne $self->library_id ) {

        # Needs transfer to pickup library
        $recall->start_transfer( { item => $item } ) unless $recall->in_transit;
    } else {

        # Same library — set to waiting
        my $expirationdate = $recall->calc_expirationdate;
        $recall->set_waiting( { item => $item, expirationdate => $expirationdate } )
            unless $recall->waiting;
    }

    return $self;
}

=head2 Internal methods

=head3 verify_bundle

    $checkin->verify_bundle( { verified_barcodes => \@barcodes } );

Processes bundle verification after checkin. Verified items get their
lost status cleared. Missing items (expected but not verified) are
marked as lost using C<BundleLostValue>. Unexpected items (verified
but not in the bundle) are removed from the bundle.

Returns a hashref with keys: verified, missing, unexpected.

=cut

sub verify_bundle {
    my ( $self, $params ) = @_;

    my $verified_barcodes = $params->{verified_barcodes} || [];
    my $item              = $self->item;

    require Koha::Items;
    require Koha::ItemTypes;
    require C4::Context;

    my $BundleLostValue = C4::Context->preference('BundleLostValue') || 1;

    # Build lookup of expected bundle items
    my $expected = { map { $_->barcode => $_ } $item->bundle_items->as_list };

    my @verified;
    my @unexpected;
    my @missing;

    # Process verified barcodes
    if (@$verified_barcodes) {
        my $verify_items = Koha::Items->search( { barcode => { 'in' => $verified_barcodes } } );
        while ( my $vi = $verify_items->next ) {

            # Clear lost status
            $vi->itemlost(0);
            $vi->datelastseen( dt_from_string() );

            if ( delete $expected->{ $vi->barcode } ) {
                push @verified, $vi;
            } else {

                # Not expected — remove from bundle
                $vi->remove_from_bundle;
                push @unexpected, $vi;
            }
            $vi->store;
        }
    }

    # Mark remaining expected items as lost
    for my $barcode ( keys %$expected ) {
        my $missing_item = $expected->{$barcode};
        unless ( $missing_item->itemlost ) {
            $missing_item->itemlost($BundleLostValue)->store;
            push @missing, $missing_item;
        }
    }

    return {
        verified   => \@verified,
        missing    => \@missing,
        unexpected => \@unexpected,
    };
}

=head3 _type

=cut

sub _type {
    return 'Checkin';
}

1;
