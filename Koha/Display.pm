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
use Koha::Displays;
use Koha::DisplayItems;
use Koha::Library;
use Koha::ItemType;

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

                for my $new_item (@$display_items) {
                    unless ( exists $existing_map{ $new_item->{itemnumber} } ) {
                        Koha::DisplayItem->new(
                            {
                                display_id   => $self->display_id,
                                itemnumber   => $new_item->{itemnumber},
                                biblionumber => $new_item->{biblionumber},
                                date_remove  => $new_item->{date_remove},
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

=head3 home_library

    my $home_library = $display->home_library;

Returns the related Koha::Library object for this display's home branch.

=cut

sub home_library {
    my ($self) = @_;
    my $rs = $self->_result->display_branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 holding_library

    my $holding_library = $display->holding_library;

Returns the related Koha::Library object for this display's holding branch.

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

    $display->store();

Overloaded store method to add action logging.

=cut

sub store {
    my ($self) = @_;

    my $action   = $self->in_storage ? 'update'                                  : 'create';
    my $original = $self->in_storage ? Koha::Displays->find( $self->display_id ) : undef;

    my $enabled_before = $original ? $original->enabled : undef;
    my $enabled_after  = $self->enabled;

    my $result = $self->SUPER::store;

    if ( C4::Context->preference("DisplayItemsLog") ) {
        if ( $action eq 'create' ) {
            logaction( "DISPLAYS", "CREATE", $self->display_id, undef, undef, $self );
        } else {
            logaction( "DISPLAYS", "MODIFY", $self->display_id, $self, undef, $original );

            if ( defined $enabled_before && defined $enabled_after && $enabled_before != $enabled_after ) {
                my $enable_action = $enabled_after ? "ENABLE" : "DISABLE";
                logaction( "DISPLAYS", $enable_action, $self->display_id, undef, undef, $self );
            }
        }
    }

    return $result;
}

=head3 delete

    $display->delete();

Overloaded delete method to add action logging.

=cut

sub delete {
    my ($self) = @_;

    my $result = $self->SUPER::delete;

    logaction( "DISPLAYS", "DELETE", $self->display_id, undef, undef, $self )
        if C4::Context->preference("DisplayItemsLog");

    return $result;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Display';
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1;
