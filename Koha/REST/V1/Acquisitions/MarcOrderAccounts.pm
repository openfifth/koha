package Koha::REST::V1::Acquisitions::MarcOrderAccounts;

# Copyright 2025 PTFS Europe

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

use C4::Matcher;

use Koha::MarcOrderAccount;
use Koha::MarcOrderAccounts;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $accounts = $c->objects->search( Koha::MarcOrderAccounts->new );
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
        my $account = Koha::MarcOrderAccounts->find( $c->param('marc_order_account_id') );
        return $c->render_resource_not_found("MARC order account")
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
        my $account = Koha::MarcOrderAccount->new_from_api($body)->store->discard_changes;
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

    my $account = Koha::MarcOrderAccounts->find( $c->param('marc_order_account_id') );
    return $c->render_resource_not_found("MARC order account")
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

    my $account = Koha::MarcOrderAccounts->find( $c->param('marc_order_account_id') );
    return $c->render_resource_not_found("MARC order account")
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
        my @matchers = C4::Matcher::GetMatcherList();
        return $c->render(
            status  => 200,
            openapi => { matchers => \@matchers }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
