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

use CGI      qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
use C4::Koha;
use C4::Output      qw( output_html_with_http_headers );
use Koha::DateUtils qw( dt_from_string );
use Koha::ILL::Requests;
use Koha::ILL::Request;
use Koha::ILL::Request::Workflow::TypeDisclaimer;

my $query = CGI->new;

# Grab all passed data
# 'our' since Plack changes the scoping
# of 'my'
our $params = $query->Vars();

# if illrequests is disabled, leave immediately
if ( !C4::Context->preference('ILLModule') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $op = Koha::ILL::Request->get_op_param_deprecation( 'opac', $params );

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-illrequests.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
    }
);

my $illrequest_id = $params->{illrequest_id};
my $uuid          = $params->{uuid};

my $request = Koha::ILL::Requests->find($illrequest_id);

if ( !$request ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $backends = Koha::ILL::Request::Config->new->opac_available_backends();
$params->{stage} = 'form';
$params->{type}  = $request->get_type();

if ( $params->{backend} && !grep { $_ eq $params->{backend} } @$backends ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $backends_available = ( scalar @{$backends} > 0 );
$template->param( backends_available => $backends_available );

my $dtf    = Koha::Database->new->schema->storage->datetime_parser;
my $prompt = $request->type_disclaimer_prompts->search(
    {
        uuid        => $uuid,
        patron_id   => $request->borrowernumber,
        valid_until => { '>=' => $dtf->format_datetime( dt_from_string() ) }
    }
)->next;

if ( !$prompt ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

if ( $prompt->date_replied ) {
    $template->param( op => 'typedisclaimer_confirmed' );
    output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
    exit;
}

my $type_disclaimer = Koha::ILL::Request::Workflow::TypeDisclaimer->new( $params, 'opac' );

if ( $params->{type_disclaimer_submitted} ) {
    if ( $type_disclaimer->after_request_created( $params, $request ) ) {
        $prompt->update( { date_replied => dt_from_string } );
        $template->param( op => 'typedisclaimer_confirmed' );
    } else {
        $template->param( $type_disclaimer->type_disclaimer_template_params($params) );
    }
} elsif ( $type_disclaimer->show_type_disclaimer($request) ) {
    $template->param( $type_disclaimer->type_disclaimer_template_params($params) );
}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
