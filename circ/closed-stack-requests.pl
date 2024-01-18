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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use CGI '-utf8';

use C4::Output qw( output_html_with_http_headers );
use C4::Auth   qw( get_template_and_user );
use Koha::Holds;
use Koha::I18N;

my $cgi = CGI->new;

my $op = $cgi->param('op') || '';
if ( $op eq 'cud-print_slip' ) {
    my $reserve_id = $cgi->param('reserve_id');

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {
            template_name => 'circ/printslip.tt',
            query         => $cgi,
            type          => 'intranet',
            flagsrequired => { circulate => 'circulate_remaining_permissions' },
        }
    );

    my $hold = Koha::Holds->find($reserve_id);

    my $letter = C4::Letters::GetPreparedLetter(
        module                 => 'reserves',
        letter_code            => 'CLOSED_STACK_SLIP',
        branchcode             => $hold->branchcode,
        lang                   => $hold->patron->lang,
        message_transport_type => 'print',
        tables                 => {
            reserves    => $hold->unblessed,
            branches    => $hold->branchcode,
            borrowers   => $hold->borrowernumber,
            biblio      => $hold->biblionumber,
            biblioitems => $hold->biblionumber,
            items       => $hold->itemnumber,
        },
        objects => {
            hold => $hold,
        }
    );
    if ($letter) {
        $template->param(
            title => __('Closed stack request slip'),
            slip  => $letter->{content},
            plain => !$letter->{is_html},
        );
        $hold->closed_stack_request_slip_printed(1);
        $hold->store();
    }

    output_html_with_http_headers $cgi, $cookie, $template->output;
    exit;
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "circ/closed-stack-requests.tt",
        query         => $cgi,
        type          => "intranet",
        flagsrequired => { circulate => "circulate_remaining_permissions" },
    }
);

my @messages;
if ( $op eq 'cud-cancel_reserve' ) {
    my $reserve_id = $cgi->param('reserve_id');
    my $hold       = Koha::Holds->find($reserve_id);
    if ($hold) {
        my $cancellation_reason = $cgi->param('cancellation-reason');
        $hold->cancel( { cancellation_reason => $cancellation_reason } );
        push @messages, { type => 'message', code => 'hold_cancelled' };
    }
}

my $holds = Koha::Holds->search()->filter_by_closed_stack_requests();

my $branchcode = $cgi->param('branchcode') // C4::Context->userenv->{branch};
if ( $branchcode ne '' ) {
    $holds = $holds->search( { branchcode => $branchcode } );
}
$template->param( branchcode => $branchcode );

my ( @pending_holds, @printed_slip_holds );

foreach my $hold ( $holds->as_list ) {
    if ( $hold->closed_stack_request_slip_printed ) {
        push @printed_slip_holds, $hold;
    } else {
        push @pending_holds, $hold;
    }
}

$template->param(
    pending_holds      => \@pending_holds,
    printed_slip_holds => \@printed_slip_holds,
    messages           => \@messages,
);

output_html_with_http_headers $cgi, $cookie, $template->output;
