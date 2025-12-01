package Koha::DisplayItems;

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

use Koha::Database;
use Koha::DisplayItem;

use base qw(Koha::Objects);

=head1 NAME

Koha::DisplayItems - Koha Display Items Object set class

=head1 API

=head2 Class methods

=cut

=head3 for_display

    my $display_items = $display_items->for_display($display_id);

Returns display items for a specific display.

=cut

sub for_display {
    my ( $self, $display_id ) = @_;
    return $self->search( { display_id => $display_id } );
}

=head3 for_item

    my $display_items = $display_items->for_item($itemnumber);

Returns display items for a specific item.

=cut

sub for_item {
    my ( $self, $itemnumber ) = @_;
    return $self->search( { itemnumber => $itemnumber } );
}

=head3 for_biblio

    my $display_items = $display_items->for_biblio($biblionumber);

Returns display items for a specific biblio.

=cut

sub for_biblio {
    my ( $self, $biblionumber ) = @_;
    return $self->search( { biblionumber => $biblionumber } );
}

=head3 due_for_removal

    my $items_to_remove = $display_items->due_for_removal;

Returns display items that are due for removal based on date_remove.

=cut

sub due_for_removal {
    my ($self) = @_;
    my $today = DateTime->today->ymd;

    return $self->search( { date_remove => { '<=' => $today } } );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'DisplayItem';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::DisplayItem';
}

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
