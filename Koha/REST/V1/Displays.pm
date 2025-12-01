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

use Koha::Display;
use Koha::Displays;
use Koha::DateUtils qw( dt_from_string );

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 config

Return the configuration options needed for the Display Vue app

=cut

sub config {
    my $c = shift->openapi->valid_input or return;

    my $patron = $c->stash('koha.user');

    return $c->render(
        status  => 200,
        openapi => {
            settings => {
                enabled => C4::Context->preference('UseDisplayModule'),
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

        my $active = $c->param('active');
        if ( defined $active && $active ) {
            $displays_set = $displays_set->active;
        }

        # Filter displays based on user's library permissions
        my $patron = $c->stash('koha.user');
        if ($patron) {
            my @restricted_branchcodes = $patron->libraries_where_can_edit_displays;
            if (@restricted_branchcodes) {

                # User can only see displays from specific libraries
                $displays_set = $displays_set->search( { 'me.display_branch' => { -in => \@restricted_branchcodes } } );
            }

            # If @restricted_branchcodes is empty, user has access to all displays
        }

        my $displays = $c->objects->search($displays_set);
        return $c->render( status => 200, openapi => $displays );
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

        # Check if user has permission to view this display
        my $patron = $c->stash('koha.user');
        if ($patron) {
            my @restricted_branchcodes = $patron->libraries_where_can_edit_displays;
            if (@restricted_branchcodes) {

                # User can only see displays from specific libraries
                unless ( grep { $_ eq $display->display_branch } @restricted_branchcodes ) {
                    return $c->render_resource_not_found("Display");
                }
            }

            # If @restricted_branchcodes is empty, user has access to all displays
        }

        return $c->render( status => 200, openapi => $c->objects->to_api($display), );
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

        my $display_items = delete $body->{display_items} || [];

        my $display = Koha::Display->new_from_api($body)->store;
        $display->display_items($display_items);

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

    my $display = Koha::Displays->find( $c->param('display_id') );

    return $c->render_resource_not_found("Display")
        unless $display;

    return try {
        my $body = $c->req->json;

        my $display_items = delete $body->{display_items} || [];

        $display->set_from_api($body)->store;
        $display->display_items($display_items);

        return $c->render( status => 200, openapi => $c->objects->to_api($display), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $display = Koha::Displays->find( $c->param('display_id') );

    return $c->render_resource_not_found("Display")
        unless $display;

    return try {
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
        my $displays_set = Koha::Displays->new;

        my $active = $c->param('active');
        if ( defined $active && $active ) {
            $displays_set = $displays_set->active;
        } else {
            my $today = dt_from_string->truncate( to => 'day' );
            $displays_set = $displays_set->search(
                {
                    -or => [
                        { end_date => { '>=' => $today } },
                        { end_date => undef }
                    ]
                }
            );
        }

        my $displays = $c->objects->search($displays_set);
        return $c->render( status => 200, openapi => $displays );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_public

=cut

sub get_public {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $display = Koha::Displays->find( $c->param('display_id') );

        return $c->render_resource_not_found("Display")
            unless $display;

        my $today = dt_from_string->truncate( to => 'day' )->ymd;

        if ( $display->end_date && $display->end_date < $today ) {
            return $c->render_resource_not_found("Display");
        }

        return $c->render( status => 200, openapi => $c->objects->to_api($display), );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
