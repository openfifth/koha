package Koha::REST::V1::Overdues;

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

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::Overdues

=head1 API

=head2 Class methods

=head3 config

Return the configuration options needed for the Overdues Vue app

=cut

sub config {
    my $c = shift->openapi->valid_input or return;
    return $c->render(
        status  => 200,
        openapi => {
            settings => {
                IntranetBiblioDefaultView => C4::Context->preference('IntranetBiblioDefaultView'),
                ClaimReturnedLostValue    => C4::Context->preference('ClaimReturnedLostValue'),
                viewMARC                  => C4::Context->preference('viewMARC'),
                viewLabelledMARC          => C4::Context->preference('viewLabelledMARC'),
                viewISBD                  => C4::Context->preference('viewISBD'),
                marcflavour               => C4::Context->preference('marcflavour'),
                'item-level_itypes'       => C4::Context->preference('item-level_itypes'),
                library_id                => C4::Context->userenv->{'branch'},
                FilterBeforeOverdueReport => C4::Context->preference('FilterBeforeOverdueReport') ? 1 : 0,
                patron_library_ids        => do {
                    my $logged_in_user = Koha::Patrons->find( C4::Context->userenv->{'number'} );
                    [ $logged_in_user ? $logged_in_user->libraries_where_can_see_patrons : () ];
                },
            },
        },
    );
}

1;
