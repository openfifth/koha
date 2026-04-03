package Koha::REST::V1::Auth::Identity::Provider::Mappings;

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

use Koha::Auth::Identity::Provider::Mapping;
use Koha::Auth::Identity::Provider::Mappings;
use Koha::Auth::Identity::Providers;

use Koha::Database;

use Scalar::Util qw(blessed);
use Try::Tiny;

=head1 NAME

Koha::REST::V1::Auth::Identity::Provider::Mappings - Controller for identity
provider field mapping routes.

=head2 Operations

=head3 list

Controller method for listing field mappings for an identity provider.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $provider = Koha::Auth::Identity::Providers->find( $c->param('identity_provider_id') );

        return $c->render_resource_not_found("Identity provider")
            unless $provider;

        my $mappings_rs = $provider->mappings;
        return $c->render(
            status  => 200,
            openapi => $c->objects->search($mappings_rs)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller method for retrieving a single field mapping.

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $provider = Koha::Auth::Identity::Providers->find( $c->param('identity_provider_id') );

        return $c->render_resource_not_found("Identity provider")
            unless $provider;

        my $mapping = $c->objects->find(
            $provider->mappings,
            $c->param('identity_provider_mapping_id')
        );

        return $c->render_resource_not_found("Identity provider mapping")
            unless $mapping;

        return $c->render( status => 200, openapi => $mapping );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller method for adding a field mapping to an identity provider.

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $provider = Koha::Auth::Identity::Providers->find( $c->param('identity_provider_id') );

        return $c->render_resource_not_found("Identity provider")
            unless $provider;

        Koha::Database->new->schema->txn_do(
            sub {
                my $params = $c->req->json;
                $params->{identity_provider_id} = $c->param('identity_provider_id');

                my $mapping = Koha::Auth::Identity::Provider::Mapping->new_from_api($params);
                $mapping->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $mapping->id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($mapping),
                );
            }
        );
    } catch {
        if ( blessed($_) and $_->isa('Koha::Exceptions::MissingParameter') ) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'Missing parameter: ' . $_->parameter,
                    error_code => 'missing_parameter',
                }
            );
        }

        $c->unhandled_exception($_);
    };
}

=head3 update

Controller method for updating a field mapping.

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $mapping = Koha::Auth::Identity::Provider::Mappings->find(
        {
            identity_provider_id => $c->param('identity_provider_id'),
            mapping_id           => $c->param('identity_provider_mapping_id'),
        }
    );

    return $c->render_resource_not_found("Identity provider mapping")
        unless $mapping;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                $mapping->set_from_api( $c->req->json );
                $mapping->store->discard_changes;

                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($mapping),
                );
            }
        );
    } catch {
        if ( blessed($_) and $_->isa('Koha::Exceptions::MissingParameter') ) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => 'Missing parameter: ' . $_->parameter,
                    error_code => 'missing_parameter',
                }
            );
        }

        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller method for deleting a field mapping.

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $mapping = Koha::Auth::Identity::Provider::Mappings->find(
        {
            identity_provider_id => $c->param('identity_provider_id'),
            mapping_id           => $c->param('identity_provider_mapping_id'),
        }
    );

    return $c->render_resource_not_found("Identity provider mapping")
        unless $mapping;

    return try {
        $mapping->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
