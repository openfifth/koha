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

Throws C<Koha::Exceptions::MissingParameter> if there is no hold associated
with this checkin.

Returns the C<Koha::Checkin> object for chaining.

=cut

sub confirm_hold {
    my ($self) = @_;

    Koha::Exceptions::MissingParameter->throw("No hold associated with this checkin")
        unless $self->hold_id;

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

Throws C<Koha::Exceptions::MissingParameter> if there is no hold associated
with this checkin.

Returns the C<Koha::Checkin> object for chaining.

=cut

sub cancel_hold {
    my ( $self, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw("No hold associated with this checkin")
        unless $self->hold_id;

    my $hold = $self->hold;

    $hold->cancel( { cancellation_reason => $params->{reason} } );

    $self->set( { hold_id => undef } )->store;

    return $self;
}

=head3 confirm_transfer

    $checkin->confirm_transfer;

Sets the transfer associated with this checkin in transit (populates datesent).

Throws C<Koha::Exceptions::MissingParameter> if there is no transfer associated
with this checkin.

Returns the C<Koha::Checkin> object for chaining.

=cut

sub confirm_transfer {
    my ($self) = @_;

    Koha::Exceptions::MissingParameter->throw("No transfer associated with this checkin")
        unless $self->transfer_id;

    my $transfer = $self->transfer;

    $transfer->transit unless $transfer->datesent;

    return $self;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Checkin';
}

1;
