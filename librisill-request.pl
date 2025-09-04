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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

# version 1.0 (2025-06-25)

use Modern::Perl;
use CGI        qw ( -utf8 );
use C4::Output qw( output_html_with_http_headers );
use C4::Auth   qw( get_template_and_user );
use C4::Koha;

#use C4::NewsChannels; # GetNewsToDisplay
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
use diagnostics;
use JSON;

use CGI::Carp qw(fatalsToBrowser);

my $query = CGI->new;

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name => "librisill-request.tt",
        query         => $query,
        type          => "intranet",
        flagsrequired => { catalogue => 1, },
    }
);

# Load JSON file with all api-keys
my $keyfile = "apikeys.json";

my $json_keys = do {
    open( my $json_fh, "<:encoding(UTF-8)", $keyfile )
        or die("Can't open \"$keyfile\": $!\n");
    local $/;
    <$json_fh>;
};

my $json        = JSON->new;
my $libris_keys = $json->decode($json_keys);

# Search query
my $branch2  = $query->param('branch');
my $lfnumber = $query->param('lfnumber');

my $ua = LWP::UserAgent->new;
$ua->agent("Perl API Client/1.0");

# Setup variables
my $string     = "librisfjarrlan/api/illrequests";
my $host       = "iller.libris.kb.se";
my $protocol   = "https";
my $libris_key = $libris_keys->{data}[0]{$branch2};

# Build the url
my $url = "$protocol://$host/$string/$branch2/$lfnumber";

# Fetch the actual data from the query
my $request = HTTP::Request->new( "GET" => $url );

$request->header( 'api-key' => $libris_key );

#$request->content_type('application/json');

my $response = $ua->request($request);

my $jsonString = $response->content;

my $decoded = decode_json($jsonString);

my $user_id = $decoded->{ill_requests}->[0]->{user_id};

my $patron = Koha::Patrons->find( { cardnumber => $user_id } );

my $patron_id = length($patron);

my $patron_name = length($patron);

if ( $patron ne "" ) {
    $patron_id   = $patron->borrowernumber;
    $patron_name = $patron->surname . ", " . $patron->firstname;
} else {
    $patron_id   = "";
    $patron_name = "";
}

my @library_arr = map { $_->{library_code} } @{ $decoded->{ill_requests}->[0]->{recipients} };
foreach (@library_arr) {
    $_ = "+$_";
}
my $library_codes = scalar "@library_arr";

my %ill_hash = (
    author         => $decoded->{ill_requests}->[0]->{author},
    title          => $decoded->{ill_requests}->[0]->{title},
    imprint        => $decoded->{ill_requests}->[0]->{imprint},
    bib_id         => $decoded->{ill_requests}->[0]->{bib_id},
    isbn_issn      => $decoded->{ill_requests}->[0]->{isbn_issn},
    user           => $decoded->{ill_requests}->[0]->{user},
    user_id        => $decoded->{ill_requests}->[0]->{user_id},
    active_library => $decoded->{ill_requests}->[0]->{active_library},
    lf_number      => $decoded->{ill_requests}->[0]->{lf_number},
    library_codes  => $library_codes,
    patron_id      => $patron_id,
    patron_name    => $patron_name,
);

my $ill_json = encode_json \%ill_hash;

my $homebranch;
if ( C4::Context->userenv ) {
    $homebranch = C4::Context->userenv->{'branch'};
}

#my $all_koha_news   = &GetNewsToDisplay("koha",$homebranch);
#my $koha_news_count = scalar @$all_koha_news;

#$template->param(
#    koha_news       => $all_koha_news,
#    koha_news_count => $koha_news_count,
#    daily_quote     => Koha::Quotes->get_daily_quote(),
#);

my $branch =
    (      C4::Context->preference("IndependentBranchesPatronModifications")
        || C4::Context->preference("IndependentBranches") )
    && !$flags->{'superlibrarian'}
    ? C4::Context->userenv()->{'branch'}
    : undef;

my $pendingcomments = Koha::Reviews->search_limited( { approved => 0 } )->count;
my $pendingtags     = get_count_by_tag_status(0);

# Get current branch count and total viewable count, if they don't match then pass
# both to template

if ( C4::Context->only_my_library ) {
    my $local_pendingsuggestions_count =
        Koha::Suggestions->search( { status => "ASKED", branchcode => C4::Context->userenv()->{'branch'} } )->count();
    $template->param( pendingsuggestions => $local_pendingsuggestions_count );
} else {
    my $pendingsuggestions = Koha::Suggestions->search( { status => "ASKED" } );
    my $local_pendingsuggestions_count =
        $pendingsuggestions->search( { 'me.branchcode' => C4::Context->userenv()->{'branch'} } )->count();
    my $pendingsuggestions_count = $pendingsuggestions->count();
    $template->param(
        all_pendingsuggestions => $pendingsuggestions_count != $local_pendingsuggestions_count
        ? $pendingsuggestions_count
        : 0,
        pendingsuggestions => $local_pendingsuggestions_count
    );
}

my $pending_borrower_modifications = Koha::Patron::Modifications->pending_count($branch);
my $pending_discharge_requests     = Koha::Patron::Discharge::count( { pending => 1 } );
my $pending_article_requests       = Koha::ArticleRequests->search_limited(
    {
        status => Koha::ArticleRequest::Status::Pending,
        $branch ? ( 'me.branchcode' => $branch ) : (),
    }
)->count;
my $pending_problem_reports = Koha::ProblemReports->search( { status => 'New' } );

$template->param(
    pendingcomments                => $pendingcomments,
    pendingtags                    => $pendingtags,
    pending_borrower_modifications => $pending_borrower_modifications,
    pending_discharge_requests     => $pending_discharge_requests,
    pending_article_requests       => $pending_article_requests,
    pending_problem_reports        => $pending_problem_reports,
    jsonString                     => $jsonString,
    decoded                        => $decoded,
    patron                         => $patron,
    library_codes                  => $library_codes,
    ill_JSON                       => $ill_json,
);

output_html_with_http_headers $query, $cookie, $template->output;
