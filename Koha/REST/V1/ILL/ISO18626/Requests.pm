package Koha::REST::V1::ILL::ISO18626::Requests;

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

use Koha::ILL::ISO18626::Requests;
use MIME::Base64 qw( decode_base64 );
use Scalar::Util qw( blessed );
use Try::Tiny    qw( catch try );

=head1 NAME

Koha::REST::V1::ILL::ISO18626::Requests

=head2 Operations

=head3 list

Controller function that handles listing Koha::ILL::ISO18626::Request objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $reqs = $c->objects->search( Koha::ILL::ISO18626::Requests->new );
        return $c->render(
            status  => 200,
            openapi => $reqs,
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single Koha::ILL::ISO18626::Request object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $iso18626_request =
            $c->objects->find( Koha::ILL::ISO18626::Requests->search, $c->param('iso18626_request_id') );

        return $c->render_resource_not_found("Iso18626 request")
            unless $iso18626_request;

        return $c->render(
            status  => 200,
            openapi => $iso18626_request
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_document

Controller function that handles downloading the file of a Koha::ILL::Document

=cut

sub get_document {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $iso18626_request = Koha::ILL::ISO18626::Requests->find( $c->param('iso18626_request_id') );

        return $c->render_resource_not_found("Iso18626 request")
            unless $iso18626_request;

        my $document = $iso18626_request->documents->find( $c->param('ill_document_id') );

        return $c->render_resource_not_found("Document")
            unless $document;

        $c->render_file(
            'data'         => $document->file_content,
            'filename'     => $document->file_name,
            'content_type' => $document->file_type,
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 edit

Controller function that handles editing a single Koha::ILL::ISO18626::Request object

=cut

sub edit {
    my $c = shift or return;

    my $request_id = $c->param('iso18626_request_id');
    my $request    = Koha::ILL::ISO18626::Requests->find($request_id);

    return try {
        my $body   = $c->req->json;
        my $status = $body->{status};

        my $file_name    = delete $body->{file_name};
        my $file_content = delete $body->{file_content};
        if ( $file_name || $file_content ) {
            return $c->render(
                status  => 400,
                openapi => { error => "file_name and file_content must be supplied together" }
            ) unless $file_name && $file_content;

            return $c->render(
                status  => 400,
                openapi => { error => "A document can only be supplied with the CopyCompleted status" }
            ) unless $status && $status eq 'CopyCompleted';

            $body->{document} = { file_name => $file_name, file_content => decode_base64($file_content) };
        }

        my $result = $request->progress_request( 'supplyingAgency', $body );
        return $c->render( status => 500, json => { error => "Request could not be progressed" } )
            unless $result;

        return $c->render(
            status  => 200,
            openapi => $request->to_api
        );
    } catch {
        if ( blessed $_ && $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
            return $c->render(
                status  => 413,
                openapi => { error => $_->error }
            );
        }
        return $c->unhandled_exception($_);
    };
}

1;
