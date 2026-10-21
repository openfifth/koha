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
use CGI        qw ( -utf8 );
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );

use Koha::Tickets;

my $query = CGI->new;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-ticket-verify.tt",
        type            => "opac",
        query           => $query,
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
    }
);

my $uuid = $query->param('uuid');

unless ($uuid) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $ticket = Koha::Tickets->search( { verify_uuid => $uuid } )->next;

unless ($ticket) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my $op = $query->param('op');

if ( $op eq 'cud-verify' ) {
    $ticket->verify_uuid(undef);
    $ticket->store();

    $template->param( verified => 1 );
}

$template->param( uuid => $uuid );

output_html_with_http_headers $query, $cookie, $template->output;
