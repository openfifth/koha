package Koha::Completion::NavetBorrowerCompletion;

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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use strict;
use IO::Socket::SSL;
use SOAP::Lite;
use Koha::Logger;
use File::Basename qw( dirname );

our @ISA = qw( Koha::Completion::BorrowerCompletion );

my $TEST_ORG_NR          = '162021004748';
my $TEST_BESTALLNINGS_ID = '00000236-FO01-0001';
my $TEST_CERTIFICATE     = dirname(__FILE__) . '/navet-testcert.p12';
my $TEST_PASSWORD        = '5761213661378233';

my %MAP = (
    'Namn.Efternamn'                                  => [ 'surname',      1 ],
    'Namn.Fornamn'                                    => [ 'firstname',    1 ],
    'Adresser.Folkbokforingsadress.Postort'           => [ 'city',         1 ],
    'Adresser.Folkbokforingsadress.Utdelningsadress2' => [ 'address',      1 ],
    'Adresser.Folkbokforingsadress.PostNr'            => [ 'zipcode',      0 ],
    'Avregistrering.AvregistreringsorsakKod'          => [ 'patron_attr_', 0, 'AVLIDEN' ]
);

sub fetch_completions {
    my $self = shift;
    my $id   = shift;

    my $logger = Koha::Logger->get( { category => 'Koha.Completion.NavetBorrowerCompletion' } );

    my ( $pnrd, $pnrn, $dob ) = $self->normalize_pnr($id);

    if ( defined $pnrn ) {

        if ( $self->{config}->{test} ) {
            $self->{config}->{SSL_cert_file}  = $TEST_CERTIFICATE;
            $self->{config}->{SSL_passwd}     = $TEST_PASSWORD;
            $self->{config}->{BestallningsId} = $TEST_BESTALLNINGS_ID;
            $self->{config}->{OrgNr}          = $TEST_ORG_NR;
        }

        my $ssl_opts = $self->ssl_opts;

        use Data::Dumper;
        $logger->warn( Dumper( $self->{config} ) );
        $logger->warn( Dumper($ssl_opts) );

        my $url =
            $self->{config}->{test}
            ? "https://www2.test.skatteverket.se/na/na_epersondata/V4/personpostXML"
            : "https://www2.skatteverket.se/na/na_epersondata/V4/personpostXML";

        my $soap = SOAP::Lite->proxy( $url, ssl_opts => $ssl_opts );

        my $resp = $soap->call(
            SOAP::Data->name('PersonpostRequest')
                ->uri('http://xmls.skatteverket.se/se/skatteverket/folkbokforing/na/epersondata/V1')->prefix('ns1'),
            SOAP::Data->name('Bestallning')->prefix('ns1')->value(
                \SOAP::Data->value(
                    SOAP::Data->name('OrgNr')->prefix('ns1')->value( $self->{config}->{OrgNr} ),
                    SOAP::Data->name('BestallningsId')->prefix('ns1')->value( $self->{config}->{BestallningsId} )
                ),
            ),
            SOAP::Data->name('PersonId')->prefix('ns1')->value($pnrn)
        );

        if ( $resp->fault ) {
            my $detail = '';
            for my $k ( keys %{ $resp->faultdetail->{error} } ) {
                $detail .= "$k: " . $resp->faultdetail->{error}->{$k} . "\n";
            }
            my $msg = $resp->faultcode . ' ' . $resp->faultstring . ":\n" . $detail;
            $logger->error($msg);
            return { error => $msg, status => 500 };
        }

        my $result = $resp->result;

        if ( !defined $result->{Folkbokforingspost} || !defined $result->{Folkbokforingspost}->{Personpost} ) {
            return { error => 'Result does not contain Personpost!', status => 500 };
        }

        my $p = $result->{Folkbokforingspost}->{Personpost};

        my $pnr = $self->{config}->{dashed_pnr} ? $pnrd : $pnrn;

        my $form_fields = $self->populate_form_fields( $pnr, $dob, $p, \%MAP );

        return { form_fields => $form_fields };
    }
}
