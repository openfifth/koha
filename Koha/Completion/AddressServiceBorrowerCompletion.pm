package Koha::Completion::AddressServiceBorrowerCompletion;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use strict;
use IO::Socket::SSL;
use SOAP::Lite;
use Koha::Logger;

# our @ISA = qw( BorrowerCompletion );
our @ISA = qw( Koha::Completion::BorrowerCompletion );

my %MAP = (
    'ENamn'      => [ 'surname',      1 ],
    'FNamn'      => [ 'firstname',    1 ],
    'PostAdress' => [ 'city',         1 ],
    'GatuAdress' => [ 'address',      1 ],
    'PostNr'     => [ 'zipcode',      0 ],
    'Avliden'    => [ 'patron_attr_', 0, 'AVLIDEN' ]
);

sub fetch_completions {
    my $self = shift;
    my $id   = shift;

    my $logger = Koha::Logger->get( { category => 'Koha.Completion.AddressServiceBorrowerCompletion' } );

    my ( $pnrd, $pnrn, $dob ) = $self->normalize_pnr($id);

    if ( defined $pnrn ) {

        my $soap = SOAP::Lite->proxy(
            "https://adresservice.ltv.se/csp/population/LTV.AddressService.Service.GetAddressResponderBinding.cls",
            ssl_opts => $self->ssl_opts
        );

        $soap->on_action( sub { 'ltv:population:resident:AddressService:GetAddress' } );
        $soap->ns('ltv:population:resident:AddressService');

        my $resp = $soap->call( 'GetAddress', SOAP::Data->name('pnr')->value($pnrn) );

        if ( $resp->fault ) {
            my $detail = '';
            for my $k ( keys %{ $resp->faultdetail->{error} } ) {
                $detail .= "$k: " . $resp->faultdetail->{error}->{$k} . "\n";
            }
            my $msg = $resp->faultcode . ' ' . $resp->faultstring . ":\n" . $detail;
            $logger->error($msg);
            return { error => $msg, status => 500 };
        }

        my $pnr = $self->{config}->{dashed_pnr} ? $pnrd : $pnrn;

        my $form_fields = $self->populate_form_fields( $pnr, $dob, $resp->result, \%MAP );

        return { form_fields => $form_fields };

    } else {
        my $msg = "Felaktigt personnummer: " . $id;
        $logger->error($msg);
        return { error => $msg, status => 400 };

    }
}

=head1 AUTHOR

Andreas Jonsson, E<lt>andreas.jonsson@kreablo.seE<gt>

=cut

1;
