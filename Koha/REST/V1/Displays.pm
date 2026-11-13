package Koha::REST::V1::Displays;

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

use C4::Auth qw( haspermission );
use C4::Context;
use Koha::Database;
use Koha::Display;
use Koha::Displays;
use Koha::Exceptions::REST;
use Koha::DateUtils qw( dt_from_string );

use JSON;
use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 config

Return the configuration options needed for the Display Vue app

=cut

sub config {
    my $c = shift->openapi->valid_input or return;

    my $patron      = $c->stash('koha.user');
    my $userflags   = haspermission( $patron->userid );
    my $permissions = Koha::Auth::Permissions->get_authz_from_flags( { flags => $userflags } );

    return $c->render(
        status  => 200,
        openapi => {
            settings => {
                permissions => $permissions,
                enabled     => scalar C4::Context->preference('UseDisplayModule') ? JSON::true : JSON::false,
            },
        },
    );
}

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $displays_set = Koha::Displays->new;

        # Filter displays based on user's library permissions
        my $patron = $c->stash('koha.user');
        if ($patron) {
            my @restricted_branchcodes = $patron->libraries_where_can_view_displays;

            # If @restricted_branchcodes is empty, user has access to all displays
            $displays_set = $displays_set->search( { 'me.display_branch' => { -in => \@restricted_branchcodes } } )
                if @restricted_branchcodes;
        }

        my $displays = $c->objects->search($displays_set);
        return $c->render( openapi => $displays );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $display = Koha::Displays->find( $c->param('display_id') );
        return $c->render_resource_not_found("Display")
            unless $display;

        _check_access( $c, $display, 'view' );

        return $c->render( openapi => $c->objects->to_api($display), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my ( $body, $display_items ) = _writable_body($c);

        my $display = Koha::Display->new_from_api($body);

        # Check everything before anything is written to the database
        _check_access( $c, $display, 'add' );
        _check_can_manage_display_items($c) if $display_items;

        Koha::Database->new->schema->txn_do(
            sub {
                $display->store;
                $display->display_items($display_items) if $display_items;
            }
        );

        $c->res->headers->location( $c->req->url->to_string . '/' . $display->display_id );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($display),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    return try {
        my ( $body, $display_items ) = _writable_body($c);

        my $display = Koha::Displays->find( $c->param('display_id') );
        return $c->render_resource_not_found("Display")
            unless $display;

        # The display must be editable as it is now...
        _check_access( $c, $display, 'edit' );
        _check_can_manage_display_items($c) if $display_items;

        $display->set_from_api($body);

        # ...and as it will be, so it cannot be moved out of the user's libraries
        _check_access( $c, $display, 'edit' );

        Koha::Database->new->schema->txn_do(
            sub {
                $display->store;
                $display->display_items($display_items) if $display_items;
            }
        );

        return $c->render( openapi => $c->objects->to_api($display), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $display = Koha::Displays->find( $c->param('display_id') );
        return $c->render_resource_not_found("Display")
            unless $display;

        _check_access( $c, $display, 'delete' );

        $display->delete;
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

        my $today = dt_from_string->truncate( to => 'day' )->ymd;

        my $displays_set = Koha::Displays->search(
            {
                'me.enabled' => 1,
                -and         => [
                    -or => [ { 'me.start_date' => undef }, { 'me.start_date' => { '<=' => $today } } ],
                    -or => [ { 'me.end_date'   => undef }, { 'me.end_date'   => { '>=' => $today } } ],
                ],
            }
        );

        my $displays = $c->objects->search($displays_set);
        return $c->render( openapi => $displays );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_public

=cut

sub get_public {
    my $c = shift->openapi->valid_input or return;

    return try {
        return $c->render_resource_not_found("Display")
            unless C4::Context->preference('UseDisplayModule');

        my $today = dt_from_string->truncate( to => 'day' )->ymd;

        my $display = Koha::Displays->search(
            {
                'me.display_id' => $c->param('display_id'),
                'me.enabled'    => 1,
                -and            => [
                    -or => [ { 'me.start_date' => undef }, { 'me.start_date' => { '<=' => $today } } ],
                    -or => [ { 'me.end_date'   => undef }, { 'me.end_date'   => { '>=' => $today } } ],
                ],
            }
        )->next;

        return $c->render_resource_not_found("Display")
            unless $display;

        return $c->render( openapi => $c->objects->to_api($display), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 _check_access

    _check_access( $c, $display, 'edit' );

Throws a 403 (Koha::Exceptions::REST::Public::Unauthorized) if the logged in
user may not perform the action on the display, because of the library
restrictions of their permission.

=cut

sub _check_access {
    my ( $c, $display, $action ) = @_;

    my $patron = $c->stash('koha.user');
    return unless $patron;

    return if $display->can_be_accessed_by( { patron => $patron, action => $action } );

    Koha::Exceptions::REST::Public::Unauthorized->throw(
        error => "This display exists in a library outside your library group" );
}

=head3 _check_can_manage_display_items

Throws a 403 unless the logged in user has the manage_display_items permission.

=cut

sub _check_can_manage_display_items {
    my ($c) = @_;

    return if haspermission( $c->stash('koha.user')->userid, { displays => 'manage_display_items' } );

    Koha::Exceptions::REST::Public::Unauthorized->throw(
        error => "You do not have permission to manage display items" );
}

=head3 _writable_body

    my ( $body, $display_items ) = _writable_body($c);

Returns the request body without the embedded objects, which a client sends
back when it sends what it received (the read-only C<active> and C<display_id>
are already refused by the OpenAPI validation). The display items are returned
separately.

=cut

sub _writable_body {
    my ($c) = @_;

    my $body          = $c->req->json;
    my $display_items = delete $body->{display_items} || undef;
    delete @{$body}{qw( display_library home_library holding_library item_type _strings )};

    return ( $body, $display_items );
}

1;
