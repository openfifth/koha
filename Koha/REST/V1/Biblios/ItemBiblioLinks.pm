package Koha::REST::V1::Biblios::ItemBiblioLinks;

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

use C4::Context;

use Koha::AuthorisedValues;
use Koha::Biblios;
use Koha::Item::BiblioLink;
use Koha::Item::BiblioLinks;

use Scalar::Util qw(blessed);
use Try::Tiny;

=head1 NAME

Koha::REST::V1::Biblios::ItemBiblioLinks - Koha REST API for handling links
between items and bibliographic records (V1)

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing the Koha::Item::BiblioLink rows for
a bibliographic record.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return try {
        return $c->render(
            status  => 200,
            openapi => $c->objects->search( $biblio->item_biblio_links ),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles linking an item to a bibliographic record.
Refused with a I<400> when the EnableBoundWithItems system preference is
disabled or the given link_type is not defined in the ITEM_BIBLIO_LINK_TYPE
authorised value category.

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    unless ( C4::Context->preference('EnableBoundWithItems') ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => "The EnableBoundWithItems system preference is disabled",
                error_code => 'feature_disabled',
            }
        );
    }

    return try {
        my $biblio_id = $c->param('biblio_id');
        my $biblio    = Koha::Biblios->find($biblio_id);

        return $c->render_resource_not_found("Bibliographic record")
            unless $biblio;

        my $body = $c->req->json;

        my $valid_link_type = Koha::AuthorisedValues->search(
            {
                category         => 'ITEM_BIBLIO_LINK_TYPE',
                authorised_value => $body->{link_type},
            }
        )->count;

        unless ($valid_link_type) {
            return $c->render(
                status  => 400,
                openapi => {
                    error => "Given link_type is not defined in the ITEM_BIBLIO_LINK_TYPE authorised value category",
                    error_code => 'invalid_link_type',
                }
            );
        }

        $body->{biblio_id} = $biblio_id;

        my $link = Koha::Item::BiblioLink->new_from_api($body);
        $link->store->discard_changes();

        $c->res->headers->location( $c->req->url->to_string . '/' . $link->id );

        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($link),
        );
    } catch {
        if ( blessed($_) ) {

            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 409,
                    openapi => { error => "Item does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
                return $c->render(
                    status  => 409,
                    openapi => { error => "This item is already linked to this bibliographic record" }
                );
            } elsif ( $_->isa('Koha::Exceptions::Item::BiblioLink::SameBiblio') ) {
                return $c->render(
                    status  => 409,
                    openapi =>
                        { error => "The item record already lives on this bibliographic record, no link is needed" }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller function that handles removing a link between an item and a
bibliographic record. Refused with a I<409> when holds exist for the item on
the linked record, unless the I<force> query parameter is passed.

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $link = Koha::Item::BiblioLinks->find(
        {
            id           => $c->param('item_biblio_link_id'),
            biblionumber => $c->param('biblio_id'),
        }
    );

    return $c->render_resource_not_found("Item biblio link")
        unless $link;

    return try {
        $link->delete( { force => $c->param('force') } );
        return $c->render_resource_deleted;
    } catch {
        if ( blessed($_) && $_->isa('Koha::Exceptions::Item::BiblioLink::HoldsExist') ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => "Holds exist for the item on the linked bibliographic record",
                    error_code => 'holds_exist',
                }
            );
        }

        $c->unhandled_exception($_);
    };
}

1;
