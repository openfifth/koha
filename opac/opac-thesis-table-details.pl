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

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );

use C4::CourseReserves qw( GetCourse GetCourseReserves );

my $cgi = CGI->new;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-thesis-table-details.tt",
        query           => $cgi,
        type            => "opac",
        authnotrequired => 1,
    }
);

my $table_id = $cgi->param('table_id');

die("No table_id given") unless ($table_id);

my $course          = GetCourse($table_id);
my $course_reserves = GetCourseReserves( course_id => $table_id, include_items => 1, include_count => 1 );

# Get the display text for this course type from authorized values
my $dbh         = C4::Context->dbh;
my $course_type = $course->{course_type} || 'RESEARCH_TABLE';
my $sth = $dbh->prepare("SELECT lib_opac FROM authorised_values WHERE category='CR_TYPE' AND authorised_value=?");
$sth->execute($course_type);
my $display_name = $sth->fetchrow_array() || 'Research tables';

$template->param(
    course              => $course,
    course_reserves     => $course_reserves,
    course_type_display => $display_name,
);

output_html_with_http_headers $cgi, $cookie, $template->output;
