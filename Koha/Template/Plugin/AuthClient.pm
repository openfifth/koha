package Koha::Template::Plugin::AuthClient;

# Copyright Theke Solutions 2022
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

use Template::Plugin;
use base      qw( Template::Plugin );
use Try::Tiny qw( catch try );

use Koha::Auth::Identity::Providers;
use Koha::Logger;

=head1 NAME

Koha::Template::Plugin::AuthClient

=head1 DESCRIPTION

This plugin is used to retrieve configured and valid authentication
providers in the caller context.

=head1 API

=head2 Methods

=head3 get_providers

    [% FOREACH provider IN AuthClient.get_providers('staff', shibbolethLoginUrl) %] ...

Accepts an optional C<$shib_url> parameter (the pre-computed Shibboleth login URL from
the C<shibbolethLoginUrl> template variable) used as the href for SAML2 providers.

=cut

sub get_providers {
    my ( $self, $interface, $shib_url ) = @_;

    $interface = 'staff'
        if $interface eq 'intranet';

    my @urls;

    # Handle database upgrade state where schema might be out of sync
    try {
        my $hostname     = $ENV{HTTP_HOST};
        my @h_candidates = Koha::Auth::Identity::Providers->hostname_candidates($hostname);
        my $base_url     = ( $interface eq 'staff' ) ? "/api/v1/oauth/login" : "/api/v1/public/oauth/login";

        # When an exclusive provider is configured for this hostname, return only that
        # provider's button so all other auth methods are suppressed.
        my $exclusive = Koha::Auth::Identity::Providers->find_exclusive_provider($hostname);
        if ($exclusive) {
            push @urls, _provider_entry( $exclusive, $base_url, $interface, $shib_url );
            return \@urls;
        }

        # Return all enabled providers for this hostname (exact, bare, or wildcard '*')
        # or providers with no hostname restriction at all.
        my $providers = Koha::Auth::Identity::Providers->search(
            {
                "domains.allow_$interface" => 1,
                "me.enabled"               => 1,
                -or                        => [
                    {
                        'hostname.hostname'    => \@h_candidates,
                        'hostnames.is_enabled' => 1
                    },
                    { 'hostnames.identity_provider_hostname_id' => undef }
                ]
            },
            {
                join     => [ 'domains', { 'hostnames' => 'hostname' } ],
                distinct => 1
            }
        );

        while ( my $provider = $providers->next ) {
            my $entry = _provider_entry( $provider, $base_url, $interface, $shib_url );
            push @urls, $entry if $entry;
        }
    } catch {

        # If database query fails (e.g., during upgrade), return empty array
        Koha::Logger->get->warn("AuthClient: Unable to load identity providers (database may need upgrade): $_");
        @urls = ();
    };

    return \@urls;
}

=head3 _provider_entry

Build a provider entry hashref for the login page loop.
Returns undef for SAML2 providers when no shib URL is available.

=cut

sub _provider_entry {
    my ( $provider, $base_url, $interface, $shib_url ) = @_;

    my $protocol = $provider->protocol;
    my $code     = $provider->code;

    if ( $protocol eq 'OIDC' || $protocol eq 'OAuth' ) {
        return {
            code        => $code,
            description => $provider->description,
            icon_url    => $provider->icon_url,
            url         => "$base_url/$code/$interface",
            protocol    => $protocol,
        };
    }

    if ( $protocol eq 'SAML2' && $shib_url ) {
        return {
            code        => $code,
            description => $provider->description,
            icon_url    => $provider->icon_url,
            url         => $shib_url,
            protocol    => 'SAML2',
        };
    }

    return;
}

1;
