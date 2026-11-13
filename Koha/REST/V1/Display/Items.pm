package Koha::REST::V1::Display::Items;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::DateUtils qw( dt_from_string );
use Koha::Display::Item;
use Koha::Display::Items;
use Koha::Biblios;
use Koha::Displays;
use Koha::Items;

use Try::Tiny    qw( catch try );
use Scalar::Util qw( blessed );

use Koha::BackgroundJob::BatchAddDisplayItems;
use Koha::BackgroundJob::BatchDeleteDisplayItems;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displayitems = Koha::Display::Items->new;
        return $c->render( openapi => $c->objects->search($displayitems) );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displayitems_set = Koha::Display::Items->search(
            {
                display_id => $c->param('display_id'),
                itemnumber => $c->param('item_id')
            }
        )->next;

        return $c->render_resource_not_found("Display item")
            unless $displayitems_set;

        my $displayitem = Koha::Display::Items->find( $displayitems_set->display_item_id );

        return $c->render( openapi => $displayitem->to_api );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displayitem = Koha::Display::Item->new_from_api( $c->req->json );

        # store() declines (returns false) rather than throwing when the display
        # or item is missing, the dates are invalid, or a later addition exists
        my $stored = $displayitem->store;
        return $c->render(
            status  => 400,
            openapi => {
                error      => 'The display item could not be stored',
                error_code => 'display_item_not_stored',
            }
        ) unless $stored && $displayitem->in_storage;

        $c->res->headers->location(
            $c->req->url->to_string . '/' . $displayitem->display_id . '/' . $displayitem->itemnumber );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($displayitem),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $displayitem = Koha::Display::Items->find(
        {
            display_item_id => $c->param('display_item_id'),
            display_id      => $c->param('display_id'),
            itemnumber      => $c->param('item_id')
        }
    );

    return $c->render_resource_not_found("Display item")
        unless $displayitem;

    return try {
        $displayitem->set_from_api( $c->req->json );
        $displayitem->store();
        return $c->render( openapi => $c->objects->to_api($displayitem) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $displayitem = Koha::Display::Items->find(
        {
            display_item_id => $c->param('display_item_id'),
            display_id      => $c->param('display_id'),
            itemnumber      => $c->param('item_id')
        }
    );

    return $c->render_resource_not_found("Display item")
        unless $displayitem;

    return try {
        $displayitem->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 list_public

=cut

sub list_public {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render_resource_not_found("Display item")
            unless C4::Context->preference('UseDisplayModule');

        my $displayitems = $c->objects->search( _public_display_items() );
        return $c->render( openapi => $displayitems );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_public

=cut

sub get_public {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render_resource_not_found("Display item")
            unless C4::Context->preference('UseDisplayModule');

        my $displayitem = _public_display_items()->search(
            {
                'me.display_id' => $c->param('display_id'),
                'me.itemnumber' => $c->param('item_id'),
            }
        )->next;

        return $c->render_resource_not_found("Display item")
            unless $displayitem;

        return $c->render( openapi => $displayitem->to_api );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 _public_display_items

Returns the display items that may be exposed publicly: on an enabled display
that is currently running, not past its removal date, and whose item and
record are not hidden or suppressed in the OPAC.

=cut

sub _public_display_items {
    my $today = dt_from_string()->truncate( to => 'day' )->ymd;

    my $visible_items = Koha::Items->filter_by_visible_in_opac->_resultset->get_column('itemnumber')->as_query;

    my $running_displays = Koha::Displays->search(
        {
            enabled => 1,
            -and    => [
                -or => [ { start_date => undef }, { start_date => { '<=' => $today } } ],
                -or => [ { end_date   => undef }, { end_date   => { '>=' => $today } } ],
            ],
        }
    )->_resultset->get_column('display_id')->as_query;

    my %conditions = (
        'me.display_id' => { -in => $running_displays },
        'me.itemnumber' => { -in => $visible_items },
        -or             => [ { 'me.date_remove' => undef }, { 'me.date_remove' => { '>=' => $today } } ],
    );

    if ( C4::Context->is_opac_suppressed ) {
        $conditions{'me.biblionumber'} =
            { -in =>
                Koha::Biblios->search( { opac_suppressed => 0 } )->_resultset->get_column('biblionumber')->as_query };
    }

    return Koha::Display::Items->search( \%conditions );
}

=head3 batch_add

Add multiple items to a display

=cut

sub batch_add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body = $c->req->json;

        # Validate that display exists
        my $display = Koha::Displays->find( $body->{display_id} );
        return $c->render_resource_not_found("Display")
            unless $display;

        # Enqueue background job for batch processing
        my $job_id = Koha::BackgroundJob::BatchAddDisplayItems->new->enqueue(
            {
                barcodes    => $body->{barcodes},
                date_added  => $body->{date_added}  // undef,
                date_remove => $body->{date_remove} // undef,
                display_id  => $body->{display_id},
            }
        );

        return $c->render(
            status  => 202,
            openapi => {
                job_id  => $job_id,
                message => "Batch add operation queued"
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 batch_delete

Remove multiple items from displays

=cut

sub batch_delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body = $c->req->json;

        # Enqueue background job for batch processing
        my $job_id = Koha::BackgroundJob::BatchDeleteDisplayItems->new->enqueue(
            {
                barcodes   => $body->{barcodes},
                display_id => $body->{display_id} // undef,
            }
        );

        return $c->render(
            status  => 202,
            openapi => {
                job_id  => $job_id,
                message => "Batch delete operation queued"
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
