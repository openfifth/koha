#!/usr/bin/perl

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

use Test::NoWarnings;
use Test::More tests => 4;
use Test::MockModule;
use Test::MockObject;

use JSON qw( decode_json );
use XML::LibXML;

use Koha::Database;
use Koha::ILL::ISO18626::Requester;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $request_body = {
    bibliographicInfo => { title       => 'A title' },
    serviceInfo       => { serviceType => 'Copy' },
};

# Mock the supplying agency: records what was posted and answers with $confirmation
my ( $posted_to, $posted_xml, $http_ok, $confirmation );
my $mock_ua = Test::MockModule->new('LWP::UserAgent');
$mock_ua->mock(
    'post',
    sub {
        my ( $self, $url, %args ) = @_;
        $posted_to  = $url;
        $posted_xml = $args{Content};
        my $response = Test::MockObject->new;
        $response->mock( 'is_success',      sub { $http_ok } );
        $response->mock( 'status_line',     sub { $http_ok ? '200 OK' : '500 Internal Server Error' } );
        $response->mock( 'decoded_content', sub { $confirmation } );
        return $response;
    }
);

my $confirmation_xml = sub {
    my ( $type, $status, $error ) = @_;
    my $error_xml =
        $error
        ? "<errorData><errorType>$error->{errorType}</errorType><errorValue>$error->{errorValue}</errorValue></errorData>"
        : '';
    return
        qq{<ISO18626Message xmlns="http://illtransactions.org/2013/iso18626" xmlns:ill="http://illtransactions.org/2013/iso18626" ill:version="2021-3">
  <${type}Confirmation>
    <confirmationHeader>
      <timestamp>2026-11-19T10:00:00Z</timestamp>
      <timestampReceived>2026-11-19T10:00:00Z</timestampReceived>
      <messageStatus>$status</messageStatus>
    </confirmationHeader>
    $error_xml
  </${type}Confirmation>
</ISO18626Message>};
};

my $logged = sub {
    my ( $illrequest, $type ) = @_;
    my $message = $illrequest->_result->iso18626_messages->search( { type => $type } )->next;
    return $message ? decode_json( $message->content ) : undef;
};

subtest 'send_request() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'ISO18626AgencyId',     'GB-REQ' );
    t::lib::Mocks::mock_preference( 'ISO18626AgencyIdType', 'ISIL' );

    my $supplying_agency = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::SupplyingAgencies',
            value => {
                type     => 'ISIL', agency_id => 'GB-SUP', account_id => 'acc', securityCode => 'sec',
                endpoint => 'https://supplier.example/api/v1/public/ill/iso18626'
            }
        }
    );
    my $illrequest = $builder->build_object( { class => 'Koha::ILL::Requests' } );

    $http_ok      = 1;
    $confirmation = $confirmation_xml->( 'request', 'OK' );

    my $result = Koha::ILL::ISO18626::Requester->send_request(
        { illrequest => $illrequest, supplying_agency => $supplying_agency, request => $request_body } );

    is_deeply( $result, { success => 1 }, 'Request sent' );
    is( $posted_to, $supplying_agency->endpoint, 'Sent to the supplying agency endpoint' );
    is(
        XML::LibXML->load_xml( string => $posted_xml )->documentElement->localName, 'ISO18626Message',
        'Sent in the ISO18626Message envelope'
    );

    my $header = $logged->( $illrequest, 'request' )->{request}->{header};
    is_deeply(
        $header->{supplyingAgencyId}, { agencyIdType => 'ISIL', agencyIdValue => 'GB-SUP' },
        'supplyingAgencyId is the supplying agency ID'
    );
    is_deeply(
        $header->{requestingAgencyId}, { agencyIdType => 'ISIL', agencyIdValue => 'GB-REQ' },
        'requestingAgencyId comes from ISO18626AgencyId'
    );
    is(
        $header->{requestingAgencyRequestId}, $illrequest->illrequest_id,
        'requestingAgencyRequestId is the ILL request ID'
    );
    is_deeply(
        $header->{requestingAgencyAuthentication}, { accountId => 'acc', securityCode => 'sec' },
        'Authenticates with the supplying agency credentials'
    );
    ok( $logged->( $illrequest, 'requestConfirmation' ), 'requestConfirmation is logged' );
    is(
        Koha::ILL::ISO18626::Requester->supplying_agency($illrequest)->id, $supplying_agency->id,
        'The ILL request is linked to the supplying agency'
    );

    $confirmation = $confirmation_xml->(
        'request', 'ERROR',
        { errorType => 'UnrecognisedDataValue', errorValue => 'Unknown title' }
    );
    $result = Koha::ILL::ISO18626::Requester->send_request(
        { illrequest => $illrequest, supplying_agency => $supplying_agency, request => $request_body } );
    is( $result->{success}, 0, 'A rejected request is not a success' );
    like( $result->{error}, qr/UnrecognisedDataValue Unknown title/, 'The rejection reason is returned' );

    $http_ok = 0;
    $result  = Koha::ILL::ISO18626::Requester->send_request(
        { illrequest => $illrequest, supplying_agency => $supplying_agency, request => $request_body } );
    like( $result->{error}, qr/500 Internal Server Error/, 'HTTP failures are returned' );

    $http_ok    = 1;
    $posted_xml = undef;
    $result     = Koha::ILL::ISO18626::Requester->send_request(
        {
            illrequest => $illrequest, supplying_agency => $supplying_agency,
            request    => { bibliographicInfo => { title => 'A title' } }
        }
    );
    ok( !$result->{success} && !$posted_xml, 'An invalid request is not sent' );

    $schema->storage->txn_rollback;
};

subtest 'send_requesting_agency_message() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'ISO18626AgencyId', 'GB-REQ' );

    my $illrequest = $builder->build_object( { class => 'Koha::ILL::Requests' } );

    my $result = Koha::ILL::ISO18626::Requester->send_requesting_agency_message(
        { illrequest => $illrequest, action => 'Cancel' } );
    like( $result->{error}, qr/No supplying agency/, 'Not sent without a supplying agency' );

    my $supplying_agency = $builder->build_object(
        { class => 'Koha::ILL::ISO18626::SupplyingAgencies', value => { type => 'ISIL', agency_id => 'GB-SUP' } } );
    $illrequest->add_or_update_attributes(
        {
            iso18626_supplying_agency_id         => $supplying_agency->id,
            iso18626_supplying_agency_request_id => '42',
        }
    );

    $http_ok      = 1;
    $confirmation = $confirmation_xml->( 'requestingAgencyMessage', 'OK' );

    $result = Koha::ILL::ISO18626::Requester->send_requesting_agency_message(
        { illrequest => $illrequest, action => 'Cancel', note => 'Not needed' } );
    is_deeply( $result, { success => 1 }, 'Message sent' );
    is( $posted_to, $supplying_agency->endpoint, 'Sent to the supplying agency of the request' );

    my $message = $logged->( $illrequest, 'requestingAgencyMessage' )->{requestingAgencyMessage};
    is( $message->{action},                             'Cancel',     'action is sent' );
    is( $message->{note},                               'Not needed', 'note is sent' );
    is( $message->{header}->{supplyingAgencyRequestId}, '42',         'supplyingAgencyRequestId is sent' );

    $schema->storage->txn_rollback;
};

subtest 'requestingAgencyId without ISO18626AgencyId' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'ISO18626AgencyId', '' );

    my $supplying_agency = $builder->build_object(
        { class => 'Koha::ILL::ISO18626::SupplyingAgencies', value => { type => 'ISIL', agency_id => 'GB-SUP' } } );
    my $illrequest = $builder->build_object( { class => 'Koha::ILL::Requests' } );

    $http_ok      = 1;
    $confirmation = $confirmation_xml->( 'request', 'OK' );

    my @warnings;
    {
        local $SIG{__WARN__} = sub { push @warnings, @_ };
        Koha::ILL::ISO18626::Requester->send_request(
            { illrequest => $illrequest, supplying_agency => $supplying_agency, request => $request_body } );
    }

    is_deeply(
        $logged->( $illrequest, 'request' )->{request}->{header}->{requestingAgencyId},
        { agencyIdType => 'ISIL', agencyIdValue => 'UNKNOWN' },
        'requestingAgencyId is UNKNOWN'
    );
    like( $warnings[0], qr/No requesting agency ID.*ISO18626AgencyId/, 'Warns about the missing agency ID' );

    $schema->storage->txn_rollback;
};
