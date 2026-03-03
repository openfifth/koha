package Koha::Hold;

# Copyright ByWater Solutions 2014
# Copyright 2017 Koha Development team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use List::MoreUtils qw( any );

use C4::Context qw(preference);
use C4::Letters qw( GetPreparedLetter EnqueueLetter );
use C4::Log qw( logaction );
use C4::Reserves;

use Koha::AuthorisedValues;
use Koha::DateUtils qw( dt_from_string );
use Koha::Patrons;
use Koha::Biblios;
use Koha::Hold::CancellationRequests;
use Koha::Items;
use Koha::Libraries;
use Koha::Calendar;
use Koha::Plugins;

use Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue;

use Koha::Exceptions;
use Koha::Exceptions::Hold;

use base qw(Koha::Object);

=head1 NAME

Koha::Hold - Koha Hold object class

=head1 API

=head2 Class methods

=cut

=head3 age

returns the number of days since a hold was placed, optionally
using the calendar

my $age = $hold->age( $use_calendar );

=cut

sub age {
    my ( $self, $use_calendar ) = @_;

    my $today = dt_from_string;
    my $age;

    if ( $use_calendar ) {
        my $calendar = Koha::Calendar->new( branchcode => $self->branchcode );
        $age = $calendar->days_between( dt_from_string( $self->reservedate ), $today );
    }
    else {
        $age = $today->delta_days( dt_from_string( $self->reservedate ) );
    }

    $age = $age->in_units( 'days' );

    return $age;
}

=head3 suspend_hold

my $hold = $hold->suspend_hold( $suspend_until );

=cut

sub suspend_hold {
    my ( $self, $date ) = @_;

    my $original = C4::Context->preference('HoldsLog') ? $self->unblessed : undef;

    $date &&= dt_from_string($date)->truncate( to => 'day' )->datetime;

    if ( $self->is_found ) {    # We can't suspend found holds
        if ( $self->is_waiting ) {
            Koha::Exceptions::Hold::CannotSuspendFound->throw( status => 'W' );
        }
        elsif ( $self->is_in_transit ) {
            Koha::Exceptions::Hold::CannotSuspendFound->throw( status => 'T' );
        }
        elsif ( $self->is_in_processing ) {
            Koha::Exceptions::Hold::CannotSuspendFound->throw( status => 'P' );
        }
        else {
            Koha::Exceptions::Hold::CannotSuspendFound->throw(
                      'Unhandled data exception on found hold (id='
                    . $self->id
                    . ', found='
                    . $self->found
                    . ')' );
        }
    }

    $self->suspend(1);
    $self->suspend_until($date);
    $self->store();

    Koha::Plugins->call(
        'after_hold_action',
        {
            action  => 'suspend',
            payload => { hold => $self->get_from_storage }
        }
    );

    logaction( 'HOLDS', 'SUSPEND', $self->reserve_id, $self, undef, $original )
        if C4::Context->preference('HoldsLog');

    Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue->new->enqueue(
        {
            biblio_ids => [ $self->biblionumber ]
        }
    ) if C4::Context->preference('RealTimeHoldsQueue');

    return $self;
}

=head3 resume

my $hold = $hold->resume();

=cut

sub resume {
    my ( $self ) = @_;

    my $original = C4::Context->preference('HoldsLog') ? $self->unblessed : undef;

    $self->suspend(0);
    $self->suspend_until( undef );

    $self->store();

    Koha::Plugins->call(
        'after_hold_action',
        {
            action  => 'resume',
            payload => { hold => $self->get_from_storage }
        }
    );

    logaction( 'HOLDS', 'RESUME', $self->reserve_id, $self, undef, $original )
        if C4::Context->preference('HoldsLog');

    Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue->new->enqueue(
        {
            biblio_ids => [ $self->biblionumber ]
        }
    ) if C4::Context->preference('RealTimeHoldsQueue');

    return $self;
}

=head3 delete

$hold->delete();

=cut

sub delete {
    my ( $self ) = @_;

    my $deleted = $self->SUPER::delete($self);

    logaction( 'HOLDS', 'DELETE', $self->reserve_id, $self )
        if C4::Context->preference('HoldsLog');

    return $deleted;
}

=head3 set_transfer

=cut

sub set_transfer {
    my ( $self ) = @_;

    $self->priority(0);
    $self->found('T');
    $self->store();

    Koha::Plugins->call(
        'after_hold_action',
        {
            action  => 'transfer',
            payload => { hold => $self->get_from_storage }
        }
    );

    return $self;
}

=head3 set_waiting

=cut

sub set_waiting {
    my ( $self, $desk_id ) = @_;

    $self->priority(0);

    my $today = dt_from_string();

    my $values = {
        found => 'W',
        ( !$self->waitingdate ? ( waitingdate => $today->ymd ) : () ),
        desk_id => $desk_id,
    };

    my $max_pickup_delay = C4::Context->preference("ReservesMaxPickUpDelay");
    my $cancel_on_holidays = C4::Context->preference('ExpireReservesOnHolidays');

    my $rule = Koha::CirculationRules->get_effective_rule(
        {
            categorycode => $self->borrower->categorycode,
            itemtype     => $self->item->effective_itemtype,
            branchcode   => $self->branchcode,
            rule_name    => 'holds_pickup_period',
        }
    );
    if ( defined($rule) and $rule->rule_value ne '' ) {

        # circulation rule overrides ReservesMaxPickUpDelay
        $max_pickup_delay = $rule->rule_value;
    }

    my $new_expiration_date = dt_from_string($self->waitingdate)->clone->add( days => $max_pickup_delay );

    if ( C4::Context->preference("ExcludeHolidaysFromMaxPickUpDelay") ) {
        my $itemtype = $self->item ? $self->item->effective_itemtype : $self->biblio->itemtype;
        my $daysmode = Koha::CirculationRules->get_effective_daysmode(
            {
                categorycode => $self->borrower->categorycode,
                itemtype     => $itemtype,
                branchcode   => $self->branchcode,
            }
        );
        my $calendar = Koha::Calendar->new( branchcode => $self->branchcode, days_mode => $daysmode );

        $new_expiration_date = $calendar->days_forward( dt_from_string($self->waitingdate), $max_pickup_delay );
    }

    # If patron's requested expiration date is prior to the
    # calculated one, we keep the patron's one.
    if ( $self->patron_expiration_date ) {
        my $requested_expiration = dt_from_string( $self->patron_expiration_date );

        my $cmp =
          $requested_expiration
          ? DateTime->compare( $requested_expiration, $new_expiration_date )
          : 0;

        $new_expiration_date =
          $cmp == -1 ? $requested_expiration : $new_expiration_date;
    }

    $values->{expirationdate} = $new_expiration_date->ymd;

    $self->set($values)->store();

    Koha::Plugins->call(
        'after_hold_action',
        {
            action  => 'waiting',
            payload => { hold => $self->get_from_storage }
        }
    );

    return $self;
}

=head3 is_pickup_location_valid

    if ($hold->is_pickup_location_valid({ library_id => $library->id }) ) {
        ...
    }

Returns a I<boolean> representing if the passed pickup location is valid for the hold.
It throws a I<Koha::Exceptions::_MissingParameter> if the library_id parameter is not
passed.

=cut

sub is_pickup_location_valid {
    my ( $self, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw('The library_id parameter is mandatory')
        unless $params->{library_id};

    my $pickup_locations;

    if ( $self->itemnumber ) { # item-level
        $pickup_locations = $self->item->pickup_locations({ patron => $self->patron });
    }
    else { # biblio-level
        $pickup_locations = $self->biblio->pickup_locations({ patron => $self->patron });
    }

    return any { $_->branchcode eq $params->{library_id} } $pickup_locations->as_list;
}

=head3 set_pickup_location

    $hold->set_pickup_location(
        {
            library_id => $library->id,
          [ force   => 0|1 ]
        }
    );

Updates the hold pickup location. It throws a I<Koha::Exceptions::Hold::InvalidPickupLocation> if
the passed pickup location is not valid.

Note: It is up to the caller to verify if I<AllowHoldPolicyOverride> is set when setting the
B<force> parameter.

=cut

sub set_pickup_location {
    my ( $self, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw('The library_id parameter is mandatory')
        unless $params->{library_id};

    if (
        $params->{force}
        || $self->is_pickup_location_valid(
            { library_id => $params->{library_id} }
        )
      )
    {
        # all good, set the new pickup location
        $self->branchcode( $params->{library_id} )->store;
    }
    else {
        Koha::Exceptions::Hold::InvalidPickupLocation->throw;
    }

    return $self;
}

=head3 set_processing

$hold->set_processing;

Mark the hold as in processing.

=cut

sub set_processing {
    my ( $self ) = @_;

    $self->priority(0);
    $self->found('P');
    $self->store();

    Koha::Plugins->call(
        'after_hold_action',
        {
            action  => 'processing',
            payload => { hold => $self->get_from_storage }
        }
    );

    return $self;
}

=head3 is_found

Returns true if hold is waiting, in transit or in processing

=cut

sub is_found {
    my ($self) = @_;

    return 0 unless $self->found();
    return 1 if $self->found() eq 'W';
    return 1 if $self->found() eq 'T';
    return 1 if $self->found() eq 'P';
}

=head3 is_waiting

Returns true if hold is a waiting hold

=cut

sub is_waiting {
    my ($self) = @_;

    my $found = $self->found;
    return $found && $found eq 'W';
}

=head3 is_in_transit

Returns true if hold is a in_transit hold

=cut

sub is_in_transit {
    my ($self) = @_;

    return 0 unless $self->found();
    return $self->found() eq 'T';
}

=head3 is_in_processing

Returns true if hold is a in_processing hold

=cut

sub is_in_processing {
    my ($self) = @_;

    return 0 unless $self->found();
    return $self->found() eq 'P';
}

=head3 is_cancelable_from_opac

Returns true if hold is a cancelable hold

Holds may be only canceled if they are not found.

This is used from the OPAC.

=cut

sub is_cancelable_from_opac {
    my ($self) = @_;

    return 1 unless $self->is_found();
    return 0; # if ->is_in_transit or if ->is_waiting or ->is_in_processing
}

=head3 cancellation_requestable_from_opac

    if ( $hold->cancellation_requestable_from_opac ) { ... }

Returns a I<boolean> representing if a cancellation request can be placed on the hold
from the OPAC. It targets holds that cannot be cancelled from the OPAC (see the
B<is_cancelable_from_opac> method above), but for which circulation rules allow
requesting cancellation.

Throws a B<Koha::Exceptions::InvalidStatus> exception with the following I<invalid_status>
values:

=over 4

=item B<'hold_not_waiting'>: the hold is expected to be waiting and it is not.

=item B<'no_item_linked'>: the waiting hold doesn't have an item properly linked.

=back

=cut

sub cancellation_requestable_from_opac {
    my ( $self ) = @_;

    Koha::Exceptions::InvalidStatus->throw( invalid_status => 'hold_not_waiting' )
      unless $self->is_waiting;

    my $item = $self->item;

    Koha::Exceptions::InvalidStatus->throw( invalid_status => 'no_item_linked' )
      unless $item;

    my $patron = $self->patron;

    my $controlbranch = $patron->branchcode;

    if ( C4::Context->preference('ReservesControlBranch') eq 'ItemHomeLibrary' ) {
        $controlbranch = $item->homebranch;
    }

    return Koha::CirculationRules->get_effective_rule_value(
        {
            categorycode => $patron->categorycode,
            itemtype     => $item->itype,
            branchcode   => $controlbranch,
            rule_name    => 'waiting_hold_cancellation',
        }
    ) ? 1 : 0;
}

=head3 is_at_destination

Returns true if hold is waiting
and the hold's pickup branch matches
the hold item's holding branch

=cut

sub is_at_destination {
    my ($self) = @_;

    return $self->is_waiting() && ( $self->branchcode() eq $self->item()->holdingbranch() );
}

=head3 biblio

Returns the related Koha::Biblio object for this hold

=cut

sub biblio {
    my ($self) = @_;
    my $rs = $self->_result->biblionumber;
    return Koha::Biblio->_new_from_dbic($rs);
}

=head3 patron

Returns the related Koha::Patron object for this hold

=cut

sub patron {
    my ($self) = @_;
    my $rs = $self->_result->patron;
    return Koha::Patron->_new_from_dbic($rs);
}

=head3 item

Returns the related Koha::Item object for this Hold

=cut

sub item {
    my ($self) = @_;
    my $rs = $self->_result->itemnumber;
    return unless $rs;
    return Koha::Item->_new_from_dbic($rs);
}

=head3 item_group

Returns the related Koha::Biblio::ItemGroup object for this Hold

=cut

sub item_group {
    my ($self) = @_;
    my $rs = $self->_result->item_group;
    return unless $rs;
    return Koha::Biblio::ItemGroup->_new_from_dbic($rs);
}

=head3 branch

Returns the related Koha::Library object for this hold

DEPRECATED

=cut

sub branch {
    return shift->pickup_library(@_);
}

=head3 pickup_library

Returns the related Koha::Library object for this hold

=cut

sub pickup_library {
    my ($self) = @_;
    my $rs = $self->_result->pickup_library;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 desk

Returns the related Koha::Desk object for this Hold

=cut

sub desk {
    my $self = shift;
    my $desk_rs = $self->_result->desk;
    return unless $desk_rs;
    return Koha::Desk->_new_from_dbic($desk_rs);
}

=head3 borrower

Returns the related Koha::Patron object for this Hold

=cut

# FIXME Should be renamed with ->patron
sub borrower {
    my ($self) = @_;
    my $rs = $self->_result->borrowernumber;
    return Koha::Patron->_new_from_dbic($rs);
}

=head3 is_suspended

my $bool = $hold->is_suspended();

=cut

sub is_suspended {
    my ( $self ) = @_;

    return $self->suspend();
}

=head3 add_cancellation_request

    my $cancellation_request = $hold->add_cancellation_request({ [ creation_date => $creation_date ] });

Adds a cancellation request to the hold. Returns the generated
I<Koha::Hold::CancellationRequest> object.

=cut

sub add_cancellation_request {
    my ( $self, $params ) = @_;

    my $request = Koha::Hold::CancellationRequest->new(
        {   hold_id      => $self->id,
            ( $params->{creation_date} ? ( creation_date => $params->{creation_date} ) : () ),
        }
    )->store;

    $request->discard_changes;

    return $request;
}

=head3 cancellation_requests

    my $cancellation_requests = $hold->cancellation_requests;

Returns related a I<Koha::Hold::CancellationRequests> resultset.

=cut

sub cancellation_requests {
    my ($self) = @_;

    return Koha::Hold::CancellationRequests->search( { hold_id => $self->id } );
}

=head3 cancellation_requested

    if ( $hold->cancellation_requested ) { ... }

Returns true if a cancellation request has been placed for the hold.

=cut

sub cancellation_requested {
    my ($self) = @_;

    return Koha::Hold::CancellationRequests->search( { hold_id => $self->id } )->count > 0;
}

=head3 cancel

my $cancel_hold = $hold->cancel(
    {
        [ charge_cancel_fee   => 1||0, ]
        [ cancellation_reason => $cancellation_reason, ]
        [ skip_holds_queue    => 1||0 ]
    }
);

Cancel a hold:
- The hold will be moved to the old_reserves table with a priority=0
- The priority of other holds will be updated
- The patron will be charge (see ExpireReservesMaxPickUpDelayCharge) if the charge_cancel_fee parameter is set
- The canceled hold will have the cancellation reason added to old_reserves.cancellation_reason if one is passed in
- a CANCEL HOLDS log will be done if the pref HoldsLog is on

=cut

sub cancel {
    my ( $self, $params ) = @_;

    my $autofill_next = $params->{autofill} && $self->itemnumber && $self->found && $self->found eq 'W';

    my $original = C4::Context->preference('HoldsLog') ? $self->unblessed : undef;

    $self->_result->result_source->schema->txn_do(
        sub {
            my $patron = $self->patron;

            $self->cancellationdate( dt_from_string->strftime( '%Y-%m-%d %H:%M:%S' ) );
            $self->priority(0);
            $self->cancellation_reason( $params->{cancellation_reason} );
            $self->store();

            my $dbh = $self->_result->result_source->schema->storage->dbh;
            $dbh->do(
                q{
                    DELETE  q, t
                    FROM    tmp_holdsqueue q
                    INNER JOIN hold_fill_targets t
                    ON  q.borrowernumber = t.borrowernumber
                        AND q.biblionumber = t.biblionumber
                        AND q.itemnumber = t.itemnumber
                        AND q.item_level_request = t.item_level_request
                        AND q.holdingbranch = t.source_branchcode
                    WHERE t.reserve_id = ?
                }, undef, $self->id
            );

            if ( $params->{cancellation_reason} ) {
                my $letter = C4::Letters::GetPreparedLetter(
                    module                 => 'reserves',
                    letter_code            => 'HOLD_CANCELLATION',
                    message_transport_type => 'email',
                    branchcode             => $self->borrower->branchcode,
                    lang                   => $self->borrower->lang,
                    tables => {
                        branches    => $self->borrower->branchcode,
                        borrowers   => $self->borrowernumber,
                        items       => $self->itemnumber,
                        biblio      => $self->biblionumber,
                        biblioitems => $self->biblionumber,
                        reserves    => $self->unblessed,
                    }
                );

                if ($letter) {
                    C4::Letters::EnqueueLetter(
                        {
                            letter                   => $letter,
                            borrowernumber         => $self->borrowernumber,
                            message_transport_type => 'email',
                        }
                    );
                }
            }

            my $old_me = $self->_move_to_old;

            Koha::Plugins->call(
                'after_hold_action',
                {
                    action  => 'cancel',
                    payload => { hold => $old_me->get_from_storage }
                }
            );

            # anonymize if required
            $old_me->anonymize
                if $patron->privacy == 2;

            $self->SUPER::delete(); # Do not add a DELETE log
            # now fix the priority on the others....
            C4::Reserves::_FixPriority({ biblionumber => $self->biblionumber });

            # and, if desired, charge a cancel fee
            my $charge = C4::Context->preference("ExpireReservesMaxPickUpDelayCharge");
            if ( $charge && $params->{'charge_cancel_fee'} ) {
                my $account =
                  Koha::Account->new( { patron_id => $self->borrowernumber } );
                $account->add_debit(
                    {
                        amount     => $charge,
                        user_id    => C4::Context->userenv ? C4::Context->userenv->{'number'} : undef,
                        interface  => C4::Context->interface,
                        library_id => C4::Context->userenv ? C4::Context->userenv->{'branch'} : undef,
                        type       => 'RESERVE_EXPIRED',
                        item_id    => $self->itemnumber,
                        hold_id    => $self->id,
                    }
                );
            }

            C4::Log::logaction( 'HOLDS', 'CANCEL', $self->reserve_id, $self, undef, $original )
                if C4::Context->preference('HoldsLog');

            Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue->new->enqueue(
                {
                    biblio_ids => [ $old_me->biblionumber ]
                }
            ) unless $params->{skip_holds_queue} or !C4::Context->preference('RealTimeHoldsQueue');
        }
    );

    if ($autofill_next) {
        my ( undef, $next_hold ) = C4::Reserves::CheckReserves( $self->item );
        if ($next_hold) {
            my $is_transfer = $self->branchcode ne $next_hold->{branchcode};

            C4::Reserves::ModReserveAffect( $self->itemnumber, $self->borrowernumber, $is_transfer, $next_hold->{reserve_id}, $self->desk_id, $autofill_next );
            C4::Items::ModItemTransfer( $self->itemnumber, $self->branchcode, $next_hold->{branchcode}, "Reserve" ) if $is_transfer;
        }
    }

    return $self;
}

=head3 fill

    $hold->fill({ [ item_id => $item->id ] });

This method marks the hold as filled. It effectively moves it to old_reserves.
The optional I<item_id> parameter is used to set the information about the
item that filled the hold.

=cut

sub fill {
    my ( $self, $params ) = @_;
    $self->_result->result_source->schema->txn_do(
        sub {
            my $patron = $self->patron;

            my $original = C4::Context->preference('HoldsLog') ? $self->unblessed : undef;

            $self->set(
                {
                    found    => 'F',
                    priority => 0,
                    timestamp => dt_from_string->strftime( '%Y-%m-%d %H:%M:%S' ),
                    $params->{item_id} ? ( itemnumber => $params->{item_id} ) : (),
                }
            );

            my $old_me = $self->_move_to_old;

            Koha::Plugins->call(
                'after_hold_action',
                {
                    action  => 'fill',
                    payload => { hold => $old_me->get_from_storage }
                }
            );

            # anonymize if required
            $old_me->anonymize
                if $patron->privacy == 2;

            $self->SUPER::delete(); # Do not add a DELETE log

            # now fix the priority on the others....
            C4::Reserves::_FixPriority({ biblionumber => $self->biblionumber });

            if ( $self->should_charge('collection') ) {
                $self->charge_hold_fee();
            }

            C4::Log::logaction( 'HOLDS', 'FILL', $self->id, $self, undef, $original )
                if C4::Context->preference('HoldsLog');

            Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue->new->enqueue(
                {
                    biblio_ids => [ $old_me->biblionumber ]
                }
            ) if C4::Context->preference('RealTimeHoldsQueue');
        }
    );
    return $self;
}

=head3 sub change_type

    $hold->change_type                # to record level
    $hold->change_type( $itemnumber ) # to item level

Changes hold type between record and item level holds, only if record has
exactly one hold for a patron. This is because Koha expects all holds for
a patron on a record to be alike.

=cut

sub change_type {
    my ( $self, $itemnumber ) = @_;

    my $record_holds_per_patron = Koha::Holds->search(
        {
            borrowernumber => $self->borrowernumber,
            biblionumber   => $self->biblionumber,
        }
    );

    if ( $itemnumber && $self->itemnumber ) {
        $self->itemnumber($itemnumber)->store;
        return $self;
    }

    if ( $record_holds_per_patron->count == 1 ) {
        $self->set(
            {
                itemnumber      => $itemnumber ? $itemnumber : undef,
                item_level_hold => $itemnumber ? 1           : 0,
            }
        )->store;
    } else {
        Koha::Exceptions::Hold::CannotChangeHoldType->throw();
    }

    return $self;
}

=head3 store

Override base store method to set default
expirationdate for holds.

=cut

sub store {
    my ($self, $params) = @_;

    my $hold_reverted = $params->{hold_reverted} // 0;

    Koha::Exceptions::Hold::MissingPickupLocation->throw() unless $self->branchcode;

    if ( !$self->in_storage ) {
        if ( ! $self->expirationdate && $self->patron_expiration_date ) {
            $self->expirationdate($self->patron_expiration_date);
        }

        if (
            C4::Context->preference('DefaultHoldExpirationdate')
                && !$self->expirationdate
          )
        {
            $self->_set_default_expirationdate;
        }
    }
    else {

        my %updated_columns = $self->_result->get_dirty_columns;
        return $self->SUPER::store unless %updated_columns;
        if ( exists $updated_columns{reservedate} || $hold_reverted ) {
            if (
                (
                    C4::Context->preference('DefaultHoldExpirationdate')
                    && ( !exists $updated_columns{expirationdate} || $hold_reverted )
                )
                )
            {
                if ( $self->patron_expiration_date ) {
                    $self->expirationdate( $self->patron_expiration_date );
                } else {
                    $self->_set_default_expirationdate;
                }
            }
        }
        if ( exists $updated_columns{branchcode} ) {
            Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue->new->enqueue( { biblio_ids => [ $self->biblionumber ] } );
        }
    }

    $self = $self->SUPER::store;
}

sub _set_default_expirationdate {
    my $self = shift;

    my $period = C4::Context->preference('DefaultHoldExpirationdatePeriod') || 0;
    my $timeunit =
      C4::Context->preference('DefaultHoldExpirationdateUnitOfTime') || 'days';

    $self->expirationdate(
        dt_from_string( $self->reservedate )->add( $timeunit => $period ) );
}

=head3 calculate_hold_fee

    my $fee = $hold->calculate_hold_fee();

Calculate the hold fee for this hold using circulation rules.
Returns the fee amount as a decimal.

=cut

sub calculate_hold_fee {
    my ($self) = @_;

    my $item = $self->item;

    if ($item) {

        # Item-level hold - straightforward fee calculation
        return $item->holds_fee( $self->patron );
    } else {

        # Title-level hold - use strategy to determine fee
        return $self->_calculate_title_hold_fee();
    }
}

=head3 should_charge

    my $should_charge = $hold->should_charge($stage);

Returns true if the hold fee should be charged at the given stage
based on HoldFeeMode preference and current hold state.

Stage can be:
- 'placement': When the hold is first placed
- 'collection': When the hold is filled/collected

=cut

sub should_charge {
    my ( $self, $stage ) = @_;

    return 0 unless $stage;
    return 0 unless $stage =~ /^(placement|collection)$/;

    my $mode = C4::Context->preference('HoldFeeMode') || 'not_always';

    if ( $stage eq 'placement' ) {
        return 0 if $mode eq 'any_time_is_collected';    # Don't charge at placement
        return 1 if $mode eq 'any_time_is_placed';       # Always charge at placement

        # 'not_always' mode - check conditions at placement time
        return $self->_should_charge_not_always_mode();
    } elsif ( $stage eq 'collection' ) {
        return 1 if $mode eq 'any_time_is_collected';    # Charge at collection
        return 0 if $mode eq 'any_time_is_placed';       # Already charged at placement

        # 'not_always' mode - no additional fee at collection
        return 0;
    }

    return 0;
}

=head3 charge_hold_fee

    $hold->charge_hold_fee({ amount => $fee });

Charge the patron for the hold fee.

=cut

sub charge_hold_fee {
    my ( $self, $params ) = @_;

    my $amount = $params->{amount} // $self->calculate_hold_fee();
    return unless $amount && $amount > 0;

    my $line = $self->patron->account->add_debit(
        {
            amount      => $amount,
            description => $self->biblio->title,
            type        => 'RESERVE',
            item_id     => $self->itemnumber,
            hold_id     => $self->id,
            user_id     => C4::Context->userenv ? C4::Context->userenv->{number} : undef,
            library_id  => C4::Context->userenv ? C4::Context->userenv->{branch} : undef,
            interface   => C4::Context->interface,
        }
    );

    return $line;
}

=head3 _calculate_title_hold_fee

    my $fee = $hold->_calculate_title_hold_fee();

Calculate the hold fee for a title-level hold using the TitleHoldFeeStrategy
system preference to determine which fee to charge when items have different fees.

=cut

sub _calculate_title_hold_fee {
    my ($self) = @_;

    # Get all holdable items for this biblio and calculate their fees
    my $biblio         = $self->biblio;
    my @holdable_items = $biblio->items->search(
        {
            -or => [
                { 'me.notforloan' => { '<=', 0 } },
                { 'me.notforloan' => undef }
            ]
        }
    )->as_list;

    my @fees;
    foreach my $item (@holdable_items) {

        # Check if item is holdable for this patron
        # We ignore hold counts since we're calculating the fee for a hold that's already been placed
        next unless C4::Reserves::CanItemBeReserved( $self->patron, $item, $self->branchcode, { ignore_hold_counts => 1 } )->{status} eq 'OK';

        my $fee = $item->holds_fee( $self->patron );
        push @fees, $fee;
    }

    return 0 unless @fees;

    # Apply the strategy from system preference
    my $strategy = C4::Context->preference('TitleHoldFeeStrategy') || 'highest';

    if ( $strategy eq 'highest' ) {
        return ( sort { $b <=> $a } @fees )[0];    # Maximum fee
    } elsif ( $strategy eq 'lowest' ) {
        return ( sort { $a <=> $b } @fees )[0];    # Minimum fee
    } elsif ( $strategy eq 'most_common' ) {
        return $self->_get_most_common_fee(@fees);
    } else {

        # Default to highest if unknown strategy
        return ( sort { $b <=> $a } @fees )[0];
    }
}

=head3 _get_most_common_fee

Helper method to find the most frequently occurring fee in a list.

=cut

sub _get_most_common_fee {
    my ( $self, @fees ) = @_;

    return 0 unless @fees;

    # Count frequency of each fee
    my %fee_count;
    for my $fee (@fees) {
        $fee_count{$fee}++;
    }

    # Sort by frequency (desc), then by value (desc) as tie breaker
    my $most_common_fee =
        ( sort { $fee_count{$b} <=> $fee_count{$a} || $b <=> $a } keys %fee_count )[0];

    return $most_common_fee;
}

=head3 _should_charge_not_always_mode

Helper method to implement the 'not_always' HoldFeeMode logic.
Returns true if a fee should be charged in not_always mode.

=cut

sub _should_charge_not_always_mode {
    my ($self) = @_;

    # First check if we have a calculated fee > 0
    my $potential_fee = $self->calculate_hold_fee();
    return 0 unless $potential_fee > 0;

    # Apply not_always logic:
    # - If items are available (not issued) → No fee
    # - If all items issued AND no other holds → No fee
    # - If all items issued AND other holds exist → Charge fee

    # Count items that are not on loan (available)
    my $biblio          = $self->biblio;
    my $available_items = $biblio->items->search( { onloan => undef } )->count;

    if ( $available_items > 0 ) {

        # Items are available, no fee needed
        return 0;
    }

    # All items are issued, check for other holds
    my $other_holds = Koha::Holds->search(
        {
            biblionumber   => $self->biblionumber,
            borrowernumber => { '!=' => $self->borrowernumber }
        }
    )->count;

    # Charge fee only if there are other holds (patron joins a queue)
    return $other_holds > 0 ? 1 : 0;
}

=head3 _move_to_old

my $is_moved = $hold->_move_to_old;

Move a hold to the old_reserve table following the same pattern as Koha::Patron->move_to_deleted

=cut

sub _move_to_old {
    my ($self) = @_;
    my $hold_infos = $self->unblessed;
    require Koha::Old::Hold;

    # Create the old hold record
    my $old_hold = Koha::Old::Hold->new($hold_infos)->store;

    # Update any linked accountlines to point to old_reserve_id instead of reserve_id
    $self->_result->search_related('accountlines')->update(
        {
            old_reserve_id => $self->id,
            reserve_id     => undef,
        }
    );

    return $old_hold;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Hold object
on the API.

=cut

sub to_api_mapping {
    return {
        reserve_id             => 'hold_id',
        borrowernumber         => 'patron_id',
        reservedate            => 'hold_date',
        biblionumber           => 'biblio_id',
        deleted_biblionumber   => 'deleted_biblio_id',
        branchcode             => 'pickup_library_id',
        notificationdate       => undef,
        reminderdate           => undef,
        cancellationdate       => 'cancellation_date',
        reservenotes           => 'notes',
        found                  => 'status',
        itemnumber             => 'item_id',
        waitingdate            => 'waiting_date',
        expirationdate         => 'expiration_date',
        patron_expiration_date => undef,
        lowestPriority         => 'lowest_priority',
        suspend                => 'suspended',
        suspend_until          => 'suspended_until',
        itemtype               => 'item_type',
        item_level_hold        => 'item_level',
    };
}

=head3 can_update_pickup_location_opac

    my $can_update_pickup_location_opac = $hold->can_update_pickup_location_opac;

Returns if a hold can change pickup location from opac

=cut

sub can_update_pickup_location_opac {
    my ($self) = @_;

    my @statuses = split /,/, C4::Context->preference("OPACAllowUserToChangeBranch");
    foreach my $status ( @statuses ){
        return 1 if ($status eq 'pending' && !$self->is_found && !$self->is_suspended );
        return 1 if ($status eq 'intransit' && $self->is_in_transit);
        return 1 if ($status eq 'suspended' && $self->is_suspended);
    }
    return 0;
}

=head3 strings_map

Returns a map of column name to string representations including the string.

=cut

sub strings_map {
    my ( $self, $params ) = @_;

    my $strings = {
        pickup_library_id => { str => $self->pickup_library->branchname, type => 'library' },
    };

    if ( defined $self->cancellation_reason ) {
        my $av = Koha::AuthorisedValues->search(
            {
                category         => 'HOLD_CANCELLATION',
                authorised_value => $self->cancellation_reason,
            }
        );
        my $cancellation_reason_str =
              $av->count
            ? $params->{public}
                ? $av->next->opac_description
                : $av->next->lib
            : $self->cancellation_reason;

        $strings->{cancellation_reason} = {
            category => 'HOLD_CANCELLATION',
            str      => $cancellation_reason_str,
            type     => 'av',
        };
    }

    return $strings;
}

=head3 debits

    my $debits = $hold->debits;

Get all debit account lines (charges) associated with this hold

=cut

sub debits {
    my ($self) = @_;

    my $accountlines_rs = $self->_result->search_related(
        'accountlines',
        {
            credit_type_code => undef,    # Only debits (no credits)
        },
        {
            order_by => { -desc => 'timestamp' },
        }
    );
    return Koha::Account::Debits->_new_from_dbic($accountlines_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Reserve';
}

=head1 AUTHORS

Kyle M Hall <kyle@bywatersolutions.com>
Jonathan Druart <jonathan.druart@bugs.koha-community.org>
Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut

1;
