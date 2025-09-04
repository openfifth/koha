#!/usr/bin/perl -w

# LIBRIS Fjärrlån - Status på beställningar
# av Johan Sahlberg (johan.sahlberg@tidaholm.se), 2024

# Search string example:
# ./flstatus_v2.pl branch=TIDA lfnumber=Tida-210416-0001 start=2024-8-1 end=2024-9-1

# Updated with authorization - 2021-06-08
# Changed to https - 2023-05-30
# Updated to recieve ALL outgoing for given period - 2024-09-19

# version 1.0 (2025-06-25)

use Modern::Perl;
use CGI qw ( -utf8 );

use C4::Auth qw( get_template_and_user );

use HTML::Entities;
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;

use lib  qw(..);
use JSON qw( );

my $keyfile = "apikeys.json";

my $json_keys = do {
    open( my $json_fh, "<:encoding(UTF-8)", $keyfile )
        or die("Can't open \"$keyfile\": $!\n");
    local $/;
    <$json_fh>;
};

my $json        = JSON->new;
my $libris_keys = $json->decode($json_keys);

my $query = CGI->new();

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name => "intranet-main.tt",
        query         => $query,
        type          => "intranet",
        flagsrequired => { catalogue => 1, }
    }
);

# Search query
my $branch = $query->param('branch');
my $start  = $query->param('start');
my $end    = $query->param('end');
my $ill_id = $query->param('ill_id');

my $ua = LWP::UserAgent->new;
$ua->agent("Koha ILL");

# Setup variables
my $string     = "librisfjarrlan/api/illrequests";
my $host       = "iller.libris.kb.se";
my $protocol   = "https";
my $libris_key = $libris_keys->{data}[0]{$branch};

# Build the url
my $url =
    ($ill_id)
    ? "$protocol://$host/$string/$branch/$ill_id"
    : "$protocol://$host/$string/$branch/outgoing?start_date=$start" . "&end_date=$end";

# Fetch the actual data from the query
my $request = HTTP::Request->new( "GET" => $url );

$request->header( 'api-key' => $libris_key );

#$request->content_type('application/json');

my $response = $ua->request($request);

my $cgi = CGI->new;
print $cgi->header( -type => "application/json", -charset => "utf-8" );

my $jsonString = $response->content;

# Finally print JSON
print $jsonString;
