package Koha::ILL::ISO18626::Requester;

# Copyright Open Fifth 2026
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

use File::Basename qw( dirname );
use JSON           qw( encode_json );
use LWP::UserAgent;
use XML::LibXML;

use C4::Context;
use Koha::ILL::ISO18626;
use Koha::ILL::ISO18626::Message;
use Koha::ILL::Request;
use Koha::ILL::Request::Config;
use Koha::ILL::ISO18626::SupplyingAgencies;
use Koha::REST::V1;

=head1 NAME

Koha::ILL::ISO18626::Requester - Send ISO 18626 messages to supplying agencies

=head1 SYNOPSIS

    my $result = Koha::ILL::ISO18626::Requester->send_request(
        {
            illrequest       => $illrequest,
            supplying_agency => $supplying_agency,
            request          => { bibliographicInfo => {...}, serviceInfo => {...} },
        }
    );

=head1 DESCRIPTION

Requesting agency side of ISO 18626, for ILL backends to use. The backend provides the
message content, this module adds the header, validates, logs and sends the message, and
handles the confirmation. It does not change the ILL request status.

All methods return a hashref with C<success> (1 or 0), and C<error> on failure.

=head1 API

=head2 Class methods

=head3 send_request

    my $result = Koha::ILL::ISO18626::Requester->send_request(
        { illrequest => $illrequest, supplying_agency => $supplying_agency, request => $request }
    );

Sends an ISO 18626 C<request> for C<$illrequest> to C<$supplying_agency>.
C<$request> is the content of the request message without its C<header>.

=cut

sub send_request {
    my ( $class, $params ) = @_;

    my $illrequest       = $params->{illrequest};
    my $supplying_agency = $params->{supplying_agency};

    my $message = {
        request => {
            %{ $params->{request} // {} },
            header => {
                supplyingAgencyId              => $supplying_agency->iso18626_agency_id,
                requestingAgencyId             => _own_agency_id(),
                requestingAgencyRequestId      => "" . $illrequest->illrequest_id,
                timestamp                      => Koha::ILL::ISO18626::format_date_time('now'),
                requestingAgencyAuthentication => {
                    accountId    => $supplying_agency->account_id,
                    securityCode => $supplying_agency->securityCode,
                },
            },
        }
    };

    $illrequest->add_or_update_attributes( { iso18626_supplying_agency_id => $supplying_agency->id } );

    return $class->_send( $illrequest, $supplying_agency, 'request', $message );
}

=head3 send_requesting_agency_message

    my $result = Koha::ILL::ISO18626::Requester->send_requesting_agency_message(
        { illrequest => $illrequest, action => 'Cancel', note => 'Not needed anymore' }
    );

Sends an ISO 18626 C<requestingAgencyMessage> for C<$illrequest> to the supplying agency
its request was sent to.

=cut

sub send_requesting_agency_message {
    my ( $class, $params ) = @_;

    my $illrequest       = $params->{illrequest};
    my $supplying_agency = $class->supplying_agency($illrequest);

    return { success => 0, error => sprintf( 'No supplying agency for ILL request %s', $illrequest->illrequest_id ) }
        unless $supplying_agency;

    my $supplying_agency_request_id =
        $illrequest->extended_attributes->search( { type => 'iso18626_supplying_agency_request_id' } )->next;

    my $message = {
        requestingAgencyMessage => {
            header => {
                supplyingAgencyId         => $supplying_agency->iso18626_agency_id,
                requestingAgencyId        => _own_agency_id(),
                requestingAgencyRequestId => "" . $illrequest->illrequest_id,
                $supplying_agency_request_id
                ? ( supplyingAgencyRequestId => $supplying_agency_request_id->value )
                : (),
                timestamp                      => Koha::ILL::ISO18626::format_date_time('now'),
                requestingAgencyAuthentication => {
                    accountId    => $supplying_agency->account_id,
                    securityCode => $supplying_agency->securityCode,
                },
            },
            action => $params->{action},
            $params->{note} ? ( note => $params->{note} ) : (),
        }
    };

    return $class->_send( $illrequest, $supplying_agency, 'requestingAgencyMessage', $message );
}

=head3 backends

    my $backends = Koha::ILL::ISO18626::Requester->backends;

Returns the names of the ILL backends that send ISO 18626 requests, i.e. those with the
C<iso18626_requesting> capability.

=cut

sub backends {
    my ($class) = @_;

    return [ grep { Koha::ILL::Request->new->load_backend($_)->_backend_capability('iso18626_requesting') }
            @{ Koha::ILL::Request::Config->new->available_backends } ];
}

=head3 supplying_agency

    my $supplying_agency = Koha::ILL::ISO18626::Requester->supplying_agency($illrequest);

Returns the I<Koha::ILL::ISO18626::SupplyingAgency> the request of C<$illrequest> was sent to.

=cut

sub supplying_agency {
    my ( $class, $illrequest ) = @_;

    my $attribute = $illrequest->extended_attributes->search( { type => 'iso18626_supplying_agency_id' } )->next;
    return unless $attribute;

    return Koha::ILL::ISO18626::SupplyingAgencies->find( $attribute->value );
}

=head3 log_message

    Koha::ILL::ISO18626::Requester->log_message( $illrequest, $type, $message );

Stores C<$message> of C<$type> in the ISO 18626 message log of C<$illrequest>.

=cut

sub log_message {
    my ( $class, $illrequest, $type, $message ) = @_;

    return Koha::ILL::ISO18626::Message->new(
        {
            illrequest_id => $illrequest->illrequest_id,
            type          => $type,
            content       => encode_json($message),
        }
    )->store;
}

=head2 Internal methods

=head3 _send

Validates, logs and sends C<$message> of C<$type>, then logs and checks the confirmation.

=cut

sub _send {
    my ( $class, $illrequest, $supplying_agency, $type, $message ) = @_;

    my $errors = Koha::ILL::ISO18626::is_invalid( $type, $message );
    return {
        success => 0,
        error   => sprintf( 'Invalid %s: %s', $type, join( ', ', map { $_->{errorValue} } @$errors ) )
    } if $errors;

    $class->log_message( $illrequest, $type, $message );

    my $ua = LWP::UserAgent->new(
        agent   => 'Koha ' . $Koha::VERSION,
        timeout => 10,
    );
    my $response = $ua->post(
        $supplying_agency->endpoint,
        'Content-Type' => 'application/xml',
        Content        => Koha::ILL::ISO18626::xml_with_envelope($message),
    );

    return {
        success => 0,
        error   => sprintf( 'Could not send %s to %s: %s', $type, $supplying_agency->endpoint, $response->status_line )
        }
        unless $response->is_success;

    my $confirmation_type = $type . 'Confirmation';
    my $confirmation      = eval {
        my $doc = XML::LibXML->load_xml( string => $response->decoded_content );
        Koha::ILL::ISO18626::message_without_envelope(
            Koha::REST::V1::parse_xml( $doc->documentElement, _spec_file() ) );
    };

    return {
        success => 0,
        error   => sprintf( 'Could not read the %s from %s', $confirmation_type, $supplying_agency->endpoint )
        }
        unless ref $confirmation eq 'HASH' && $confirmation->{$confirmation_type};

    $class->log_message( $illrequest, $confirmation_type, $confirmation );

    my $message_status = $confirmation->{$confirmation_type}->{confirmationHeader}->{messageStatus} // '';
    unless ( $message_status eq 'OK' ) {
        my $error_data = $confirmation->{$confirmation_type}->{errorData} // [];
        $error_data = [$error_data] unless ref $error_data eq 'ARRAY';

        return {
            success => 0,
            error   => sprintf(
                '%s rejected the %s: %s', $supplying_agency->endpoint, $type,
                join(
                    ', ',
                    map {
                        join( ' ', grep { defined } @$_{qw(errorType errorValue)} )
                    } @$error_data
                    )
                    || $message_status
            )
        };
    }

    return { success => 1 };
}

=head3 _own_agency_id

Returns this Koha's agency ID, from the ISO18626AgencyId and ISO18626AgencyIdType system preferences.

=cut

sub _own_agency_id {
    my $agency_id_value = C4::Context->preference('ISO18626AgencyId');

    unless ($agency_id_value) {
        warn "ISO18626: No requesting agency ID, sending UNKNOWN. Set the ISO18626AgencyId system preference";
        $agency_id_value = 'UNKNOWN';
    }

    return {
        agencyIdType  => C4::Context->preference('ISO18626AgencyIdType') || 'ISIL',
        agencyIdValue => $agency_id_value,
    };
}

=head3 _spec_file

=cut

sub _spec_file {
    my $spec_file = dirname(__FILE__) . "/../../../api/v1/swagger/swagger_bundle.json";
    return -f $spec_file ? $spec_file : dirname(__FILE__) . "/../../../api/v1/swagger/swagger.yaml";
}

1;
