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
            };
        }
    }

    return;
}

1;

=head1 AUTHOR

Koha Development Team

=cut
