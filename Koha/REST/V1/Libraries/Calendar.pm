package Koha::REST::V1::Libraries::Calendar;

# Copyright 2026 Theke Solutions
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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Libraries;
use Koha::Calendar::WeeklyClosures;
use Koha::Calendar::RepeatingClosures;
use Koha::Calendar::SingleClosures;
use Koha::Calendar::Exceptions;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing all calendar closure definitions
for a library, grouped by type.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $library = Koha::Libraries->find( $c->param('library_id') );

    return $c->render_resource_not_found("Library")
        unless $library;

    return try {
        my $id = $library->branchcode;
        return $c->render(
            status  => 200,
            openapi => {
                weekly_closures =>
                    $c->objects->search( Koha::Calendar::WeeklyClosures->search( { library_id => $id } ) ),
                repeating_closures =>
                    $c->objects->search( Koha::Calendar::RepeatingClosures->search( { library_id => $id } ) ),
                single_closures =>
                    $c->objects->search( Koha::Calendar::SingleClosures->search( { library_id => $id } ) ),
                exceptions => $c->objects->search( Koha::Calendar::Exceptions->search( { library_id => $id } ) ),
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 copy

Controller function that copies all calendar definitions from another library.

=cut

sub copy {
    my $c = shift->openapi->valid_input or return;

    my $library = Koha::Libraries->find( $c->param('library_id') );

    return $c->render_resource_not_found("Library")
        unless $library;

    return try {
        my $from_library = Koha::Libraries->find( $c->req->json->{from_library_id} );
        return $c->render(
            status  => 400,
            openapi => { error => "Source library not found", error_code => 'source_not_found' }
        ) unless $from_library;

        $from_library->calendar->copy_to( $library->branchcode );
        $c->res->headers->location( $c->req->url->to_string =~ s|/copy$||r );
        return $c->render( status => 201, openapi => {} );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
