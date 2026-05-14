package Koha::REST::V1::Acquisitions::EdiAccounts;

# Copyright 2026 Open Fifth

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

use C4::Context;
use Koha::File::Transports;
use Koha::Plugins;
use Koha::VendorEdiAccount;
use Koha::VendorEdiAccounts;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $accounts = $c->objects->search( Koha::VendorEdiAccounts->new );
        return $c->render( status => 200, openapi => $accounts );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $account = Koha::VendorEdiAccounts->find( $c->param('vendor_edi_account_id') );
        return $c->render_resource_not_found("EDI account")
            unless $account;

        return $c->render( status => 200, openapi => $c->objects->to_api($account) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body    = $c->req->json;
        my $account = Koha::VendorEdiAccount->new_from_api($body)->store->discard_changes;
        $c->res->headers->location( $c->req->url->to_string . '/' . $account->id );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($account)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $account = Koha::VendorEdiAccounts->find( $c->param('vendor_edi_account_id') );
    return $c->render_resource_not_found("EDI account")
        unless $account;

    return try {
        $account->set_from_api( $c->req->json )->store;
        return $c->render( status => 200, openapi => $c->objects->to_api($account) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $account = Koha::VendorEdiAccounts->find( $c->param('vendor_edi_account_id') );
    return $c->render_resource_not_found("EDI account")
        unless $account;

    return try {
        $account->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 config

=cut

sub config {
    my $c = shift->openapi->valid_input or return;

    return try {
        my @file_transports = map {
            {
                file_transport_id => $_->id,
                name              => $_->name,
                transport         => $_->transport,
                host              => $_->host // '',
            }
        } Koha::File::Transports->search( {}, { order_by => { -asc => 'name' } } )->as_list;

        my @plugins = ();
        if ( C4::Context->config("enable_plugins") ) {
            @plugins = map { { class => $_->class, name => $_->metadata->{name} } }
                Koha::Plugins->new()->GetPlugins( { method => 'edifact' } );
        }

        return $c->render(
            status  => 200,
            openapi => { file_transports => \@file_transports, plugins => \@plugins }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
