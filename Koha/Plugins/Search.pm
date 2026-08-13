package Koha::Plugins::Search;

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
use Mojo::URL;

use C4::Context;

=head1 NAME

Koha::Plugins::Search

=head1 API

=head2 Class methods

=head3 search

    my ( $results, $errors ) = Koha::Plugins::Search->search($term);

Searches the configured plugin-store for plugins compatible with this Koha's own version, whose
name or description contains C<$term> (case-insensitive). Returns C<( \@results, \@errors )> as
a list of C<{ repo => {...}, result => {...} }> hashes.

=cut

sub search {
    my ( $class, $term ) = @_;

    my ( @results, @errors );

    my $store_url = C4::Context->config('plugin_store_url');
    unless ($store_url) {
        push @errors, { repo => { name => 'plugin store' }, error => 'No plugin store configured' };
        return ( \@results, \@errors );
    }

    my $koha_version = C4::Context->preference('Version');
    my $ua           = Mojo::UserAgent->new;
    my $tx           = $ua->get("$store_url/api/plugins?koha_version_release=$koha_version");

    unless ( $tx->res->code && $tx->res->code == 200 ) {
        push @errors, { repo => { name => 'plugin store' }, error => 'Could not reach the plugin store' };
        return ( \@results, \@errors );
    }

    my $plugins = eval { $tx->res->json } // [];
    for my $plugin (@$plugins) {
        next
            unless lc( $plugin->{name} // '' ) =~ /\Q$term\E/i
            or lc( $plugin->{description} // '' ) =~ /\Q$term\E/i;

        for my $release ( @{ $plugin->{releases} // [] } ) {
            my ($install_name) = ( $release->{kpz_url} // '' ) =~ m{([^/]+)$};

            # Extract owner/org from repo_url (e.g. https://github.com/openfifth/koha-plugin-coverflow -> openfifth)
            my $repo_owner = $plugin->{repo_url} // '';
            if ($repo_owner) {
                my $url      = Mojo::URL->new($repo_owner);
                my @segments = grep { length } @{ $url->path->parts };
                $repo_owner = $segments[0] // $repo_owner;
            }

            push @results,
                {
                repo   => { name => $repo_owner },
                result => {
                    name         => $plugin->{name},
                    description  => $plugin->{description},
                    html_url     => $plugin->{repo_url},
                    tag_name     => $release->{tag_name} // $release->{version},
                    install_name => $install_name        // '',
                    install_url  => $release->{kpz_url},
                },
                };
        }
    }

    return ( \@results, \@errors );
}

1;

=head1 AUTHOR

Koha Development Team

=cut
