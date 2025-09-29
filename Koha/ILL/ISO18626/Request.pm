package Koha::ILL::ISO18626::Request;

# Copyright PTFS Europe 2025
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::ILL::ISO18626::Messages;
use Koha::REST::V1;
use XML::LibXML;
use JSON           qw( encode_json decode_json );
use File::Basename qw( dirname );

use base qw(Koha::Object);

=head1 NAME

Koha::ILL::ISO18626::Request - Koha ILL ISO18626 request Object class

=cut

=head3 to_api

    my $json = $fund->to_api;

Overloaded method that returns a JSON representation of the Koha::Acquisition::Fund object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $args ) = @_;

    my $messages = $self->messages;

    my $json_request = $self->SUPER::to_api($args);
    return unless $json_request;

    $json_request->{messages} = $messages;

    return $json_request;
}

=head3 add_message

Add the I<Koha::ILL::ISO18626::Message> to this ISO18626 request

=cut

sub add_message {
    my ( $self, $params ) = @_;

    my $type    = $params->{type};
    my $message = $params->{message};

    if ( ref $message eq 'HASH' ) {
        $message = encode_json($message);
    }

    return $self->_result->add_to_iso18626_messages(
        {
            type    => $type,
            content => $message,
        }
    );
}

=head3 messages

Return the I<Koha::ILL::ISO18626::Messages> for this ISO18626 request

=cut

sub messages {
    my ($self) = @_;
    my $messages = $self->_result->iso18626_messages->search(
        {},
        { order_by => { -desc => 'timestamp' } }
    );
    return Koha::ILL::ISO18626::Messages->_new_from_dbic($messages);
}

=head3 send_message

Send a message to the requesting agency
    # $message must be a valid XML string.

=cut

sub send_message {
    my ( $self, $type, $message ) = @_;

    # my $requesting_agency = $self->_result->requesting_agency;

    # return unless $requesting_agency->callback_endpoint;

    # my $ua = LWP::UserAgent->new( agent => 'Koha ILL' );
    # $ua->agent( 'Koha/' . Koha::version() );

    # my $response = $ua->post(
    #     $requesting_agency->callback_endpoint,
    #     Content_Type => 'application/xml',
    #     Content => $message,
    # );

    # if ( $response->is_success ) {
    #FIXME: Better way to convert this to json other than invoking Koha::REST::V1 ?
    # my $parser = XML::LibXML->new();
    # my $doc    = $parser->parse_string($message);
    # my $root   = $doc->documentElement();
    # my $json   = Koha::REST::V1::parse_xml($root);

    # $json = JSON::encode_json($json);
    $self->add_message( { type => $type, message => $message } );
    return 1;

    # }
    # else {
    #     $self->_result->add_message( 'Request', "Failed to send message: " . $response->status_line );
    #     return;
    # }
}

=head3 progress_request

Progress the request by sending a message to the requesting agency with the status of the request.

Params:
    - actor: supplyingAgency or requestingAgency
    - params: may contain status, messageInfoNote, message

=cut

sub progress_request {
    my ( $self, $actor, $params ) = @_;

    return unless $actor;

    my $resulting_status = $self->status;
    my $old_status       = $self->status;
    my $new_status       = $params->{status};

    my $reasonForMessage     = 'RequestResponse';
    my $messageInfoNote      = $params->{messageInfoNote}      // undef;
    my $answerYesNo          = $params->{answerYesNo}          // undef;
    my $expectedDeliveryDate = $params->{expectedDeliveryDate} // undef;
    my $reasonUnfilled       = $params->{reasonUnfilled}       // undef;
    my $reasonRetry          = $params->{reasonRetry}          // undef;
    my $volume               = $params->{volume}               // undef;
    my $loanCondition        = $params->{loanCondition}        // undef;

    if ( $actor eq 'requestingAgency' ) {
        return unless $params->{message};

        my $message      = $params->{message};
        my $json_message = JSON::decode_json( $message->content );

        my $requesting_agency_action = $json_message->{requestingAgencyMessage}->{action};

        if ( $requesting_agency_action eq 'StatusRequest' ) {
            $reasonForMessage = 'StatusRequestResponse';
        } elsif ( $requesting_agency_action eq 'Received' ) {
            return;
        }
    } elsif ( $actor eq 'supplyingAgency' ) {
        return unless $new_status;

        $resulting_status = $new_status if $actor eq 'supplyingAgency';

        if ( $resulting_status ne $old_status ) {
            $reasonForMessage = 'StatusChange';
        }

        if ( $new_status eq 'Cancelled' ) {
            $reasonForMessage = 'CancelResponse';
            $resulting_status = $old_status unless $answerYesNo eq 'Y';
            $self->pending_requesting_agency_action(undef)->store;    #TODO: Should we always reset this?
        }

        #TODO: Handle other statuses
        # elsif ( $new_status eq 'Renew' ) { #Handle 'renew', it's not a status
        #     $reasonForMessage = 'RenewResponse';
        #     $answerYesNo      = $params->{answerYesNo};
        #     $resulting_status = ?????;
        # }

    } else {
        return;
    }

    #TODO: Verify this is a valid status
    # $resulting_status = 'WillSupply';

    my $json = {
        supplyingAgencyMessage => {
            header => {
                supplyingAgencyId => {
                    agencyIdType  => 'ISIL',
                    agencyIdValue => 'sup_agency_value',
                },
                requestingAgencyRequestId => 'XYZ',
                supplyingAgencyRequestId  => $self->iso18626_request_id,
                timestamp                 => '2023-03-15 14:30:00',
                requestingAgencyId        => {
                    agencyIdType  => 'ISIL',
                    agencyIdValue => 'req_agency_value',
                },
            },
            messageInfo => {
                reasonForMessage => $reasonForMessage,
                $answerYesNo     ? ( answerYesNo => $answerYesNo )     : (),
                $messageInfoNote ? ( note        => $messageInfoNote ) : (),
                $reasonUnfilled && $resulting_status eq 'Unfilled'      ? ( reasonUnfilled => $reasonUnfilled ) : (),
                $reasonRetry    && $resulting_status eq 'RetryPossible' ? ( reasonRetry    => $reasonRetry )    : (),
            },
            statusInfo => {
                status => $resulting_status,
                $expectedDeliveryDate ? ( expectedDeliveryDate => $expectedDeliveryDate ) : (),
                dueDate    => '2023-03-15 14:30:00',    #TODO: Add due date
                lastChange => '2023-03-15 14:30:00',    #TODO: Add $self->last_status_change_timestamp here
            },
            $resulting_status eq 'RetryPossible'
            ? (
                retryInfo => {
                    $loanCondition ? ( loanCondition => $loanCondition ) : (),
                    edition    => ['edition_string'],
                    itemFormat => ['PaperCopy'],
                    $volume ? ( volume => [ split /,/, $volume ] ) : (),
                    serviceType    => 'Copy',
                    serviceLevel   => ['Urgent'],
                    deliveryMethod => ['Email'],
                    courierName    => [ 'Fedex', 'UPS' ],    # Only if deliveryMethod = 'Courier'
                    offeredCosts   => [ { currencyCode => 'EUR', monetaryValue => '50.00' } ],
                    ,    # Only if $request->billingInfo->maximumCosts not null and lower than supplying agency costs
                    paymentMethod => [ 'BankTransfer', 'DebitCard' ]
                    , # Only if ReasonRetry or ReqPayMethodNotSupp is used not null and lower than supplying agency costs
                    retryBefore => '2023-03-15 14:30:00',
                    retryAfter  => '2023-03-15 14:30:00'
                }
                )
            : (),
            deliveryInfo => {
                dateSent       => '2023-03-15 14:30:00',
                itemId         => 'edition_string',
                itemFormat     => ['PaperCopy'],
                serviceType    => 'Copy',
                deliveryMethod => 'Email',
                paymentMethod  => 'BankTransfer'
            },
            shippingInfo => {
                courierName         => 'DHL',
                trackingId          => [ '123', 'abc' ],
                insurance           => 'N',
                insuranceThirdParty => 'N',
                thirdPartyName      => 'Some name, if insuranceThirdParty',
                insuranceCosts      => [ { currencyCode => 'EUR', monetaryValue => '50.00' } ]
            }
        },
    };

    my $spec_file = dirname(__FILE__) . "/../../../api/v1/swagger/swagger_bundle.json";
    if ( !-f $spec_file ) {
        $spec_file = dirname(__FILE__) . "/../../../api/v1/swagger/swagger.yaml";
    }

    my $schema = JSON::Validator::Schema::OpenAPIv2->new($spec_file);
    $schema->resolve( $schema->data->{definitions}->{supplyingAgencyMessage} );
    my @errors = $schema->validate($json);

    if (@errors) {

        #TODO: Throw exception
        use Data::Dumper;
        $Data::Dumper::Maxdepth = 4;
        warn Dumper( '##### 2 #######################################################line: ' . __LINE__ );
        warn Dumper( \@errors );
        warn Dumper('##### end2 #######################################################');
    }
    $self->status($resulting_status)->store;
    $self->send_message( 'supplyingAgencyMessage', $json );
    return 1;
}

=head3 _type

=cut

sub _type {
    return 'Iso18626Request';
}

1;
