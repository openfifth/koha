package Koha::Display::Item;

# Copyright 2025-2026 Open Fifth Ltd
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

use Carp;

use C4::Context;
use C4::Log qw( logaction );
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Display;
use Koha::Displays;
use Koha::Exceptions;
use Koha::Item;
use Koha::Items;
use Koha::Biblio;
use Koha::SearchEngine;
use Koha::SearchEngine::Indexer;

use base qw(Koha::Object);

=head1 NAME

Koha::Display::Item - Koha Display Item Object class


=head1 API

=head2 Class methods

=cut

=head3 display

    my $display = $display_item->display;

Returns the related Koha::Display object for this display item.

=cut

sub display {
    my ($self) = @_;
    my $rs = $self->_result->display;
    return unless $rs;
    return Koha::Display->_new_from_dbic($rs);
}

=head3 item

    my $item = $display_item->item;

Returns the related Koha::Item object for this display item.

=cut

sub item {
    my ($self) = @_;
    my $rs = $self->_result->itemnumber;
    return unless $rs;
    return Koha::Item->_new_from_dbic($rs);
}

=head3 biblio

    my $biblio = $display_item->biblio;

Returns the related Koha::Biblio object for this display item.

=cut

sub biblio {
    my ($self) = @_;
    my $rs = $self->_result->biblionumber;
    return unless $rs;
    return Koha::Biblio->_new_from_dbic($rs);
}

=head3 store

    $display_item->store;

Overloaded store method to validate the display item and add action logging.

Throws a L<Koha::Exceptions::BadParameter> when the display or item does not
exist, C<date_added> is missing, C<date_remove> is before C<date_added>, or the
item is already on an active display that was added later.

=cut

sub store {
    my ($self) = @_;

    # Look the records up by id: for an unsaved row the relationship accessors
    # return a placeholder object, even when the id does not exist
    my $display = defined $self->display_id ? Koha::Displays->find( $self->display_id ) : undef;
    Koha::Exceptions::BadParameter->throw(
        parameter => 'display_id',
        error     => sprintf( 'Display %s does not exist', $self->display_id // q{} ),
    ) unless $display;

    my $item = defined $self->itemnumber ? Koha::Items->find( $self->itemnumber ) : undef;
    Koha::Exceptions::BadParameter->throw(
        parameter => 'itemnumber',
        error     => sprintf( 'Item %s does not exist', $self->itemnumber // q{} ),
    ) unless $item;

    # The record is always the item's own
    $self->biblionumber( $item->biblionumber );

    Koha::Exceptions::BadParameter->throw(
        parameter => 'date_added',
        error     => 'A display item requires a date_added',
    ) unless defined $self->date_added;

    Koha::Exceptions::BadParameter->throw(
        parameter => 'date_remove',
        error     => 'date_remove cannot be before date_added',
    ) if defined $self->date_remove && $self->date_remove lt $self->date_added;

    unless ( $self->in_storage ) {
        if ( defined $display->start_date && defined $display->display_days && not defined $self->date_remove ) {
            my $dt_now                = dt_from_string();
            my $dt_display_start_date = dt_from_string( $display->start_date, "iso" );

            unless ( $dt_now->ymd lt $dt_display_start_date->ymd ) {
                my $dt_adjusted_for_display_days = $dt_now->clone->add( days => $display->display_days );
                $self->date_remove( $dt_adjusted_for_display_days->ymd );
            } else {
                my $dt_adjusted_for_display_days = $dt_display_start_date->clone->add( days => $display->display_days );
                $self->date_remove( $dt_adjusted_for_display_days->ymd );
            }
        }

        # An item that is already on an active display cannot be added to another
        # one with an earlier date than the one it is currently on
        if ( my $current = $item->active_display_item ) {
            Koha::Exceptions::BadParameter->throw(
                parameter => 'date_added',
                error     => 'The item is already on an active display that was added later',
            ) if dt_from_string( $self->date_added ) < dt_from_string( $current->date_added );
        }

        $self->display_item_id(undef);
        $self = $self->SUPER::store;
        $self->discard_changes;

        $self->_reindex_item;

        logaction( "DISPLAYS", "ADD_ITEM", $self->display_item_id, $self, undef, $self )
            if ( C4::Context->preference("DisplayItemsLog") );

        return $self;
    } else {
        ## if no date_remove is supplied, set it to a really distant date
        ## so that added<->remove calculations can be made elsewhere
        $self->date_remove( Koha::Display::DISTANT_DATE() )
            unless ( defined $self->date_remove );

        my $original = Koha::Display::Items->find( $self->display_item_id )->unblessed;

        $self = $self->SUPER::store;
        $self->discard_changes;

        $self->_reindex_item;

        logaction( "DISPLAYS", "MODIFY_ITEM", $self->display_item_id, $self, undef, $original )
            if ( C4::Context->preference("DisplayItemsLog") );

        return $self;
    }
}

=head3 delete

    $display_item->delete;

Overloaded delete method to add action logging.

=cut

sub delete {
    my ($self) = @_;

    my $display_item_id = $self->display_item_id;
    my $item            = $self->item;
    my $result          = $self->SUPER::delete;

    # The item no longer has the display's values: its record must be indexed again
    $self->_reindex_item($item);

    logaction( "DISPLAYS", "REMOVE_ITEM", $display_item_id, $self, undef, $self )
        if ( C4::Context->preference("DisplayItemsLog") );

    return $result;
}

=head3 active

    $display->active;

Returns 1 if the display item is:
  * on an active display
  * the date added is before today
  * the date remove is after today

Returns undef if any of the above statements are false

=cut

sub active {
    my ($self) = @_;

    my $item = $self->item;
    return
        unless $item;

    my $display = $self->display;
    return
        unless $display->active;

    return
        unless $self->date_added and $self->date_remove;

    my $dt_now    = dt_from_string();
    my $dt_added  = dt_from_string( $self->date_added );
    my $dt_remove = dt_from_string( $self->date_remove );

    return
        unless ( $dt_added->ymd le $dt_now->ymd );

    return
        unless ( $dt_remove->ymd ge $dt_now->ymd );

    return 1;
}

=head3 active_display

    my $display = $display_item->active_display;

Returns the display of this display item if the display item is active (see
L</active>), undef otherwise.

=cut

sub active_display {
    my ($self) = @_;

    my $display = $self->display;
    return
        unless $self->active
        and $display->active;

    return $display;
}

=head3 to_api

    my $json = $display_item->to_api;

Overloaded method that returns a JSON representation of the Koha::Display::Item object,

suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $json_display_item = $self->SUPER::to_api($params);
    return unless $json_display_item;

    $json_display_item->{active} =
        ( $self->active )
        ? Mojo::JSON->true
        : Mojo::JSON->false;

    return $json_display_item;
}

=head2 Public API methods

=head3 public_read_list

Returns the list of fields that are allowed to be read by the public API.

=cut

sub public_read_list {
    return [
        qw(
            display_item_id
            display_id
            itemnumber
            biblionumber
            date_added
            date_remove
        )
    ];
}

=head2 Internal methods

=head3 _reindex_item

=cut

sub _reindex_item {
    my ( $self, $item ) = @_;

    $item //= $self->item;
    return unless $item;

    my $indexer = Koha::SearchEngine::Indexer->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );
    return $indexer->index_records( $item->biblionumber, "specialUpdate", "biblioserver" );
}

=head3 _type

=cut

sub _type {
    return 'DisplayItem';
}

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
