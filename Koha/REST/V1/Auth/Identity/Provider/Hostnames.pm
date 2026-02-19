package Koha::REST::V1::Auth::Identity::Provider::Hostnames;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Auth::Identity::Provider::Hostname;
use Koha::Auth::Identity::Provider::Hostnames;

use Koha::Database;

use Scalar::Util qw(blessed);
use Try::Tiny;

=head1 NAME

Koha::REST::V1::Auth::Identity::Provider::Hostnames - Controller library for handling
identity provider hostname routes.

Each row is a many-to-many association between a hostname (via hostname_id FK) and an
identity provider. The unique constraint is on (hostname_id, identity_provider_id).

=head2 Operations

=head3 list

Controller method for listing all identity provider hostnames.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $hostnames_rs = Koha::Auth::Identity::Provider::Hostnames->new;
        return $c->render(
            status  => 200,
            openapi => $c->objects->search($hostnames_rs),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller method for retrieving an identity provider hostname.

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $hostname = $c->objects->find(
            Koha::Auth::Identity::Provider::Hostnames->new,
            $c->param('identity_provider_hostname_id')
        );

        return $c->render_resource_not_found("Identity provider hostname")
            unless $hostname;

        return $c->render( status => 200, openapi => $hostname );
    } catch {
        $c->unhandled_exception($_);
    }
}

=head3 add

Controller method for adding an identity provider hostname.

Accepts either a C<hostname_id> integer (direct FK reference) or a C<hostname>
string (the backend will find-or-create the canonical hostname record and resolve
it to a C<hostname_id> before creating the bridge row).

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                my $body = $c->req->json;

                # If caller sent a hostname string instead of hostname_id,
                # resolve it via find_or_create on the hostnames table.
                unless ( $body->{hostname_id} ) {
                    my $hostname_str = delete $body->{hostname};
                    my $hostname_rec = Koha::Database->new->schema->resultset('Hostname')
                        ->find_or_create( { hostname => $hostname_str } );
                    $body->{hostname_id} = $hostname_rec->hostname_id;
                } else {

                    # hostname string is readOnly in the schema; strip it if present
                    delete $body->{hostname};
                }

                my $hostname = Koha::Auth::Identity::Provider::Hostname->new_from_api($body);
                $hostname->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $hostname->id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($hostname),
                );
            }
        );
    } catch {
        if ( blessed($_) and $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'A hostname entry with this hostname already exists for this provider',
                    error_code => 'duplicate_hostname',
                }
            );
        }

        $c->unhandled_exception($_);
    };
}

=head3 update

Controller method for updating an identity provider hostname.

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $hostname = Koha::Auth::Identity::Provider::Hostnames->find( $c->param('identity_provider_hostname_id') );

    return $c->render_resource_not_found("Identity provider hostname")
        unless $hostname;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                my $body = $c->req->json;

                # hostname string is readOnly; strip it to avoid set_from_api errors
                delete $body->{hostname};

                $hostname->set_from_api($body);
                $hostname->store->discard_changes;

                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($hostname),
                );
            }
        );
    } catch {
        if ( blessed($_) and $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error      => 'A hostname entry with this hostname already exists for this provider',
                    error_code => 'duplicate_hostname',
                }
            );
        }

        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller method for deleting an identity provider hostname.

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $hostname = Koha::Auth::Identity::Provider::Hostnames->find( $c->param('identity_provider_hostname_id') );

    return $c->render_resource_not_found("Identity provider hostname")
        unless $hostname;

    return try {
        $hostname->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
