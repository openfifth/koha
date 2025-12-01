package Koha::Displays;

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

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Display;

use base qw(Koha::Objects);

=head1 NAME

Koha::Displays - Koha Display Object set class

=head1 API

=head2 Class methods

=cut

=head3 enabled

    my $enabled_displays = $displays->enabled;

Returns only the enabled displays.

=cut

sub enabled {
    my ($self) = @_;
    return $self->search( { enabled => 1 } );
}

=head3 for_branch

    my $branch_displays = $displays->for_branch($branchcode);

Returns displays for a specific branch.

=cut

sub for_branch {
    my ( $self, $branchcode ) = @_;
    return $self->search( { display_home_branch => $branchcode } );
}

=head3 active

    my $active_displays = $displays->active;

Returns displays that are currently active (enabled and within date range if specified).

=cut

sub active {
    my ($self) = @_;
    my $today = dt_from_string()->truncate( to => 'day' )->ymd;

    return $self->search(
        {
            enabled => 1,
            -and    => [
                -or => [ { start_date => undef }, { start_date => { '<=' => $today } } ],
                -or => [ { end_date   => undef }, { end_date   => { '>=' => $today } } ],
            ],
        }
    );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Display';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Display';
}

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
