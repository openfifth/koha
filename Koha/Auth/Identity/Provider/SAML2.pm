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

=encoding utf8

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

SAML2 providers support two modes:

=over 4

=item C<ipc> mode

Authentication is handled at the web-server level (e.g. mod_shib / libshibsp).
No Koha-side SP crypto config is required; Koha stores only optional behavioural
settings (autocreate, sync, welcome) plus the C<mode> field.

=item C<native> mode

Koha acts as a native SAML2 Service Provider using L<Koha::Auth::SAML2>.
SP cert/key and IdP metadata are stored in the identity provider config JSON.
Required native-mode fields (C<sp_cert>, C<sp_key>, C<idp_metadata>) are
validated at the middleware level when the SP is initialised, not here.
The C<sp_entity_id> field is optional — when absent the entity ID is derived
from the request hostname passed to C<build_sp>.

=back

Returns an empty list because no config fields are universally mandatory
across both modes.

=cut

sub mandatory_config_attributes {
    return ();
}

=head3 is_native

    my $native = $provider->is_native();

Returns true (1) if this provider is configured in native mode
(C<< get_config()->{mode} eq 'native' >>), false otherwise.

=cut

sub is_native {
    my ($self) = @_;
    my $config = $self->get_config // {};
    return ( ( $config->{mode} // '' ) eq 'native' ) ? 1 : 0;
}

=head3 build_sp

    my $sp = $provider->build_sp($hostname);

Creates and returns a L<Koha::Auth::SAML2> SP object configured from this
provider's config JSON. Only valid when C<is_native()> returns true.

The optional C<$hostname> argument (the request hostname without port) is used
to derive the SP entity ID and to construct the correct ACS/SLS endpoint URLs
(C<https://{hostname}/cgi-bin/koha/saml2/acs> etc.) when C<sp_entity_id>
is not explicitly stored in the provider config.

=cut

sub build_sp {
    my ( $self, $hostname ) = @_;

    require Koha::Auth::SAML2;
    return Koha::Auth::SAML2->new( { provider => $self, hostname => $hostname } );
}

1;
