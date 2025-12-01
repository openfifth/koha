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
use Koha::Item;
use Koha::Biblio;

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

Overloaded store method to add action logging.

=cut

sub store {
    my ($self)         = @_;
    my $display        = $self->display;
    my $item           = $self->item;
    my $active_display = $item->active_display;

    return unless ( $display && $item );

    return
        unless ( defined $self->date_added );

    return
        if ( defined $self->date_remove && ( $self->date_remove lt $self->date_added ) );

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

        if ($active_display) {
            my $active_display_items = Koha::Display::Items->search( { display_id => $active_display->display_id } );

            for my $active_display_item ( $active_display_items->next ) {
                next unless $active_display_item->itemnumber == $self->itemnumber;

                my $dt_old = dt_from_string( $active_display_item->date_added );
                my $dt_new = dt_from_string( $self->date_added );

                return if $dt_new < $dt_old;
            }
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
        $self->date_remove("2106-02-07")
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

    logaction( "DISPLAYS", "REMOVE_ITEM", $self->display_item_id, $self, undef, $self )
        if ( C4::Context->preference("DisplayItemsLog") );

    return $self->SUPER::delete;
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

    my $display = $item->active_display;

Returns the active display for this item, if any. Returns undef if the item is not
currently in an active display.

An active display is one that:
- Is enabled
- Has a date_added on the display_item that is today or in the past (or no date_added)
- Has a date_remove on the display_item that is today or in the future (or no date_remove)

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

=head2 Internal methods

=head3 _reindex_item

=cut

sub _reindex_item {
    my ($self) = @_;

    my $item = $self->item;
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
