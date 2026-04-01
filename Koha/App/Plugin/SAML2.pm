package Koha::App::Plugin::SAML2;

# Copyright 2025 Koha Development Team
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

use Mojo::Base 'Mojolicious::Plugin';

=head1 NAME

Koha::App::Plugin::SAML2

=head1 SYNOPSIS

    $app->plugin( 'SAML2', { interface => 'staff' } );   # in Intranet
    $app->plugin( 'SAML2', { interface => 'opac'  } );   # in Opac

=head1 DESCRIPTION

Registers the C</auth/saml2/*> routes and points them at
L<Koha::App::Controller::SAML2>.  The C<interface> parameter ('staff' or
'opac') is stored in the route stash and tells the controller which Koha
interface is in use.

=head1 METHODS

=head2 register

Called at application startup; registers C</auth/saml2/*> routes.

=cut

sub register {
    my ( $self, $app, $conf ) = @_;

    my $interface = $conf->{interface} // 'opac';
    my $r         = $app->routes;

    $r->get('/auth/saml2/login')->to( 'SAML2#login', interface => $interface );
    $r->post('/auth/saml2/acs')->to( 'SAML2#acs', interface => $interface, csrf_exempt => 1 );
    $r->get('/auth/saml2/logout')->to( 'SAML2#logout', interface => $interface );
    $r->get('/auth/saml2/sls')->to( 'SAML2#sls', interface => $interface );
    $r->get('/auth/saml2/metadata')->to( 'SAML2#metadata', interface => $interface );
    $r->get('/auth/saml2/attributes')->to( 'SAML2#attributes', interface => $interface );
}

1;

=encoding utf8

=head1 SEE ALSO

L<Koha::App::Controller::SAML2>

=cut
