package Koha::REST::V1::Items;

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

use C4::Circulation qw( barcodedecode );

use Koha::Item::Availability::Hold;
use Koha::Items;
use Koha::Libraries;
use Koha::Patrons;

use List::MoreUtils qw( any );
use Try::Tiny       qw( catch try );

=head1 NAME

Koha::REST::V1::Items - Koha REST API for handling items (V1)

=head1 API

=head2 Methods

=cut

=head3 list

Controller function that handles listing Koha::Item objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $items_set = Koha::Items->new;
        my $items     = $c->objects->search($items_set);
        return $c->render(
            status  => 200,
            openapi => $items
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 list_public

Controller function that handles listing Koha::Item objects available to the opac

=cut

sub list_public {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron = $c->stash('koha.user');

        my $items_set = Koha::Items->filter_by_visible_in_opac( { patron => $patron } );
        my $items     = $c->objects->search($items_set);

        return $c->render(
            status  => 200,
            openapi => $items
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single Koha::Item

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    try {
        my $items_rs = Koha::Items->new;
        my $item     = $c->objects->find( $items_rs, $c->param('item_id') );

        return $c->render_resource_not_found("Item")
            unless $item;

        return $c->render( status => 200, openapi => $item );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller function that handles deleting a single Koha::Item

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $item = Koha::Items->find( $c->param('item_id') );

        return $c->render_resource_not_found("Item")
            unless $item;

        my $safe_to_delete = $item->safe_to_delete;

        if ( !$safe_to_delete ) {

            # Pick the first error, if any
            my ($error) = grep { $_->type eq 'error' } @{ $safe_to_delete->messages };

            unless ($error) {
                Koha::Exception->throw('Koha::Item->safe_to_delete returned false but carried no error message');
            }

            my $errors = {
                book_on_loan  => { code => 'checked_out', description => 'The item is checked out' },
                book_reserved => { code => 'found_hold',  description => 'Waiting or in-transit hold for the item' },
                last_item_for_hold => {
                    code        => 'last_item_for_hold',
                    description => 'The item is the last one on a record on which a biblio-level hold is placed'
                },
                linked_analytics =>
                    { code => 'linked_analytics', description => 'The item has linked analytic records' },
                not_same_branch =>
                    { code => 'not_same_branch', description => 'The item is blocked by independent branches' },
                item_has_holds => { code => 'item_has_holds', description => 'The item has item level holds' },
            };

            if ( any { $error->message eq $_ } keys %{$errors} ) {

                my $code = $error->message;

                return $c->render(
                    status  => 409,
                    openapi => {
                        error      => $errors->{$code}->{description},
                        error_code => $errors->{$code}->{code},
                    }
                );
            } else {
                Koha::Exception->throw(
                    'Koha::Patron->safe_to_delete carried an unexpected message: ' . $error->message );
            }
        }

        $item->safe_delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_bookings

Controller function that handles retrieving item's bookings

=cut

sub get_bookings {
    my $c = shift->openapi->valid_input or return;

    my $item = Koha::Items->find( { itemnumber => $c->param('item_id') }, { prefetch => ['bookings'] } );

    return $c->render_resource_not_found("Item")
        unless $item;

    return try {

        my $bookings_rs = $item->bookings;
        my $bookings    = $c->objects->search($bookings_rs);
        return $c->render(
            status  => 200,
            openapi => $bookings
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 pickup_locations

Method that returns the possible pickup_locations for a given item
used for building the dropdown selector

=cut

sub pickup_locations {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->param('item_id');
    my $item    = Koha::Items->find($item_id);

    return $c->render_resource_not_found("Item")
        unless $item;

    my $patron_id = $c->param('patron_id');
    my $patron    = Koha::Patrons->find($patron_id);

    $c->req->params->remove('patron_id');

    unless ($patron) {
        return $c->render(
            status  => 400,
            openapi => { error => "Patron not found" }
        );
    }

    return try {

        my $pl_set = $item->pickup_locations( { patron => $patron } );

        return $c->render(
            status  => 200,
            openapi => _pickup_locations_response( $c, $pl_set )
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 _pickup_locations_response

    my $libraries = _pickup_locations_response( $c, $pl_set );

Builds the pickup locations list that the API returns, from the
I<Koha::Libraries> set that C<< $item->pickup_locations >> gives back.

Every library in the response carries a C<needs_override> flag. When
C<AllowHoldPolicyOverride> is off, the response holds only the valid pickup
locations, and the flag is always false. When the preference is on, the response
holds every pickup location in the system, and the flag marks the ones that the
circulation rules do not permit. The staff interface uses the flag to show those
libraries as a choice that needs an override.

Shared by C<pickup_locations> and C<holdability>.

=cut

sub _pickup_locations_response {
    my ( $c, $pl_set ) = @_;

    if ( C4::Context->preference('AllowHoldPolicyOverride') ) {

        my $libraries_rs = Koha::Libraries->search( { pickup_location => 1 } );
        my $libraries    = $c->objects->search($libraries_rs);

        return [
            map {
                my $library = $_;
                $library->{needs_override} =
                    ( any { $_->branchcode eq $library->{library_id} } @{ $pl_set->as_list } )
                    ? Mojo::JSON->false
                    : Mojo::JSON->true;
                $library;
            } @{$libraries}
        ];
    }

    my $pickup_locations = $c->objects->search($pl_set);

    return [ map { $_->{needs_override} = Mojo::JSON->false; $_; } @{$pickup_locations} ];
}

=head3 holdability

Controller function that reports whether a patron can place a hold on an item.

=cut

sub holdability {
    my $c = shift->openapi->valid_input or return;

    my $item = Koha::Items->find( $c->param('item_id') );

    return $c->render_resource_not_found("Item")
        unless $item;

    my $patron = Koha::Patrons->find( $c->param('patron_id') );

    unless ($patron) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => 'Patron not found',
                error_code => 'patron_not_found',
            }
        );
    }

    my $pickup_library;
    my $pickup_library_id = $c->param('pickup_library_id');

    if ($pickup_library_id) {

        $pickup_library = Koha::Libraries->find($pickup_library_id);

        unless ($pickup_library) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'Library not found',
                    error_code => 'library_not_found',
                }
            );
        }
    }

    my $include_pickup_locations = $c->param('include_pickup_locations');

    # These are read above rather than passed to the query builder, so remove
    # them before any helper that inspects the request parameters runs.
    $c->req->params->remove($_) for qw( patron_id pickup_library_id include_pickup_locations );

    return try {

        my $availability = Koha::Item::Availability::Hold->check(
            {
                item             => $item,
                patron           => $patron,
                pickup_library   => $pickup_library,
                overrides        => $c->stash('koha.overrides'),
                no_short_circuit => 1,
            }
        );

        my $response = $availability->to_api;

        if ($include_pickup_locations) {
            $response->{pickup_locations} =
                _pickup_locations_response( $c, $item->pickup_locations( { patron => $patron } ) );
        }

        return $c->render(
            status  => 200,
            openapi => $response
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 bundled_items

Controller function that handles bundled_items Koha::Item objects

=cut

sub bundled_items {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->param('item_id');
    my $item    = Koha::Items->find($item_id);

    return $c->render_resource_not_found("Item")
        unless $item;

    return try {
        my $items_set = Koha::Items->search(
            {
                'item_bundles_item.host' => $item_id,
            },
            {
                join => 'item_bundles_item',
            }
        );
        my $items = $c->objects->search($items_set);
        return $c->render(
            status  => 200,
            openapi => $items
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add_to_bundle

Controller function that handles adding items to this bundle

=cut

sub add_to_bundle {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->param('item_id');
    my $item    = Koha::Items->find($item_id);

    return $c->render_resource_not_found("Item")
        unless $item;

    my $body = $c->req->json;

    my $bundle_item_id = $body->{'external_id'};
    $bundle_item_id = barcodedecode($bundle_item_id);
    my $bundle_item = Koha::Items->find( { barcode => $bundle_item_id } );

    return $c->render_resource_not_found("Bundle item")
        unless $bundle_item;

    my $add_link = $body->{'marc_link'} // 0;
    return try {
        my $options = {
            force_checkin => $body->{force_checkin},
            ignore_holds  => $body->{ignore_holds},
        };

        my $link = $item->add_to_bundle( $bundle_item, $options );
        if ($add_link) {
            $bundle_item->biblio->link_marc_host( { host => $item->biblio } );
        }
        return $c->render(
            status  => 201,
            openapi => $bundle_item->to_api
        );
    } catch {
        if ( ref($_) eq 'Koha::Exceptions::Object::DuplicateID' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'Item is already bundled',
                    error_code => 'already_bundled',
                    key        => $_->duplicate_id
                }
            );
        } elsif ( ref($_) eq 'Koha::Exceptions::Item::Bundle::BundleIsCheckedOut' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'Bundle is checked out',
                    error_code => 'bundle_checked_out'
                }
            );
        } elsif ( ref($_) eq 'Koha::Exceptions::Item::Bundle::ItemIsCheckedOut' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'Item is checked out',
                    error_code => 'checked_out'
                }
            );
        } elsif ( ref($_) eq 'Koha::Exceptions::Checkin::FailedCheckin' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'Item cannot be checked in',
                    error_code => 'failed_checkin'
                }
            );
        } elsif ( ref($_) eq 'Koha::Exceptions::Item::Bundle::ItemHasHolds' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'Item is reserved',
                    error_code => 'reserved'
                }
            );
        } elsif ( ref($_) eq 'Koha::Exceptions::Item::Bundle::IsBundle' ) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'Bundles cannot be nested',
                    error_code => 'failed_nesting'
                }
            );
        } else {
            $c->unhandled_exception($_);
        }
    };
}

=head3 remove_from_bundle

Controller function that handles removing items from this bundle

=cut

sub remove_from_bundle {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->param('item_id');
    my $item    = Koha::Items->find($item_id);

    return $c->render_resource_not_found("Item")
        unless $item;

    my $bundle_item_id = $c->param('bundled_item_id');
    $bundle_item_id = barcodedecode($bundle_item_id);
    my $bundle_item = Koha::Items->find( { itemnumber => $bundle_item_id } );

    return $c->render_resource_not_found("Bundle item")
        unless $bundle_item;

    return try {
        $bundle_item->remove_from_bundle;
        return $c->render_resource_deleted;
    } catch {
        if ( ref($_) eq 'Koha::Exceptions::Item::Bundle::BundleIsCheckedOut' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'Bundle is checked out',
                    error_code => 'bundle_checked_out'
                }
            );
        } else {
            $c->unhandled_exception($_);
        }
    };
}

1;
