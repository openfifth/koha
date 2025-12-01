package Koha::REST::V1::DisplayItems;

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
use Koha::DisplayItem;
use Koha::DisplayItems;
use Koha::Displays;

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
        my $displayitems = Koha::DisplayItems->new;
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
        my $displayitems_set = Koha::DisplayItems->search(
            {
                display_item_id => $c->param('display_item_id'),
                display_id      => $c->param('display_id'),
                itemnumber      => $c->param('item_id')
            }
        )->next;

        return $c->render_resource_not_found("Display item")
            unless $displayitems_set;

        my $displayitem = Koha::DisplayItems->find( $displayitems_set->display_item_id );

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
        my $displayitem = Koha::DisplayItem->new_from_api( $c->req->json );
        $displayitem->store;
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

    my $displayitem = Koha::DisplayItems->find(
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

    my $displayitem = Koha::DisplayItems->find(
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

        my $today = dt_from_string()->truncate( to => 'day' )->ymd;

        my $displayitems_set = Koha::DisplayItems->search(
            {
                'display.enabled' => 1,
                -and              => [
                    -or => [ { 'display.start_date' => undef }, { 'display.start_date' => { '<=' => $today } } ],
                    -or => [ { 'display.end_date'   => undef }, { 'display.end_date'   => { '>=' => $today } } ],
                ],
                -or => [ { 'me.date_remove' => undef }, { 'me.date_remove' => { '>=' => $today } } ],
            },
            { join => 'display' }
        );

        my $displayitems = $c->objects->search($displayitems_set);
        return $c->render( openapi => $displayitems_set );
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

        my $today = dt_from_string->truncate( to => 'day' )->ymd;

        my $displayitems_set = Koha::DisplayItems->search(
            {
                'me.display_id'   => $c->param('display_id'),
                'me.itemnumber'   => $c->param('item_id'),
                'display.enabled' => 1,
                -and              => [
                    -or => [ { 'display.start_date' => undef }, { 'display.start_date' => { '<=' => $today } } ],
                    -or => [ { 'display.end_date'   => undef }, { 'display.end_date'   => { '>=' => $today } } ],
                ],
                -or => [ { 'me.date_remove' => undef }, { 'me.date_remove' => { '>=' => $today } } ],
            },
            { join => 'display' }
        )->next;

        return $c->render_resource_not_found("Display item")
            unless $displayitems_set;

        my $displayitem = Koha::DisplayItems->find( $displayitems_set->display_item_id );

        return $c->render( openapi => $displayitem->to_api );
    } catch {
        $c->unhandled_exception($_);
    };
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
