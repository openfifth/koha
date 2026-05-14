#!/usr/bin/perl

#
# Copyright 2012 Bywater Solutions
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

use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );

use C4::CourseReserves qw( SearchCourses );

my $cgi = CGI->new;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-thesis-tables.tt",
        query           => $cgi,
        type            => "opac",
        authnotrequired => 1,
    }
);

my $courses = SearchCourses( enabled => 'yes', course_type => 'RESEARCH_TABLE' );

# Get the display text for this course type from authorized values
my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare(
    "SELECT lib_opac FROM authorised_values WHERE category='CR_TYPE' AND authorised_value='RESEARCH_TABLE'");
$sth->execute();
my $display_name = $sth->fetchrow_array() || 'Research tables';

$template->param(
    courses             => $courses,
    course_type_display => $display_name,
);
output_html_with_http_headers $cgi, $cookie, $template->output;
