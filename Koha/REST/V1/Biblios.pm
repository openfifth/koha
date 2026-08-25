package Koha::REST::V1::Biblios;

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

use Koha::Biblio::Availability::Hold;
use Koha::Biblios;
use Koha::Item::Availability::Hold;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patrons;
use Koha::Ratings;
use Koha::RecordSources;
use C4::Biblio   qw( DelBiblio AddBiblio ModBiblio );
use C4::Reserves qw( CalculatePriority );
use C4::Search   qw( FindDuplicate );

use C4::Auth qw( haspermission );
use C4::Barcodes::ValueBuilder;
use C4::Context;

use Koha::Items;

use List::MoreUtils qw( any );
use MARC::Record::MiJ;

use Try::Tiny qw( catch try );
use JSON      qw( decode_json );

=head1 API

=head2 Methods

=head3 get

Controller function that handles retrieving a single biblio object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $attributes;
    $attributes = { prefetch => ['metadata'] }    # don't prefetch metadata if not needed
        unless $c->req->headers->accept =~ m/application\/json/;

    my $biblio = Koha::Biblios->find( { biblionumber => $c->param('biblio_id') }, $attributes );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return try {

        if ( $c->req->headers->accept =~ m/application\/json/ ) {
            return $c->render(
                status => 200,
                json   => $c->objects->to_api($biblio),
            );
        } else {
            my $metadata = $biblio->metadata;
            my $record   = $metadata->record;
            my $schema   = $metadata->schema // C4::Context->preference("marcflavour");

            $c->respond_to(
                marcxml => {
                    status => 200,
                    format => 'marcxml',
                    text   => $record->as_xml_record($schema),
                },
                mij => {
                    status => 200,
                    format => 'mij',
                    data   => $record->to_mij
                },
                marc => {
                    status => 200,
                    format => 'marc',
                    text   => $record->as_usmarc
                },
                txt => {
                    status => 200,
                    format => 'text/plain',
                    text   => $record->as_formatted
                },
                any => {
                    status  => 406,
                    openapi => [
                        "application/json",
                        "application/marcxml+xml",
                        "application/marc-in-json",
                        "application/marc",
                        "text/plain"
                    ]
                }
            );
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller function that handles deleting a biblio object

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return try {
        my $error = DelBiblio( $biblio->id );

        if ($error) {
            return $c->render(
                status  => 409,
                openapi => { error => $error }
            );
        } else {
            return $c->render_resource_deleted;
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_public

Controller function that handles retrieving a single biblio object

=cut

sub get_public {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find(
        { biblionumber => $c->param('biblio_id') },
        { prefetch     => ['metadata'] }
    );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return try {

        my $schema = $biblio->metadata->schema // C4::Context->preference("marcflavour");
        my $patron = $c->stash('koha.user');

        # Check if the bibliographic record is suppressed in OPAC
        if ( C4::Context->is_opac_suppressed && $biblio->opac_suppressed ) {
            return $c->render_resource_not_found("Bibliographic record");
        }

        # Check if the bibliographic record should be hidden for unprivileged access
        # unless there's a logged in user, and there's an exception for it's category
        my $opachiddenitems_rules = C4::Context->yaml_preference('OpacHiddenItems');
        unless ( $patron and $patron->category->override_hidden_items ) {
            if ( $biblio->hidden_in_opac( { rules => $opachiddenitems_rules } ) ) {
                return $c->render_resource_not_found("Bibliographic record");
            }
        }

        my $record = $biblio->metadata_record( { interface => 'opac', patron => $patron } );

        $c->respond_to(
            marcxml => {
                status => 200,
                format => 'marcxml',
                text   => $record->as_xml_record($schema),
            },
            mij => {
                status => 200,
                format => 'mij',
                data   => $record->to_mij
            },
            marc => {
                status => 200,
                format => 'marc',
                text   => $record->as_usmarc
            },
            txt => {
                status => 200,
                format => 'text/plain',
                text   => $record->as_formatted
            },
            any => {
                status  => 406,
                openapi => [
                    "application/marcxml+xml",
                    "application/marc-in-json",
                    "application/marc",
                    "text/plain"
                ]
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_bookings

Controller function that handles retrieving biblio's bookings

=cut

sub get_bookings {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( { biblionumber => $c->param('biblio_id') }, { prefetch => ['bookings'] } );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return try {

        my $bookings_rs = $biblio->bookings;
        my $bookings    = $c->objects->search($bookings_rs);
        return $c->render(
            status  => 200,
            openapi => $bookings
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_items

Controller function that handles retrieving biblio's items

=cut

sub get_items {
    my $c = shift->openapi->valid_input or return;

    my $biblio        = Koha::Biblios->find( { biblionumber => $c->param('biblio_id') }, { prefetch => ['items'] } );
    my $bookable_only = $c->param('bookable');

    # Deletion of parameter to avoid filtering on the items table in the case of bookings on 'itemtype'
    $c->req->params->remove('bookable');

    my $group_by_status = $c->param('group_by_status');
    $c->req->params->remove('group_by_status');

    my $holdability = $c->param('holdability');
    my $patron_id   = $c->param('patron_id');
    $c->req->params->remove($_) for qw( holdability patron_id );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    my $patron;

    if ($holdability) {

        unless ($patron_id) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'A patron_id is required to report holdability',
                    error_code => 'missing_patron_id',
                }
            );
        }

        $patron = Koha::Patrons->find($patron_id);

        unless ($patron) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'Patron not found',
                    error_code => 'patron_not_found',
                }
            );
        }
    }

    return try {

        # FIXME We need to order_by serial.publisheddate if we have _order_by=+me.serial_issue_number
        # FIXME Do we always need host_items => 1 or depending on a flag?
        # FIXME Should we prefetch => ['issue','branchtransfer']?
        my $items_rs = $biblio->items( { host_items => 1 } )->search_ordered( {}, { join => 'biblioitem' } );
        $items_rs = $items_rs->filter_by_bookable if $bookable_only;

        if ($group_by_status) {
            my @item_ids;
            for my $status (
                qw( available checked_out local_use in_transit lost withdrawn damaged not_for_loan on_hold recalled in_bundle restricted )
                )
            {
                push @item_ids,
                    $items_rs->search( { _status => $status }, { order_by => { '-asc' => 'me.itemnumber' } } )
                    ->get_column('itemnumber');
            }
            $items_rs = $items_rs->search(
                {},
                {
                    order_by => [ \[ sprintf( "field(me.itemnumber, %s)", join( ', ', map { qq{'$_'} } @item_ids ) ) ] ]
                }
            );
        }

        # FIXME We need to order_by serial.publisheddate if we have _order_by=+me.serial_issue_number
        #
        # Split into the three steps that objects->search makes, so that the
        # item objects for this page are available below. to_api discards them,
        # and refetching them by id would repeat a query already paid for.
        my $paged_items_rs = $c->objects->search_rs($items_rs);
        $c->add_pagination_headers();

        my @item_objects = $paged_items_rs->as_list;
        my $items        = [ map { $c->objects->to_api($_) } @item_objects ];

        _embed_holdability( $c, $biblio, $patron, $items, \@item_objects ) if $holdability;

        return $c->render(
            status  => 200,
            openapi => $items
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 _embed_holdability

    _embed_holdability( $c, $biblio, $patron, $items, $item_objects );

Adds a C<holdability> key to each item hashref in I<$items>, in place.

I<$items> and I<$item_objects> describe the same items in the same order: the
caller built the first by mapping C<to_api> over the second.

Only the items on the requested page are checked. That is what keeps this
endpoint inside its budget: a 500-item record still costs one page's worth of
checks, not five hundred.

The per-record context is read once through
L<Koha::Biblio::Availability::Hold/build_patron_context> and handed to every
item, so the page costs a constant number of queries rather than a few per item.

C<cache_counts> and C<cache_transfers> are safe here because this is a read-only
display loop: nothing places a hold between one item and the next.

=cut

sub _embed_holdability {
    my ( $c, $biblio, $patron, $items, $item_objects ) = @_;

    return unless @{$items};

    my $context = Koha::Biblio::Availability::Hold->build_patron_context( { biblio => $biblio, patron => $patron } );

    my $overrides = $c->stash('koha.overrides');

    for my $index ( 0 .. $#{$items} ) {

        $items->[$index]->{holdability} = Koha::Item::Availability::Hold->check(
            {
                item                     => $item_objects->[$index],
                patron                   => $patron,
                overrides                => $overrides,
                no_short_circuit         => 1,
                skip_patron_count_checks => 1,
                cache_counts             => 1,
                cache_transfers          => 1,
                %{$context},
            }
        )->to_api;
    }

    return;
}

=head3 add_item

Controller function that handles creating a biblio's item

=cut

sub add_item {
    my $c = shift->openapi->valid_input or return;

    try {
        my $biblio_id = $c->param('biblio_id');
        my $biblio    = Koha::Biblios->find($biblio_id);

        return $c->render_resource_not_found("Bibliographic record")
            unless $biblio;

        my $body = $c->req->json;

        $body->{biblio_id} = $biblio_id;

        # Don't save extended subfields yet. To be done in another bug.
        $body->{extended_subfields} = undef;

        my $item = Koha::Item->new_from_api($body);

        if ( !defined $item->barcode ) {

            # FIXME This should be moved to Koha::Item->store
            my $autoBarcode = C4::Context->preference('autoBarcode');
            my $barcode     = '';

            if ( !$autoBarcode || $autoBarcode eq 'OFF' ) {

                #We do nothing
            } elsif ( $autoBarcode eq 'incremental' ) {
                ($barcode) = C4::Barcodes::ValueBuilder::incremental::get_barcode;
            } elsif ( $autoBarcode eq 'annual' ) {
                my $year = Koha::DateUtils::dt_from_string()->year();
                ($barcode) = C4::Barcodes::ValueBuilder::annual::get_barcode( { year => $year } );
            } elsif ( $autoBarcode eq 'hbyymmincr' ) {

                # Generates a barcode where
                #  hb = home branch Code,
                #  yymm = year/month catalogued,
                #  incr = incremental number,
                #  reset yearly -fbcit
                my $now        = Koha::DateUtils::dt_from_string();
                my $year       = $now->year();
                my $month      = $now->month();
                my $homebranch = $item->homebranch // '';
                ($barcode) = C4::Barcodes::ValueBuilder::hbyymmincr::get_barcode( { year => $year, mon => $month } );
                $barcode = $homebranch . $barcode;
            } elsif ( $autoBarcode eq 'EAN13' ) {
                ($barcode) = C4::Barcodes::ValueBuilder::EAN13::get_barcode();
            } else {
                warn "ERROR: unknown autoBarcode: $autoBarcode";
            }
            $item->barcode($barcode) if $barcode;
        }

        $item->store->discard_changes;

        my $base_url = $c->req->url->to_string;
        $base_url =~ s|/biblios/\d+||;
        $c->res->headers->location( $base_url . '/' . $item->id );

        $c->render(
            status  => 201,
            openapi => $c->objects->to_api($item),
        );
    } catch {
        if ( blessed $_ and $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => 'Duplicate barcode.' }
            );
        }
        $c->unhandled_exception($_);
    }
}

=head3 update_item

Controller function that handles updating a biblio's item

=cut

sub update_item {
    my $c = shift->openapi->valid_input or return;

    try {
        my $biblio_id = $c->param('biblio_id');
        my $item_id   = $c->param('item_id');
        my $biblio    = Koha::Biblios->find( { biblionumber => $biblio_id } );

        return $c->render_resource_not_found("Bibliographic record")
            unless $biblio;

        my $item = $biblio->items->find( { itemnumber => $item_id } );

        return $c->render_resource_not_found("Item")
            unless $item;

        my $body = $c->req->json;

        $body->{biblio_id} = $biblio_id;

        # Don't save extended subfields yet. To be done in another bug.
        $body->{extended_subfields} = undef;

        $item->set_from_api($body);

        $item->store->discard_changes;

        $c->render(
            status  => 200,
            openapi => $c->objects->to_api($item),
        );
    } catch {
        if ( blessed $_ and $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => 'Duplicate barcode.' }
            );
        }
        $c->unhandled_exception($_);
    }
}

=head3 get_checkouts

List Koha::Checkout objects

=cut

sub get_checkouts {
    my $c = shift->openapi->valid_input or return;

    my $checked_in = $c->param('checked_in');
    $c->req->params->remove('checked_in');

    try {
        my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

        return $c->render_resource_not_found("Bibliographic record")
            unless $biblio;

        my $checkouts =
            ($checked_in)
            ? $c->objects->search( $biblio->old_checkouts )
            : $c->objects->search( $biblio->current_checkouts );

        return $c->render(
            status  => 200,
            openapi => $checkouts
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 pickup_locations

Method that returns the possible pickup_locations for a given biblio
used for building the dropdown selector

=cut

sub pickup_locations {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    my $patron = Koha::Patrons->find( $c->param('patron_id') );
    $c->req->params->remove('patron_id');

    unless ($patron) {
        return $c->render(
            status  => 400,
            openapi => { error => "Patron not found" }
        );
    }

    return try {

        my $pl_set = $biblio->pickup_locations( { patron => $patron } );

        my @response = ();
        if ( C4::Context->preference('AllowHoldPolicyOverride') ) {

            my $libraries_rs = Koha::Libraries->search( { pickup_location => 1 } );
            my $libraries    = $c->objects->search($libraries_rs);

            @response = map {
                my $library = $_;
                $library->{needs_override} =
                    ( any { $_->branchcode eq $library->{library_id} } @{ $pl_set->as_list } )
                    ? Mojo::JSON->false
                    : Mojo::JSON->true;
                $library;
            } @{$libraries};
        } else {

            my $pickup_locations = $c->objects->search($pl_set);
            @response = map { $_->{needs_override} = Mojo::JSON->false; $_; } @{$pickup_locations};
        }
        @response = map {
            if ( exists $pl_set->{_pickup_location_items}->{ $_->{library_id} }
                && ref $pl_set->{_pickup_location_items}->{ $_->{library_id} } eq 'ARRAY' )
            {
                $_->{pickup_items} = $pl_set->{_pickup_location_items}->{ $_->{library_id} };
            } else {
                $_->{pickup_items} = [];
            }
            $_;
        } @response;

        return $c->render(
            status  => 200,
            openapi => \@response
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 holdability

Controller function that reports whether a patron can place a hold on a record.

=cut

sub holdability {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

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

    my $item_type_id = $c->param('item_type_id');

    # These are read above rather than passed to the query builder, so remove
    # them before any helper that inspects the request parameters runs.
    $c->req->params->remove($_) for qw( patron_id pickup_library_id item_type_id );

    return try {

        my $availability = Koha::Biblio::Availability::Hold->check(
            {
                biblio         => $biblio,
                patron         => $patron,
                pickup_library => $pickup_library,
                overrides      => $c->stash('koha.overrides'),
                ( $item_type_id ? ( item_type_id => $item_type_id ) : () ),

                # Report every blocker rather than the first one, and check
                # every item rather than stopping at the first holdable one.
                # Together these let a single call answer both "can this patron
                # hold this record" and "how many of its items could fill it".
                no_short_circuit => 1,
                summarise_items  => 1,
            }
        );

        my $response = $availability->to_api;

        my $item_results = $availability->context->{item_results} // [];

        $response->{items} = {
            total                  => scalar @{$item_results},
            holdable               => scalar( grep { $_->{available} } @{$item_results} ),
            first_holdable_item_id => $availability->context->{available_item}
            ? $availability->context->{available_item}->itemnumber
            : undef,
        };

        # holds_fee mirrors what reserve/request.pl already does: the fee
        # that would apply is the cheapest holdable item's own hold_fee rule.
        my $available_item = $availability->context->{available_item};
        $response->{hold_fee} =
            $available_item ? ( 0 + ( $available_item->holds_fee($patron) // 0 ) ) : undef;

        # The priority a new hold would take if placed right now.
        $response->{prospective_priority} = CalculatePriority( $biblio->biblionumber );

        return $c->render(
            status  => 200,
            openapi => $response
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 holdability_batch

Controller function that reports holdability for several patrons, or for several
items, in one call.

=cut

sub holdability_batch {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    my $body       = $c->req->json;
    my $patron_ids = $body->{patron_ids};
    my $item_ids   = $body->{item_ids} // [];

    my $pickup_library;

    if ( $body->{pickup_library_id} ) {

        $pickup_library = Koha::Libraries->find( $body->{pickup_library_id} );

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

    my $item_type_id = $body->{item_type_id};

    return try {

        my $overrides = $c->stash('koha.overrides');

        # Fetch the record's items once, however many patrons are checked
        # against them. This is what fetch_items and check()'s items parameter
        # were added for: a club hold asks the same record about every member.
        my @items       = Koha::Biblio::Availability::Hold->fetch_items( $biblio, $item_type_id );
        my %items_by_id = map { $_->itemnumber => $_ } @items;

        my @results;

        for my $patron_id ( @{$patron_ids} ) {

            my $patron = Koha::Patrons->find($patron_id);

            # An unknown id becomes an entry of its own rather than failing the
            # whole request. One stale id in a club must not cost the caller
            # every other verdict it asked for.
            unless ($patron) {
                push @results,
                    {
                    patron_id  => $patron_id,
                    error      => 'Patron not found',
                    error_code => 'patron_not_found',
                    };
                next;
            }

            unless ( @{$item_ids} ) {

                push @results,
                    {
                    patron_id => $patron_id,
                    %{ Koha::Biblio::Availability::Hold->check(
                            {
                                biblio           => $biblio,
                                patron           => $patron,
                                pickup_library   => $pickup_library,
                                overrides        => $overrides,
                                items            => \@items,
                                no_short_circuit => 1,
                                ( $item_type_id ? ( item_type_id => $item_type_id ) : () ),
                            }
                        )->to_api
                    },
                    };

                next;
            }

            # Read the per-record context once for this patron, then reuse it
            # for every item the request named.
            my $context =
                Koha::Biblio::Availability::Hold->build_patron_context( { biblio => $biblio, patron => $patron } );

            for my $item_id ( @{$item_ids} ) {

                my $item = $items_by_id{$item_id};

                unless ($item) {
                    push @results,
                        {
                        patron_id  => $patron_id,
                        item_id    => $item_id,
                        error      => 'Item not found on this bibliographic record',
                        error_code => 'item_not_found',
                        };
                    next;
                }

                push @results,
                    {
                    patron_id => $patron_id,
                    item_id   => $item_id,
                    %{ Koha::Item::Availability::Hold->check(
                            {
                                item             => $item,
                                patron           => $patron,
                                pickup_library   => $pickup_library,
                                overrides        => $overrides,
                                no_short_circuit => 1,
                                cache_counts     => 1,
                                cache_transfers  => 1,
                                %{$context},
                            }
                        )->to_api
                    },
                    };
            }
        }

        # 200, not 201: this reports on the record, it creates nothing.
        return $c->render(
            status  => 200,
            openapi => \@results
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_items_public

Controller function that handles retrieving biblio's items, for unprivileged
access.

=cut

sub get_items_public {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find(
        $c->param('biblio_id'),
        { prefetch => ['items'] }
    );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return try {

        my $patron = $c->stash('koha.user');

        my $items_rs = $biblio->items->filter_by_visible_in_opac( { patron => $patron } );
        my $items    = $c->objects->search($items_rs);
        return $c->render(
            status  => 200,
            openapi => $items
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 set_rating

Set rating for the logged in user

=cut

sub set_rating {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    my $patron = $c->stash('koha.user');
    unless ($patron) {
        return $c->render(
            status  => 403,
            openapi => { error => "Cannot rate. Reason: must be logged-in" }
        );
    }

    my $body         = $c->req->json;
    my $rating_value = $body->{rating};

    return try {

        my $rating = Koha::Ratings->find(
            {
                biblionumber   => $biblio->biblionumber,
                borrowernumber => $patron->borrowernumber,
            }
        );
        $rating->delete if $rating;

        if ($rating_value) {    # Cannot set to 0 from the UI
            $rating = Koha::Rating->new(
                {
                    biblionumber   => $biblio->biblionumber,
                    borrowernumber => $patron->borrowernumber,
                    rating_value   => $rating_value,
                }
            )->store;
        }
        my $ratings = Koha::Ratings->search( { biblionumber => $biblio->biblionumber } );
        my $average = $ratings->get_avg_rating;

        return $c->render(
            status  => 200,
            openapi => {
                rating  => $rating && $rating->in_storage ? $rating->rating_value : undef,
                average => $average,
                count   => $ratings->count
            },
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles creating a biblio object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    try {
        my $headers = $c->req->headers;

        my $flavour = $headers->header('x-record-schema');
        $flavour //= C4::Context->preference('marcflavour');

        my $record_source_id = $headers->header('x-record-source-id');

        if ($record_source_id) {

            # We've been passed a record source. Verify they are allowed to
            unless ( haspermission( $c->stash('koha.user')->userid, { editcatalogue => 'set_record_sources' } ) ) {
                return $c->render(
                    status  => 403,
                    openapi => { error => 'You do not have permission to set the record source' }
                );
            }
        }

        my $record;

        my $frameworkcode = $headers->header('x-framework-id');
        my $content_type  = $headers->content_type;

        if ( $content_type =~ m/application\/marcxml\+xml/ ) {
            $record = MARC::Record->new_from_xml( $c->req->body, 'UTF-8', $flavour );
        } elsif ( $content_type =~ m/application\/marc-in-json/ ) {
            $record = MARC::Record->new_from_mij_structure( $c->req->json );
        } elsif ( $content_type =~ m/application\/marc/ ) {
            $record = MARC::Record->new_from_usmarc( $c->req->body );
        } else {
            return $c->render(
                status  => 406,
                openapi => [
                    "application/marcxml+xml",
                    "application/marc-in-json",
                    "application/marc"
                ]
            );
        }

        my $confirm_not_duplicate = $headers->header('x-confirm-not-duplicate');

        if ( !$confirm_not_duplicate ) {
            my ( $duplicatebiblionumber, $duplicatetitle ) = FindDuplicate($record);

            return $c->render(
                status  => 400,
                openapi => {
                    error => "Duplicate biblio $duplicatebiblionumber",
                }
            ) if $duplicatebiblionumber;
        }

        my ($biblio_id) = C4::Biblio::AddBiblio( $record, $frameworkcode, { record_source_id => $record_source_id } );

        if ( !$biblio_id ) {

            # FIXME: AddBiblio wraps everything inside a transaction and a try/catch block
            # this will need a tweak if this behavior changes
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'Error creating record',
                    error_code => 'record_creation_failed',
                },
            );
        }

        $c->res->headers->location( $c->req->url->to_string . '/' . $biblio_id );

        return $c->render(
            status  => 200,
            openapi => { id => $biblio_id }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles modifying an biblio object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->param('biblio_id') );

    return $c->render_resource_not_found("Bibliographic record")
        unless $biblio;

    return $c->render(
        status  => 403,
        openapi => { error => 'You do not have permission to edit a locked record' }
    ) unless ( $biblio->can_be_edited( $c->stash('koha.user') ) );

    try {
        my $headers = $c->req->headers;

        my $flavour = $headers->header('x-record-schema');
        $flavour //= C4::Context->preference('marcflavour');

        my $frameworkcode = $headers->header('x-framework-id') || $biblio->frameworkcode;

        my $content_type = $headers->content_type;

        my $record;

        if ( $content_type =~ m/application\/marcxml\+xml/ ) {
            $record = MARC::Record->new_from_xml( $c->req->body, 'UTF-8', $flavour );
        } elsif ( $content_type =~ m/application\/marc-in-json/ ) {
            $record = MARC::Record->new_from_mij_structure( $c->req->json );
        } elsif ( $content_type =~ m/application\/marc/ ) {
            $record = MARC::Record->new_from_usmarc( $c->req->body );
        } else {
            return $c->render(
                status  => 406,
                openapi => [
                    "application/json",
                    "application/marcxml+xml",
                    "application/marc-in-json",
                    "application/marc"
                ]
            );
        }

        my $record_source_id = $headers->header('x-record-source-id');

        my $options = {
            overlay_context => {
                userid       => $c->stash('koha.user')->userid,
                categorycode => $c->stash('koha.user')->categorycode,
            }
        };

        if ($record_source_id) {

            # We've been passed a record source. Verify they are allowed to
            unless (
                haspermission(
                    $c->stash('koha.user')->userid,
                    { editcatalogue => 'set_record_sources' }
                )
                )
            {
                return $c->render(
                    status  => 403,
                    openapi => { error => 'You do not have permission to set the record source' }
                );
            }

            # find record source name to given id
            my $record_source = Koha::RecordSources->search( { record_source_id => $record_source_id } )->single;

            unless ($record_source) {
                return $c->render(
                    status  => 409,
                    openapi => { error => 'Given record_source_id does not exist' }
                );
            }

            $options->{'overlay_context'}->{'source'} = $record_source->name;

            # this will update the record source id in biblio metadata
            $options->{'record_source_id'} = $record_source_id;
        }

        unless ( $options->{'overlay_context'}->{'source'} ) {
            $options->{'overlay_context'}->{source} = '*';
        }

        ModBiblio( $record, $biblio->id, $frameworkcode, $options );

        $c->render(
            status  => 200,
            openapi => { id => $biblio->id }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 list

Controller function that handles retrieving a single biblio object

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my @prefetch = qw(biblioitem);
    push @prefetch, 'metadata'    # don't prefetch metadata if not needed
        unless $c->req->headers->accept =~ m/application\/json/;

    my $rs      = Koha::Biblios->search( undef, { prefetch => \@prefetch } );
    my $biblios = $c->objects->search_rs( $rs, [ ( sub { $rs->api_query_fixer( $_[0], '', $_[1] ) } ) ] );

    return try {

        if ( $c->req->headers->accept =~ m/application\/json(;.*)?$/ ) {
            return $c->render(
                status => 200,
                json   => $c->objects->to_api($biblios),
            );
        } elsif ( $c->req->headers->accept =~ m/application\/marcxml\+xml(;.*)?$/ ) {
            $c->res->headers->add( 'Content-Type', 'application/marcxml+xml' );
            return $c->render(
                status => 200,
                text   => $biblios->print_collection('marcxml')
            );
        } elsif ( $c->req->headers->accept =~ m/application\/marc-in-json(;.*)?$/ ) {
            $c->res->headers->add( 'Content-Type', 'application/marc-in-json' );
            return $c->render(
                status => 200,
                data   => $biblios->print_collection('mij')
            );
        } elsif ( $c->req->headers->accept =~ m/application\/marc(;.*)?$/ ) {
            $c->res->headers->add( 'Content-Type', 'application/marc' );
            return $c->render(
                status => 200,
                text   => $biblios->print_collection('marc')
            );
        } elsif ( $c->req->headers->accept =~ m/text\/plain(;.*)?$/ ) {
            return $c->render(
                status => 200,
                text   => $biblios->print_collection('txt')
            );
        } else {
            return $c->render(
                status  => 406,
                openapi => [
                    "application/json",         "application/marcxml+xml",
                    "application/marc-in-json", "application/marc",
                    "text/plain"
                ]
            );
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 merge

Controller function that handles merging two biblios. If an optional
MARCXML is provided as the request body, this MARCXML replaces the
bibliodata of the merge target biblio. Syntax format inside the request body
must match with the Marc format used into Koha installation (MARC21 or UNIMARC)

=cut

sub merge {
    my $c                = shift->openapi->valid_input or return;
    my $ref_biblionumber = $c->param('biblio_id');
    my $json             = decode_json( $c->req->body );
    my $bn_merge         = $json->{'biblio_id_to_merge'};
    my $framework        = $json->{'framework_to_use'} // q{};
    my $rules            = $json->{'rules'} || q{override};
    my $override_rec     = $json->{'datarecord'} // q{};

    my $biblio = Koha::Biblios->find($ref_biblionumber);
    if ( not defined $biblio ) {
        return $c->render(
            status => 404,
            json   => { error => sprintf( "[%s] biblio to merge into not found", $ref_biblionumber ) }
        );
    }
    my $frombib = Koha::Biblios->find($bn_merge);
    if ( not defined $frombib ) {
        return $c->render(
            status => 404,
            json   => { error => sprintf( "[%s] from which to merge not found", $bn_merge ) }
        );
    }

    if ( ( $rules eq 'override_ext' ) && ( $override_rec eq '' ) ) {
        return $c->render(
            status => 404,
            json   => {
                error =>
                    "With the rule 'override_ext' you need to insert a bib record in marc-in-json format into 'record' field."
            }
        );
    }

    if ( ( $rules eq 'override' ) && ( $framework ne '' ) ) {
        return $c->render(
            status => 404,
            json   => { error => "With the rule 'override' you can not use the field 'framework_to_use'." }
        );
    }

    return try {
        if ( $rules eq 'override_ext' ) {
            my $record = MARC::Record::MiJ->new_from_mij_structure($override_rec);
            $record->encoding('UTF-8');
            $framework ||= $biblio->frameworkcode;
            my $chk = ModBiblio( $record, $ref_biblionumber, $framework );
            if ( $chk != 1 ) { die "Error on ModBiblio"; }    # ModBiblio returns 1 if everything as gone well
        }

        $biblio->merge_with( [$bn_merge] );

        $c->respond_to(
            mij => {
                status => 200,
                format => 'mij',
                data   => $biblio->metadata->record->to_mij
            }
        );
    } catch {
        $c->render( status => 400, json => { error => $@ } );
    };
}

1;
