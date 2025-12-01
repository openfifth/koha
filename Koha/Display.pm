package Koha::Display;

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
use Koha::Displays;
use Koha::DisplayItems;
use Koha::ItemType;
use Koha::Library;

use base qw(Koha::Object);

=head1 NAME

Koha::Display - Koha Display Object class

=head1 API

=head2 Class methods

=cut

=head3 display_items

    my $display_items = $display->display_items;

Returns the related Koha::DisplayItems object for this display.

=cut

sub display_items {
    my ( $self, $display_items ) = @_;

    if ($display_items) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                my $existing_items = $self->display_items;
                my %existing_map   = map { $_->itemnumber   => $_ } $existing_items->as_list;
                my %new_map        = map { $_->{itemnumber} => $_ } @$display_items;

                for my $existing_item ( values %existing_map ) {
                    unless ( exists $new_map{ $existing_item->itemnumber } ) {
                        $existing_item->delete;
                    }
                }

                for my $display_item (@$display_items) {
                    if ( exists $existing_map{ $display_item->{itemnumber} } ) {
                        my $existing_item = Koha::DisplayItems->search(
                            {
                                display_id => $self->display_id,
                                itemnumber => $display_item->{itemnumber},
                            }
                        )->single;

                        if ($existing_item) {
                            $existing_item->set(
                                {
                                    itemnumber   => $display_item->{itemnumber},
                                    biblionumber => $display_item->{biblionumber},
                                    date_added   => $display_item->{date_added},
                                    date_remove  => $display_item->{date_remove},
                                }
                            )->store;
                        }
                    } else {
                        Koha::DisplayItem->new(
                            {
                                display_id   => $self->display_id,
                                itemnumber   => $display_item->{itemnumber},
                                biblionumber => $display_item->{biblionumber},
                                date_added   => $display_item->{date_added},
                                date_remove  => $display_item->{date_remove},
                            }
                        )->store;
                    }
                }
            }
        );
    }

    my $display_items_rs = $self->_result->display_items;
    return Koha::DisplayItems->_new_from_dbic($display_items_rs);
}

=head3 display_library

    my $display_library = $display->display_library;

Returns the related Koha::Library object for this display's branch.

=cut

sub display_library {
    my ($self) = @_;
    my $rs = $self->_result->display_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 home_library

    my $home_library = $display->home_library;

Returns the related Koha::Library object for this display's home branch for items.

=cut

sub home_library {
    my ($self) = @_;
    my $rs = $self->_result->display_home_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 holding_library

    my $holding_library = $display->holding_library;

Returns the related Koha::Library object for this display's holding branch for items.

=cut

sub holding_library {
    my ($self) = @_;
    my $rs = $self->_result->display_holding_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 item_type

    my $item_type = $display->item_type;

Returns the related Koha::ItemType object for this display's item type.

=cut

sub item_type {
    my ($self) = @_;
    my $rs = $self->_result->display_itype;
    return unless $rs;
    return Koha::ItemType->_new_from_dbic($rs);
}

=head3 store

    $display->store;

Overloaded store method to add action logging.

=cut

sub store {
    my ($self) = @_;

    unless ( $self->in_storage ) {
        if ( !$self->start_date ) {
            my $dt = dt_from_string();

            $self->start_date( $dt->ymd );
        }

        if ( !$self->display_days ) {
            $self->display_days(14);
        }

        if ( !$self->end_date ) {
            my $display_days = $self->display_days || 14;
            my $dt           = dt_from_string( $self->start_date );

            $dt->add( days => $display_days );
            $self->end_date( $dt->ymd );
        }

        $self->display_id(undef);
        $self = $self->SUPER::store;
        $self->discard_changes;

        logaction( "DISPLAYS", "CREATE", $self->display_id, $self, undef, undef )
            if ( C4::Context->preference("DisplayItemsLog") );

        return $self;
    } else {
        if ( C4::Context->preference("DisplayItemsLog") ) {
            my $original       = $self->in_storage ? Koha::Displays->find( $self->display_id ) : undef;
            my $enabled_before = $original         ? $original->enabled                        : undef;
            my $enabled_after  = $self->enabled;

            if ( defined $enabled_before && defined $enabled_after && $enabled_before != $enabled_after ) {
                my $enable_action = $enabled_after ? "ENABLE" : "DISABLE";
                logaction( "DISPLAYS", $enable_action, $self->display_id, $self, undef, undef );
            }

            logaction( "DISPLAYS", "MODIFY", $self->display_id, $self, undef, $original );
        }

        return $self->SUPER::store;
    }
}

=head3 delete

    $display->delete;

Overloaded delete method to add action logging.

=cut

sub delete {
    my ($self) = @_;

    logaction( "DISPLAYS", "DELETE", $self->display_id, $self, undef, undef )
        if C4::Context->preference("DisplayItemsLog");

    return $self->SUPER::delete;
}

=head3 active

    $display->active;

Returns 1 if the display is:
  * enabled
  * the start date is before today
  * the end date is after today

Returns undef if any of the above statements are false

=cut

sub active {
    my ($self) = @_;

    return unless $self->enabled;
    return unless $self->start_date and $self->end_date;

    my $dt_now   = dt_from_string();
    my $dt_start = dt_from_string( $self->start_date );
    my $dt_end   = dt_from_string( $self->end_date );

    return 1 if ( $dt_start <= $dt_now ) and ( $dt_end >= $dt_now );
    return;
}

=head3 to_api

    my $json = $display->to_api;

Overloaded method that returns a JSON representation of the Koha::Display object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $json_display = $self->SUPER::to_api($params);
    return unless $json_display;

    $json_display->{active} =
        ( $self->active )
        ? Mojo::JSON->true
        : Mojo::JSON->false;

    return $json_display;
}

=head2 Public API methods

=head3 public_read_list

Returns the list of fields that are allowed to be read by the public API.
Excludes staff_note which is for internal use only.

=cut

sub public_read_list {
    return [
        qw(
            display_id
            display_name
            start_date
            end_date
            enabled
            display_location
            display_code
            display_branch
            display_home_branch
            display_holding_branch
            display_itype
            public_note
            display_days
            display_return_over
        )
    ];
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Display';
}

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
