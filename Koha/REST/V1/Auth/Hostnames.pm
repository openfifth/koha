package Koha::REST::V1::Auth::Hostnames;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Auth::Hostname;
use Koha::Auth::Hostnames;

use Try::Tiny;

=head1 NAME

Koha::REST::V1::Auth::Hostnames - Controller library for handling hostname routes.

=head2 Operations

=head3 list

Controller method for listing all known hostnames.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render(
            status  => 200,
            openapi => $c->objects->search( Koha::Auth::Hostnames->new ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller method for retrieving a single hostname by ID.

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $hostname = $c->objects->find(
            Koha::Auth::Hostnames->new,
            $c->param('hostname_id')
        );

        return $c->render_resource_not_found("Hostname")
            unless $hostname;

        return $c->render( status => 200, openapi => $hostname );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
