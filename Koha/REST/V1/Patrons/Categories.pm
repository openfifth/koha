package Koha::REST::V1::Patrons::Categories;

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

use Try::Tiny qw( catch try );

use Koha::Patron::Categories;

=head1 NAME

Koha::REST::V1::Patrons::Categories;

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing Koha::Patron::Category objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render(
            status  => 200,
            openapi => $c->objects->search( Koha::Patron::Categories->search_with_library_limits ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding Koha::Patron::Category objects

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $category = Koha::Patron::Category->new_from_api( $c->req->json );
        $category->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $category->categorycode );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($category),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
