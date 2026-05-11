#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright Johan Sahlberg 2024
# Copyright (C) 2013  Mark Tompsett
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

# version 1.0 (2025-06-25)

use Modern::Perl;
use CGI        qw ( -utf8 );
use C4::Output qw( output_html_with_http_headers );
use C4::Auth   qw( get_template_and_user );
use C4::Koha;
use C4::Context;
use C4::Tags qw/get_count_by_tag_status/;
use Koha::Patron::Modifications;
use Koha::Patron::Discharge;
use Koha::Reviews;
use Koha::ArticleRequests;
use Koha::ProblemReports;
use Koha::Quotes;
use Koha::Suggestions;

use HTML::Entities;
use LWP::UserAgent;
use HTTP::Request;
use strict;
use warnings;
use JSON;

use utf8;

my $query = CGI->new;

my $debug = 1;

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name => "librisill-incomings.tt",
        query         => $query,
        type          => "intranet",
        debug         => $debug,
        flagsrequired => { catalogue => 1, },
    }
);

# Search query
my $sigil          = $query->param('branch');
my $start          = $query->param('start');
my $end            = $query->param('end');
my $archive        = $query->param('archive');
my $action         = $query->param('action');
my $response_id    = $query->param('response_id');
my $added_response = $query->param('added_response');
my $may_reserve    = $query->param('may_reserve');
my $order_id       = $query->param('order_id');
my $timestamp      = $query->param('last_modified');

my $url;
my $fragment;
my $extra_content;
my $request;
my $orig_data;

# Load JSON file with all api-keys
my $keyfile = "apikeys.json";

my $json_keys = do {
    open( my $json_fh, "<:encoding(UTF-8)", $keyfile )
        or die("Can't open \"$keyfile\": $!\n");
    local $/;
    <$json_fh>;
};

my $jsonforkeys = JSON->new;
my $libris_keys = $jsonforkeys->decode($json_keys);
my $libris_key  = $libris_keys->{data}[0]{$sigil};

if ($action) {

    $extra_content = "&may_reserve=$may_reserve&response_id=$response_id&added_response=$added_response";

} elsif ($archive) {

    $fragment = "illrequests/$sigil/incoming_archive?start_date=$start&end_date=$end";

} else {

    $fragment = "illrequests/$sigil/incoming";

}

# Fetch the actual data from the query
if ($action) {

    my $update_data = _update_libris( $sigil, $libris_key, $order_id, $action, $extra_content );
    $fragment  = "illrequests/$sigil/incoming";
    $orig_data = _get_data_from_libris( $sigil, $libris_key, $fragment );

} else {

    $orig_data = _get_data_from_libris( $sigil, $libris_key, $fragment );

}

my $decoded = $orig_data;

my $homebranch;
if ( C4::Context->userenv ) {
    $homebranch = C4::Context->userenv->{'branch'};
}

my $branch =
    (      C4::Context->preference("IndependentBranchesPatronModifications")
        || C4::Context->preference("IndependentBranches") )
    && !$flags->{'superlibrarian'}
    ? C4::Context->userenv()->{'branch'}
    : undef;

sub _get_data_from_libris {

    my ( $sigil, $libris_key, $fragment ) = @_;

    my $base_url = 'https://iller.libris.kb.se/librisfjarrlan/api';

    # Create a user agent object
    my $ua = LWP::UserAgent->new;
    $ua->agent("Koha ILL");

    # Replace placeholders in the fragment
    $fragment =~ s/__sigil__/$sigil/g;

    # Create a request
    my $url = "$base_url/$fragment";
    warn "Requesting $url";
    my $request = HTTP::Request->new( GET => $url );
    $request->header( 'api-key' => $libris_key );

    # Pass request to the user agent and get a response back
    my $res = $ua->request($request);

    my $json;

    # Check the outcome of the response
    if ( $res->is_success ) {
        $json = $res->content;
    } else {
        warn $res->status_line;
    }

    unless ($json) {
        warn "No JSON!";

        # exit;
    }

    my $data = decode_json($json);
    if ( $data->{'count'} == 0 ) {
        warn "No data!";

        # exit;
    }

    return $data;

}

sub _update_libris {

    my ( $sigil, $libris_key, $order_id, $action, $extra_content ) = @_;

    # my $orderid = $request->orderid;
    warn "*** orderid: $order_id";

    # Figure out the sigil that the current request is connected to
    # my $sigil = $sigil;
    warn "Handling request on behalf of $sigil";

    # my $status = $request->status;
    # $status =~ m/(.*?)_.*/g;
    my $direction = $1;

    my $orig_data = _get_data_from_libris( $sigil, $libris_key, "illrequests/$sigil/$order_id" );

    # Pick out the timestamp
    my $newtimestamp = $orig_data->{'ill_requests'}->[0]->{'last_modified'};
    warn "*** timestamp: $newtimestamp";

    # The extra-content being sent

    warn "*** extra_content: $extra_content";

    ## Make the call back to Libris, to change the status

    # Create a user agent object
    my $ua = LWP::UserAgent->new;
    $ua->agent("Koha ILL");

    # Create a request
    my $url = "https://iller.libris.kb.se/librisfjarrlan/api/illrequests/$sigil/$order_id";
    warn "POSTing to $url";
    my $req = HTTP::Request->new( 'POST', $url );
    warn "*** libris_key: " . $libris_key;
    $req->header( 'api-key'      => $libris_key );
    $req->header( 'Content-Type' => 'application/x-www-form-urlencoded' );
    $req->content("action=$action&timestamp=$newtimestamp$extra_content");

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ( $res->is_success ) {

        my $json     = $res->content;
        my $new_data = decode_json($json);

        warn "*** Update action: " . $new_data->{'update_action'};
        warn "*** Update success: " . $new_data->{'update_success'};
        warn "*** Update message: " . $new_data->{'update_message'};
        warn "*** Last modified: " . $new_data->{'ill_requests'}->[0]->{'last_modified'};
        warn "*** Status: " . $new_data->{'ill_requests'}->[0]->{'status'};

        # Update the request in the database
        # FIXME Create a proper sub for updating data
        # $request->status( $direction . '_' . translate_status( $new_data->{'ill_requests'}->[0]->{'status'} ) );
        # $request->extended_attributes->find({ type => 'last_modified' })->value( $new_data->{'ill_requests'}->[0]->{'last_modified'} );
        # request->store;

    } else {

        warn "--- ERROR ---";

    }

    return $res;

}

$template->param(
    decoded => $decoded,
    action  => $action,
    archive => $archive,
    sigil   => $sigil
);

output_html_with_http_headers $query, $cookie, $template->output;
