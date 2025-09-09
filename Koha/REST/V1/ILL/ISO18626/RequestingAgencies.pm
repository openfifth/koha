package Koha::REST::V1::ILL::ISO18626::RequestingAgencies;

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

use Koha::ILL::ISO18626::RequestingAgencies;
use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::ILL::ISO18626::RequestingAgencies

=head2 Operations

=head3 list

Controller function that handles listing Koha::ILL::ISO18626::RequestingAgency objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $reqs = $c->objects->search( Koha::ILL::ISO18626::RequestingAgencies->new );
        return $c->render(
            status  => 200,
            openapi => $reqs,
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single Koha::ILL::ISO18626::RequestingAgency object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $iso18626_requesting_agency = $c->objects->find(
            Koha::ILL::ISO18626::RequestingAgencies->search,
            $c->param('iso18626_requesting_agency_id')
        );

        return $c->render_resource_not_found("ISO18626 requesting agency")
            unless $iso18626_requesting_agency;

        return $c->render(
            status  => 200,
            openapi => $iso18626_requesting_agency
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::ILL::ISO18626::RequestingAgency object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                my $requesting_agency = Koha::ILL::ISO18626::RequestingAgency->new_from_api($body)->store;
                $c->res->headers->location(
                    $c->req->url->to_string . '/' . $requesting_agency->iso18626_requesting_agency_id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($requesting_agency),
                );
            }
        );
    } catch {

        my $to_api_mapping = Koha::ILL::ISO18626::RequestingAgency->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
                return $c->render(
                    status  => 409,
                    openapi => { error => $_->error, conflict => $_->duplicate_id }
                );
            } elsif ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->broken_fk } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->parameter } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::ILL::ISO18626::RequestingAgency object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $requesting_agency = Koha::ILL::ISO18626::RequestingAgencies->find( $c->param('iso18626_requesting_agency_id') );

    return $c->render_resource_not_found("ISO18626 requesting agency")
        unless $requesting_agency;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                $requesting_agency->set_from_api($body)->store;
                $c->res->headers->location(
                    $c->req->url->to_string . '/' . $requesting_agency->iso18626_requesting_agency_id );
                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($requesting_agency),
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::ILL::ISO18626::RequestingAgency->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->broken_fk } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->parameter } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $requesting_agency = Koha::ILL::ISO18626::RequestingAgencies->find( $c->param('iso18626_requesting_agency_id') );

    return $c->render_resource_not_found("ISO18626 requesting agency")
        unless $requesting_agency;

    return try {
        $requesting_agency->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
