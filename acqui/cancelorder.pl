#!/usr/bin/perl

# Copyright 2014 BibLibre
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

=head1 NAME

cancelorder.pl

=head1 DESCRIPTION

Ask confirmation for cancelling an order line
and add possibility to indicate a reason for cancellation
(saved in aqorders.notes).

Patrons who have placed holds on the items of the order (or on the record, when
nothing else would be left to fill them) are listed, and the librarian can choose to
cancel those holds, with a HOLD_CANCELLATION reason, so the patrons are told and the
items can be deleted.

=cut

use Modern::Perl;

use CGI;
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Log    qw(logaction);
use Koha::Acquisition::Baskets;
use Koha::AuthorisedValues;
use Koha::Notice::Templates;
use Koha::Patrons;

my $input = CGI->new;
my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name => 'acqui/cancelorder.tt',
        query         => $input,
        type          => 'intranet',
        flagsrequired => { 'acquisition' => 'order_manage' },
    }
);

my $op            = $input->param('op') || q{};
my $ordernumber   = $input->param('ordernumber');
my $biblionumber  = $input->param('biblionumber');
my $order         = Koha::Acquisition::Orders->find($ordernumber);
my $basketno      = $order->basketno;
my $basket        = Koha::Acquisition::Baskets->find( { basketno => $basketno }, { prefetch => 'booksellerid' } );
my $referrer      = $input->param('referrer') || $input->referer;
my $delete_biblio = $input->param('del_biblio') ? 1 : 0;

# Holds that could no longer be filled, and whether this librarian may cancel them
my $orphaned_holds = $order ? $order->holds_orphaned_by_cancellation : undef;
my $can_cancel_holds =
    Koha::Patrons->find($loggedinuser)->has_permission( { reserveforothers => '*' } ) ? 1 : 0;
my $cancel_holds =
    $can_cancel_holds && $orphaned_holds && $orphaned_holds->count && $input->param('cancel_holds') ? 1 : 0;
my $hold_reason = $input->param('hold_cancellation_reason');

# Cancelling holds needs a reason, as that is what tells the patrons why
if ( $op eq "cud-confirmcancel" && $cancel_holds && !$hold_reason ) {
    $template->param( error_hold_reason_required => 1 );
    $op = q{};
}

if ( $op eq "cud-confirmcancel" ) {
    my $reason = $input->param('reason');
    my @messages;
    if ( !$order ) {
        push @messages, Koha::Object::Message->new( { message => 'error_order_not_found', type => 'error' } );
        $template->param( error_order_not_found => 1 );
    } elsif ( $order->datecancellationprinted ) {
        push @messages, Koha::Object::Message->new( { message => 'error_order_already_cancelled', type => 'error' } );
        $template->param( error_order_already_cancelled => 1 );
    } else {
        $order->cancel(
            {
                reason        => $reason,
                delete_biblio => $delete_biblio,
                ( $cancel_holds ? ( cancel_holds => 1, hold_cancellation_reason => $hold_reason ) : () ),
            }
        );
        @messages = @{ $order->object_messages };
    }

    # Cancelling holds is reported with the other messages, but it is not a problem
    my ($holds_cancelled) = grep { $_->message eq 'holds_cancelled' } @messages;
    $template->param(
        holds_cancelled => $holds_cancelled->payload->{count},
        holds_notified  => $holds_cancelled->payload->{notified},
    ) if $holds_cancelled;
    @messages = grep { $_->message ne 'holds_cancelled' } @messages;

    if ( scalar @messages > 0 ) {
        $template->param( error_delitem => 1 )
            if grep { $_->message eq 'error_delitem' } @messages;
        $template->param( error_delbiblio => 1 )
            if grep { $_->message eq 'error_delbiblio' } @messages;
    } else {

        # Log the cancellation of the order
        if ( C4::Context->preference("AcquisitionLog") ) {
            logaction( 'ACQUISITIONS', 'CANCEL_ORDER', $ordernumber );
        }
        $template->param( success_cancelorder => 1 );
    }
    $template->param( confirmcancel => 1 );
}

$template->param(
    ordernumber             => $ordernumber,
    biblionumber            => $biblionumber,
    basket                  => $basket,
    referrer                => $referrer,
    del_biblio              => $delete_biblio,
    orphaned_holds          => $orphaned_holds,
    can_cancel_holds        => $can_cancel_holds,
    has_cancellation_notice => Koha::Notice::Templates->search(
        { module => 'reserves', code => 'HOLD_CANCELLATION', message_transport_type => 'email' }
    )->count,
);

output_html_with_http_headers $input, $cookie, $template->output;
