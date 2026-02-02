#!/usr/bin/perl

use Modern::Perl;

use CGI        qw ( -utf8 );
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use Koha::Patrons;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "shibboleth/shibboleth.tt",
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

    push @borrower_columns,
        {
        value => $column,
        label => $label,
        };
}

$template->param( borrower_columns => \@borrower_columns );

output_html_with_http_headers $input, $cookie, $template->output;
