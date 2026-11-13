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

use C4::Context;
use Koha::DateUtils qw( dt_from_string );
use Koha::Display::Item;
use Koha::Display::Items;
use Koha::Biblios;
use Koha::Displays;
use Koha::Exceptions::REST;
use Koha::Items;

use Try::Tiny qw( catch try );

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

        # Only the items of the displays the user may view
        my $patron = $c->stash('koha.user');
        if ($patron) {
            my @branches = $patron->libraries_where_can_view_displays;
            $displayitems = $displayitems->search(
                {
                    'me.display_id' => {
                        -in => Koha::Displays->search( { display_branch => { -in => \@branches } } )
                            ->_resultset->get_column('display_id')->as_query
                    }
                }
            ) if @branches;
        }

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
        my $displayitem = Koha::Display::Items->search(
            {
                display_id => $c->param('display_id'),
                itemnumber => $c->param('item_id')
            }
        )->next;

        return $c->render_resource_not_found("Display item")
            unless $displayitem;

        _check_access( $c, $displayitem->display, 'view' );

        return $c->render( openapi => $c->objects->to_api($displayitem) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body = $c->req->json;

        my $displayitem = Koha::Display::Item->new_from_api($body);

        # The user must be allowed to edit the display the item is added to
        my $display = Koha::Displays->find( $displayitem->display_id );
        _check_access( $c, $display, 'edit' ) if $display;

        # store() throws Koha::Exceptions::BadParameter (rendered as a 400)
        # when the display or item does not exist or the dates are invalid
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

    my $displayitem = Koha::Display::Items->search(
        {
            display_id => $c->param('display_id'),
            itemnumber => $c->param('item_id')
        }
    )->next;

    return $c->render_resource_not_found("Display item")
        unless $displayitem;

    return try {
        _check_access( $c, $displayitem->display, 'edit' );

        # The URL identifies the display item: the body cannot move it elsewhere
        my $body = $c->req->json;
        $body->{display_id} = $displayitem->display_id;
        $body->{item_id}    = $displayitem->itemnumber;
        $body->{biblio_id}  = $displayitem->biblionumber if exists $body->{biblio_id};

        $displayitem->set_from_api($body);
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

    my $displayitem = Koha::Display::Items->search(
        {
            display_id => $c->param('display_id'),
            itemnumber => $c->param('item_id')
        }
    )->next;

    return $c->render_resource_not_found("Display item")
        unless $displayitem;

    return try {
        _check_access( $c, $displayitem->display, 'edit' );

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
        return $c->render( openapi => [] )
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

        _check_access( $c, $display, 'edit' );

        # Enqueue background job for batch processing
        my $job_id = Koha::BackgroundJob::BatchAddDisplayItems->new->enqueue(
            {
                barcodes    => $body->{barcodes},
                date_added  => $body->{added_date}   // undef,
                date_remove => $body->{removal_date} // undef,
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

Remove multiple items from a display

=cut

sub batch_delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body = $c->req->json;

        my $display = Koha::Displays->find( $body->{display_id} );
        return $c->render_resource_not_found("Display")
            unless $display;

        _check_access( $c, $display, 'edit' );

        # Enqueue background job for batch processing
        my $job_id = Koha::BackgroundJob::BatchDeleteDisplayItems->new->enqueue(
            {
                barcodes   => $body->{barcodes},
                display_id => $body->{display_id},
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

=head3 _check_access

    _check_access( $c, $display, 'edit' );

Throws a 403 (Koha::Exceptions::REST::Public::Unauthorized) if the logged in
user may not perform the action on the display, because of the library
restrictions of their permission. Managing the items of a display requires
being able to edit that display.

=cut

sub _check_access {
    my ( $c, $display, $action ) = @_;

    my $patron = $c->stash('koha.user');
    return unless $patron;

    return if $display->can_be_accessed_by( { patron => $patron, action => $action } );

    Koha::Exceptions::REST::Public::Unauthorized->throw(
        error => "This display exists in a library outside your library group" );
}

1;
