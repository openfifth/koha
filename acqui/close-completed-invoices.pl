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

use CGI        qw( -utf8 );
use Try::Tiny;
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );

use Koha::Acquisition::Invoices;

my $input = CGI->new;
my $op    = $input->param('op') // q{};

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => 'acqui/close-completed-invoices.tt',
        query         => $input,
        type          => 'intranet',
        flagsrequired => { acquisition => 'order_manage' },
    }
);

my @results;

if ( $op eq 'cud-run' ) {
    my $open_invoices = Koha::Acquisition::Invoices->search( { closedate => undef } );

    while ( my $invoice = $open_invoices->next ) {
        my $closed = 0;
        try {
            $closed = $invoice->check_and_close;
        } catch {
            warn sprintf( "Error closing invoice %s: %s", $invoice->invoiceid, $_ );
        };
        push @results, {
            invoiceid     => $invoice->invoiceid,
            invoicenumber => $invoice->invoicenumber,
            closed        => $closed,
        };
    }
    $template->param( results => \@results, ran => 1 );
}

output_html_with_http_headers( $input, $cookie, $template->output );
