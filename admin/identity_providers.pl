#!/usr/bin/perl

# Copyright 2022 Theke Solutions
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

use C4::Auth    qw( get_template_and_user );
use C4::Context qw();
use C4::Output  qw( output_html_with_http_headers );

use Koha::Patron::Attribute::Types;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::Patrons;

my $input = CGI->new;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => 'admin/identity_providers.tt',
        query         => $input,
        type          => "intranet",
        flagsrequired => { parameters => 'manage_identity_providers' },
    }
);

my $borrowers_source = Koha::Patrons->_resultset->result_source;
my @borrower_columns;
my %skip_columns = map { $_ => 1 } qw( password updated_on timestamp );
foreach my $column ( sort $borrowers_source->columns ) {
    next if $skip_columns{$column};
    my $column_info = $borrowers_source->column_info($column);
    my $label       = $column_info->{comments} || $column;
    push @borrower_columns, { value => $column, label => $label };
}

my @libraries_map = map { { value => $_->branchcode, label => $_->branchname } }
    Koha::Libraries->search( {}, { order_by => 'branchname' } )->as_list;

my @categories_map = map { { value => $_->categorycode, label => $_->description } }
    Koha::Patron::Categories->search( {}, { order_by => 'description' } )->as_list;

my @unique_patron_attributes = map {
    {
        value => 'patron_attribute:' . $_->code,
        label => sprintf( '%s (%s)', $_->description, $_->code ),
    }
} Koha::Patron::Attribute::Types->search(
    { unique_id => 1 },
    { order_by  => 'description' }
)->as_list;

my @all_patron_attributes = map {
    {
        value => 'patron_attribute:' . $_->code,
        label => sprintf( '%s (%s)', $_->description, $_->code ),
    }
} Koha::Patron::Attribute::Types->search(
    {},
    { order_by => 'description' }
)->as_list;

my @idp_default_hostnames;
for my $pref (qw( OPACBaseURL staffClientBaseURL )) {
    my $url = C4::Context->preference($pref);
    next unless $url;
    my ($hostname) = $url =~ m|^https?://([^/:?#]+)|;
    push @idp_default_hostnames, $hostname if $hostname;
}

$template->param(
    borrower_columns         => \@borrower_columns,
    libraries_map            => \@libraries_map,
    categories_map           => \@categories_map,
    idp_default_hostnames    => \@idp_default_hostnames,
    unique_patron_attributes => \@unique_patron_attributes,
    all_patron_attributes    => \@all_patron_attributes,
);

output_html_with_http_headers $input, $cookie, $template->output;
