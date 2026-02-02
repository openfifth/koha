package Koha::REST::V1::ShibbolethFieldMappings;

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

use Try::Tiny    qw(catch try);
use Scalar::Util qw(blessed);

use Koha::ShibbolethFieldMapping;
use Koha::ShibbolethFieldMappings;

=head1 API

=head2 Methods

=head3 list

List all field mappings

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mappings = $c->objects->search( Koha::ShibbolethFieldMappings->new );
        return $c->render( status => 200, openapi => $mappings );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Get a specific mapping

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mapping = Koha::ShibbolethFieldMappings->find( $c->param('mapping_id') );

        return $c->render_resource_not_found('Mapping') unless $mapping;

        return $c->render( status => 200, openapi => $c->objects->to_api($mapping) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Add a new field mapping

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mapping = Koha::ShibbolethFieldMapping->new_from_api( $c->req->json );
        $mapping->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $mapping->mapping_id );

        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($mapping)
        );
    } catch {
        if ( blessed $_ && $_->isa('Koha::Exceptions::MissingParameter') ) {
            return $c->render(
                status  => 400,
                openapi => { error => $_->error }
            );
        }
        $c->unhandled_exception($_);
    };
}

=head3 update

Update an existing mapping

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $mapping = Koha::ShibbolethFieldMappings->find( $c->param('mapping_id') );

    return $c->render_resource_not_found('Mapping') unless $mapping;

    return try {
        $mapping->set_from_api( $c->req->json )->store;

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($mapping)
        );
    } catch {
        if ( blessed $_ && $_->isa('Koha::Exceptions::MissingParameter') ) {
            return $c->render(
                status  => 400,
                openapi => { error => $_->error }
            );
        }
        $c->unhandled_exception($_);
    };
}

=head3 delete

Delete a mapping

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $mapping = Koha::ShibbolethFieldMappings->find( $c->param('mapping_id') );

    return $c->render_resource_not_found('Mapping') unless $mapping;

    return try {
        $mapping->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
