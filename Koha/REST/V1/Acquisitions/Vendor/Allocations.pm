package Koha::REST::V1::Acquisitions::Vendor::Allocations;

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

use Scalar::Util qw( blessed );

use Koha::Acquisition::Booksellers;
use Koha::Acquisition::VendorAllocation;

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::Acquisitions::Vendor::Allocations

=head1 API

=head2 Class methods

=head3 list

Return the list of allocations for a given vendor

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $vendor = Koha::Acquisition::Booksellers->find( $c->param('vendor_id') );

        return $c->render_resource_not_found("Vendor")
            unless $vendor;

        my $allocations_rs = $vendor->vendor_allocations;
        my $allocations    = $c->objects->search($allocations_rs);

        return $c->render(
            status  => 200,
            openapi => $allocations,
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Return a single vendor allocation

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $vendor = Koha::Acquisition::Booksellers->find( $c->param('vendor_id') );

        return $c->render_resource_not_found("Vendor")
            unless $vendor;

        my $allocation = $vendor->vendor_allocations->find( $c->param('allocation_id') );

        return $c->render_resource_not_found("Vendor allocation")
            unless $allocation;

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($allocation),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Add a vendor allocation

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $vendor = Koha::Acquisition::Booksellers->find( $c->param('vendor_id') );

        return $c->render_resource_not_found("Vendor")
            unless $vendor;

        my $body = $c->req->json;
        $body->{vendor_id} = $vendor->id;

        my $allocation = Koha::Acquisition::VendorAllocation->new_from_api($body)->store;

        $c->res->headers->location( $c->req->url->to_string . '/' . $allocation->id );

        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($allocation),
        );
    } catch {
        if ( blessed $_ && $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => "An allocation already exists for this vendor and budget period" },
            );
        }
        $c->unhandled_exception($_);
    };
}

=head3 update

Update a vendor allocation

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $vendor = Koha::Acquisition::Booksellers->find( $c->param('vendor_id') );

        return $c->render_resource_not_found("Vendor")
            unless $vendor;

        my $allocation = $vendor->vendor_allocations->find( $c->param('allocation_id') );

        return $c->render_resource_not_found("Vendor allocation")
            unless $allocation;

        my $body = $c->req->json;
        $allocation->set_from_api($body)->store;

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($allocation),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Delete a vendor allocation

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $vendor = Koha::Acquisition::Booksellers->find( $c->param('vendor_id') );

        return $c->render_resource_not_found("Vendor")
            unless $vendor;

        my $allocation = $vendor->vendor_allocations->find( $c->param('allocation_id') );

        return $c->render_resource_not_found("Vendor allocation")
            unless $allocation;

        $allocation->delete;

        return $c->render( status => 204, openapi => q{} );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
