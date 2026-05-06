package Koha::REST::V1::Acquisitions::Invoicing::Invoices;

# Copyright 2024 PTFS Europe

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

use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny;

use Koha::Acquisition::Invoicing::Invoice;
use Koha::Acquisition::Invoicing::Invoices;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $invoices = $c->objects->search( Koha::Acquisition::Invoicing::Invoices->new );
        return $c->render( status => 200, openapi => $invoices );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $invoice = Koha::Acquisition::Invoicing::Invoices->find( $c->param('invoice_id') );
        return $c->render_resource_not_found("Invoice")
            unless $invoice;

        return $c->render( status => 200, openapi => $c->objects->to_api($invoice) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                my $body    = $c->req->json;
                my $invoice = Koha::Acquisition::Invoicing::Invoice->new_from_api($body)->store->discard_changes;

                $c->res->headers->location( $c->req->url->to_string . '/' . $invoice->invoice_id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($invoice)
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $invoice = Koha::Acquisition::Invoicing::Invoices->find( $c->param('invoice_id') );
    return $c->render_resource_not_found("Invoice")
        unless $invoice;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                my $body = $c->req->json;
                $invoice->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $invoice->invoice_id );
                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($invoice)
                );
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $invoice = Koha::Acquisition::Invoicing::Invoices->find( $c->param('invoice_id') );
    return $c->render_resource_not_found("Invoice")
        unless $invoice;

    return try {
        $invoice->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
