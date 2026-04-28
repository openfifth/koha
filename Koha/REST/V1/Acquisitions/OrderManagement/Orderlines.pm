package Koha::REST::V1::Acquisitions::OrderManagement::Orderlines;

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
use Mojo::JSON qw(decode_json);
use Try::Tiny;

use Koha::Acquisition::OrderManagement::Orderline;
use Koha::Acquisition::OrderManagement::Orderlines;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $orderlines = $c->objects->search( Koha::Acquisition::OrderManagement::Orderlines->new );
        return $c->render( status => 200, openapi => $orderlines );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $orderline = Koha::Acquisition::OrderManagement::Orderlines->find( $c->param('orderline_id') );
        return $c->render_resource_not_found("Orderline")
            unless $orderline;

        return $c->render( status => 200, openapi => $c->objects->to_api($orderline), );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body           = $c->req->json;
    my %orderline_copy = %$body;

    my $extended_attributes   = delete $body->{extended_attributes}                 // [];
    my $patrons_to_notify     = delete $body->{patrons_to_notify}                   // [];
    my $managed_by            = delete $body->{managed_by}                          // [];
    my $fund_distributions    = delete $body->{fund_distributions}                  // [];
    my $biblio                = delete $body->{biblio}                              // {};
    my $items                 = delete $body->{items}                               // [];
    my $confirm_not_duplicate = $c->req->headers->header('x-confirm-not-duplicate') // 0;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                $body->{status}         = $body->{vendor_id} ? "NEW" : "DRAFT";
                $body->{status}         = 'DRAFT' if scalar(@$fund_distributions) == 0;
                $body->{payment_status} = "PENDING";
                my $user = $c->stash('koha.user');
                $body->{created_by} = $user->borrowernumber;

                my $orderline =
                    Koha::Acquisition::OrderManagement::Orderline->new_from_api($body)->store->discard_changes;

                $orderline->add_patron_relationships(
                    { patrons_to_notify => $patrons_to_notify, managed_by => $managed_by } );
                $orderline->fund_distributions($fund_distributions);
                $orderline->biblio( { biblio_data => $biblio, confirm_not_duplicate => $confirm_not_duplicate } )
                    unless $orderline->biblionumber;

                $orderline->items($items) if @$items && !$orderline->is_continuous;

                my @extended_attributes =
                    map { { 'id' => $_->{field_id}, 'value' => $_->{value} } } @{$extended_attributes};
                $orderline->extended_attributes( \@extended_attributes );

                $c->res->headers->location( $c->req->url->to_string . '/' . $orderline->orderline_id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($orderline)
                );
            }
        )
    } catch {
        warn $_;
        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::DuplicateObject') ) {
                my $duplicate_biblio = Koha::Biblios->find( $_->error );

                return $c->render(
                    status  => 409,
                    openapi => {
                        error     => "bib_match",      new_biblio     => $biblio, duplicate_biblio => $duplicate_biblio,
                        orderline => \%orderline_copy, dialog_confirm => 1
                    }
                );
            }
        }
        return $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Acquisition::OrderManagement::Orderline object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $orderline = Koha::Acquisition::OrderManagement::Orderlines->find( $c->param('orderline_id') );

    return $c->render_resource_not_found("Orderline")
        unless $orderline;

    return try {
        my $body = $c->req->json;

        my $extended_attributes   = delete $body->{extended_attributes}                 // [];
        my $patrons_to_notify     = delete $body->{patrons_to_notify}                   // [];
        my $managed_by            = delete $body->{managed_by}                          // [];
        my $fund_distributions    = delete $body->{fund_distributions}                  // [];
        my $biblio                = delete $body->{biblio}                              // {};
        my $items                 = delete $body->{items}                               // [];
        my $confirm_not_duplicate = $c->req->headers->header('x-confirm-not-duplicate') // 0;

        delete $body->{modified_date} if $body->{modified_date};
        delete $body->{created_date}  if $body->{created_date};

        $orderline->set_from_api($body)->store;

        $orderline->add_patron_relationships( { patrons_to_notify => $patrons_to_notify, managed_by => $managed_by } );
        $orderline->fund_distributions($fund_distributions);
        $orderline->biblio( { biblio_data => $biblio, confirm_not_duplicate => $confirm_not_duplicate } )
            unless $orderline->biblionumber;

        $orderline->items($items) if @$items && !$orderline->is_continuous;

        my @extended_attributes =
            map { { 'id' => $_->{field_id}, 'value' => $_->{value} } } @{$extended_attributes};
        $orderline->extended_attributes( \@extended_attributes );

        $c->res->headers->location( $c->req->url->to_string . '/' . $orderline->orderline_id );
        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($orderline)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $orderline = Koha::Acquisition::OrderManagement::Orderlines->find( $c->param('orderline_id') );
    return $c->render_resource_not_found("Orderline")
        unless $orderline;

    return try {
        $orderline->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
