package Koha::DisplayItem;

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
use DateTime;

use C4::Context;
use C4::Log qw( logaction );
use Koha::Database;
use Koha::Display;
use Koha::Item;
use Koha::Biblio;

use base qw(Koha::Object);

=head1 NAME

Koha::DisplayItem - Koha Display Item Object class

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

    $display_item->store();

Overloaded store method to add action logging.

=cut

sub store {
    my ($self) = @_;

    my $action = $self->in_storage ? 'update' : 'create';

    if ( $action eq 'create' && !$self->date_remove ) {
        my $display = $self->display;
        if ( $display && $display->display_days ) {
            my $dt = DateTime->now( time_zone => C4::Context->tz() );
            $dt->add( days => $display->display_days );
            $self->date_remove( $dt->ymd );
        }
    }

    my $result = $self->SUPER::store;

    if ( C4::Context->preference("DisplayItemsLog") && $action eq 'create' ) {
        logaction( "DISPLAYS", "ADD_ITEM", $self->display_id, "Item " . $self->itemnumber, undef, $self );
    }

    return $result;
}

=head3 delete

    $display_item->delete();

Overloaded delete method to add action logging.

=cut

sub delete {
    my ($self) = @_;

    my $display_id = $self->display_id;
    my $itemnumber = $self->itemnumber;

    my $result = $self->SUPER::delete;

    logaction( "DISPLAYS", "REMOVE_ITEM", $display_id, "Item " . $itemnumber, undef, $self )
        if C4::Context->preference("DisplayItemsLog");

    return $result;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'DisplayItem';
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1;
