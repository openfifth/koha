package Koha::Plugins::Store;

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

use Mojo::UserAgent;

use C4::Context;

=head1 NAME

Koha::Plugins::Store

=head1 API

=head2 Class methods

=head3 lookup_by_kpz_url

    my $info = Koha::Plugins::Store->lookup_by_kpz_url($kpz_url);
    # { repo_url => '...', certification_tier => '...' } or undef

Queries the configured plugin-store's public discovery API
(C<GET /api/plugins?koha_version_release=...>) for the plugin version whose C<kpz_url> exactly
matches the one given, returning its origin C<repo_url> and C<certification_tier> if found.
Returns C<undef> if C<plugin_store_url> isn't configured, the store isn't reachable, or no
release matches.

=cut

sub lookup_by_kpz_url {
    my ( $class, $kpz_url ) = @_;

    my $store_url = C4::Context->config('plugin_store_url');
    return unless $store_url;

    my $koha_version = C4::Context->preference('Version');
    my $ua           = Mojo::UserAgent->new;
    my $tx           = $ua->get("$store_url/api/plugins?koha_version_release=$koha_version");

    return unless $tx->res->code && $tx->res->code == 200;

    my $plugins = eval { $tx->res->json } // [];
    for my $plugin (@$plugins) {
        for my $release ( @{ $plugin->{releases} // [] } ) {
            next unless ( $release->{kpz_url} // '' ) eq $kpz_url;
            return {
                repo_url           => $plugin->{repo_url},
                certification_tier => $release->{certification_tier},
                signed_manifest    => $release->{signed_manifest},
                signature          => $release->{signature},
            };
        }
    }

    return;
}

=head3 lookup_by_digest

    my $info = Koha::Plugins::Store->lookup_by_digest($digest);
    # { signed_manifest => '...', signature => '...', certification_tier => '...' } or undef

Queries the configured plugin-store's digest-lookup endpoint
(C<GET /api/plugins/verify?digest=...>) for a published version matching the given SHA-256
digest -- used for manually-uploaded files, which have no C<kpz_url> to match against the
discovery listing C<lookup_by_kpz_url> consults. Returns C<undef> if C<plugin_store_url>
isn't configured, the store isn't reachable, or no published version has that digest.

=cut

sub lookup_by_digest {
    my ( $class, $digest ) = @_;

    my $store_url = C4::Context->config('plugin_store_url');
    return unless $store_url;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->get("$store_url/api/plugins/verify?digest=$digest");

    return unless $tx->res->code && $tx->res->code == 200;

    my $result = eval { $tx->res->json };
    return unless $result;

    return {
        signed_manifest    => $result->{signed_manifest},
        signature          => $result->{signature},
        certification_tier => $result->{certification_tier},
    };
}

1;

=head1 AUTHOR

Koha Development Team

=cut
