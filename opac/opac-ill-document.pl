#!/usr/bin/perl

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

use CGI qw ( -utf8 );

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use Koha::ILL::Documents;

my $query = CGI->new;

if ( !C4::Context->preference('ILLModule') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-ill-document.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => C4::Context->preference("OpacPublic") ? 1 : 0,
    }
);

my $op    = $query->param('op') // q{};
my $token = $query->param('token');

my $document =
    $token
    ? Koha::ILL::Documents->search( { token => $token, illrequest_id => { '!=' => undef } } )->next
    : undef;

if ( $document && $op eq 'cud-download' ) {
    $document->record_download;
    print $query->header(
        -type       => $document->file_type,
        -attachment => $document->file_name,
    );
    print $document->file_content;
    exit;
}

$template->param(
    document => $document,
    token    => $token,
);

output_html_with_http_headers $query, $cookie, $template->output;
