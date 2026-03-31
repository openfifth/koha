package Koha::Auth::Identity::Provider::SAML2;

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

use base qw(Koha::Auth::Identity::Provider);

=head1 NAME

Koha::Auth::Identity::Provider::SAML2 - SAML2/Shibboleth identity provider class

=head1 API

=head2 Class methods

=head3 new

    my $saml2 = Koha::Auth::Identity::Provider::SAML2->new( \%{params} );

Overloaded constructor that sets protocol to 'SAML2'.

=cut

sub new {
    my ( $class, $params ) = @_;

    $params->{protocol} = 'SAML2';

    return $class->SUPER::new($params);
}

=head2 Internal methods

=head3 mandatory_config_attributes

SAML2 providers are configured at the web-server level (e.g. mod_shib).
Koha stores optional protocol-specific settings in C<config>, but
behavioural settings like C<auto_register_opac>, C<update_on_auth>
and C<send_welcome_email> are configured at the domain level.
None are mandatory.

=cut

sub mandatory_config_attributes {
    return ();
}

1;
