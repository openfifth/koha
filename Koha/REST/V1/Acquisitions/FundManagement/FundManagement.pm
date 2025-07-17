package Koha::REST::V1::Acquisitions::FundManagement::FundManagement;

# Copyright 2025 Open Fifth

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json);
use Try::Tiny;

use C4::Context;

use Koha::Acquisition::FundManagement::BaseObjects;

=head1 API

=head2 Methods

=head3 config

=cut

sub config {
    my $c = shift->openapi->valid_input or return;

    my $patron      = $c->stash('koha.user');
    my $userflags   = C4::Auth::getuserflags( $patron->flags, $patron->id );
    my $permissions = Koha::Auth::Permissions->get_authz_from_flags( { flags => $userflags } );

    return $c->render(
        status  => 200,
        openapi => {
            permissions => $permissions,
        },
    );
}

=head3 list_users

Return the list of possible fund management users

=cut

sub list_users {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $query = decode_json( $c->req->param('q') );
        $c->req->params->remove('q');

        my $patrons_rs = Koha::Patrons->search->filter_by_have_permission( $query->{permission} );
        my $patrons    = $c->objects->search($patrons_rs);

        my $lib_group_visibility = $query->{lib_group_visibility};
        if ( defined $lib_group_visibility ) {
            $patrons = Koha::Acquisition::FundManagement::BaseObjects->filter_by_library_group_based_on_branchcode(
                {
                    lib_group_visibility => $lib_group_visibility,
                    objects              => $patrons,
                    match_field          => 'library_id',
                }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $patrons
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
