package Koha::REST::V1::Acquisitions::Finances::Finances;

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
use Mojo::JSON qw(encode_json decode_json);
use Try::Tiny;

use C4::Context;

use Koha::Acquisition::Finances::BaseObjects;

=head1 API

=head2 Methods

=head3 config

=cut

sub config {
    my $c = shift->openapi->valid_input or return;

    my $patron      = $c->stash('koha.user');
    my $userflags   = C4::Auth::getuserflags( $patron->flags, $patron->id );
    my $permissions = Koha::Auth::Permissions->get_authz_from_flags( { flags => $userflags } );

    my @gst_values = map { option => $_ + 0.0 }, split( '\|', C4::Context->preference("TaxRates") );

    return $c->render(
        status  => 200,
        openapi => {
            permissions => $permissions,
            gst_values  => \@gst_values,
            sysprefs    => {
                calculate_fund_values_including_tax  => C4::Context->preference('CalculateFundValuesIncludingTax'),
                acq_create_items                     => C4::Context->preference('AcqCreateItem'),
                use_acq_framework_for_biblio_records => C4::Context->preference('UseAcqFrameworkForBiblioRecords'),
                marcflavour                          => C4::Context->preference('marcflavour'),
                different_currencies_in_ledgers      => C4::Context->preference('DifferentCurrenciesInLedgers'),
                unique_item_fields                   => C4::Context->preference('UniqueItemFields'),
                marc_ordering_automation             => C4::Context->preference('MarcOrderingAutomation'),
                edifact                              => C4::Context->preference('EDIFACT'),
            },
        },
    );
}

=head3 list_users

Return the list of possible finances users

=cut

sub list_users {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $query = decode_json( $c->req->param('q') );
        my $permission;
        if ( $query->{permission} ) {
            $permission = $query->{permission};
            delete $query->{permission};
        } else {
            if ( $query->{'-and'} || $query->{'-or'} ) {
                foreach my $param ( ( '-and', '-or' ) ) {
                    if ( $query->{$param} ) {
                        my ($permission_query) = grep( ref($_) eq 'HASH' && $_->{permission}, @{ $query->{$param} } );
                        my @filtered_params = grep( ref($_) ne 'HASH' || ( ref($_) eq 'HASH' && !$_->{permission} ),
                            @{ $query->{$param} } );
                        $query->{$param} = \@filtered_params;
                        $permission = $permission_query->{permission};
                    }
                }
            }
        }
        $c->req->param( 'q', encode_json($query) );

        my $patrons_rs = Koha::Patrons->new->filter_by_have_permission($permission);
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
