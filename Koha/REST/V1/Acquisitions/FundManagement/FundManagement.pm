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

    my $calculate_fund_values_including_tax  = C4::Context->preference('CalculateFundValuesIncludingTax');
    my $acq_create_items                     = C4::Context->preference('AcqCreateItem');
    my $use_acq_framework_for_biblio_records = C4::Context->preference('UseAcqFrameworkForBiblioRecords');
    my $marcflavour                          = C4::Context->preference('marcflavour');

    my @gst_values = map { option => $_ + 0.0 }, split( '\|', C4::Context->preference("TaxRates") );

    return $c->render(
        status  => 200,
        openapi => {
            permissions => $permissions,
            gst_values  => \@gst_values,
            sysprefs    => {
                calculate_fund_values_including_tax  => $calculate_fund_values_including_tax,
                acq_create_items                     => $acq_create_items,
                use_acq_framework_for_biblio_records => $use_acq_framework_for_biblio_records,
                marcflavour                          => $marcflavour
            },
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

        return $c->render(
            status  => 200,
            openapi => $patrons
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
