#!/usr/bin/perl

# Copyright 2011 BibLibre SARL
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

=head1 NAME

itemrecorddisplay.pl

=head1 DESCRIPTION

Return a HTML form for Item record modification or creation.
It uses PrepareItemrecordDisplay

=cut

use Modern::Perl;

use CGI        qw ( -utf8 );
use JSON       qw( to_json );
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers output_with_http_headers );
use C4::Items  qw( PrepareItemrecordDisplay );
use Koha::Item;

my $input = CGI->new;
my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name => 'services/itemrecorddisplay.tt',
        query         => $input,
        type          => 'intranet',
        flagsrequired => { acquisition => '*' },
    }
);

my $biblionumber    = $input->param('biblionumber')    || '';
my $itemnumber      = $input->param('itemnumber')      || '';
my $frameworkcode   = $input->param('frameworkcode')   || '';
my $return_api_json = $input->param('return_api_json') || '';

my $result = PrepareItemrecordDisplay( $biblionumber, $itemnumber, undef, $frameworkcode );
unless ($result) {
    $result = PrepareItemrecordDisplay( $biblionumber, $itemnumber, undef, '' );
}

$template->param(%$result);

if ($return_api_json) {
    my $api_mapping = Koha::Item->new->to_api_mapping;

    for my $field ( @{ $result->{iteminformation} } ) {
        my $kohafield = $field->{kohafield} // '';
        if ( $kohafield =~ s/^items\.// ) {
            $field->{api_name} = $api_mapping->{$kohafield} || $kohafield;
        }
    }

    output_with_http_headers $input, undef, to_json( $result, { utf8 => 1 } ), 'json';
    exit 0;
}

output_html_with_http_headers $input, $cookie, $template->output;
