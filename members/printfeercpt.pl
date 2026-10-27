#!/usr/bin/perl

# Copyright Koustubha Kale 2010
# Copyright PTFS Europe 2020
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

use C4::Auth     qw( get_template_and_user );
use C4::Output   qw( output_and_exit_if_error output_and_exit output_html_with_http_headers );
use CGI          qw ( -utf8 );
use Scalar::Util qw( looks_like_number );
use C4::Letters;
use Koha::Account::Lines;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "members/printfeercpt.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => {
            borrowers     => 'edit_borrowers',
            updatecharges => 'remaining_permissions'
        }
    }
);

my $credit_id = $input->param('accountlines_id');
my $credit    = Koha::Account::Lines->find($credit_id);
my $patron    = $credit->patron;

my $logged_in_user = Koha::Patrons->find($loggedinuser) or die "Not logged in";
output_and_exit_if_error(
    $input, $cookie,
    $template,
    {
        module         => 'members',
        logged_in_user => $logged_in_user,
        current_patron => $patron
    }
);

my $tendered = scalar $input->param('tendered');
my $change   = scalar $input->param('change');

# The Accounting pages only pass 'change' when opening the receipt, whereas
# the POS receipt passes both. The amount tendered is the amount paid plus the
# change given, so work it out here rather than leaving it blank. An explicit
# 'tendered' parameter always wins, and without a change figure (a reprint,
# or a payment with no change) there is nothing to derive it from.
if ( !( defined $tendered && length $tendered ) && defined $change && looks_like_number($change) ) {
    $tendered = $credit->amount * -1 + $change;
}

my $substitute = {
    tendered => $tendered,
    change   => $change,
};

my $letter = C4::Letters::GetPreparedLetter(
    module                 => 'circulation',
    letter_code            => 'CREDIT_' . $credit->credit_type_code,
    branchcode             => C4::Context::mybranch,
    message_transport_type => 'print',
    lang                   => $patron->lang,
    tables                 => {
        credits   => $credit_id,
        borrowers => $patron->borrowernumber
    },
    substitute => $substitute
);

$letter //= C4::Letters::GetPreparedLetter(
    module                 => 'circulation',
    letter_code            => 'ACCOUNT_CREDIT',
    branchcode             => C4::Context::mybranch,
    message_transport_type => 'print',
    lang                   => $patron->lang,
    tables                 => {
        credits   => $credit_id,
        borrowers => $patron->borrowernumber
    },
    substitute => $substitute
);

$template->param(
    slip   => $letter->{content},
    plain  => !$letter->{is_html},
    patron => $patron,
    style  => $letter->{style},
);

output_html_with_http_headers $input, $cookie, $template->output;
