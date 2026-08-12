package Koha::REST::V1::Plugins;

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

use Archive::Extract;

use Koha::Plugins;
use C4::Context;

=head1 NAME

Koha::REST::V1::Plugins

=head1 API

=head2 Class methods

=head3 add

Installs the uploaded plugin

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body    = $c->req->json;
    my $kpz_url = $body->{kpz_url};

    return $c->render( status => 400, openapi => { error => 'Missing kpz_url' } )
        unless $kpz_url;

    my ($uploadfilename) = $kpz_url =~ m{([^/]+)$};

    my $plugins_restricted = C4::Context->config("plugins_restricted");
    my $plugins_dir        = C4::Context->config("pluginsdir");
    $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;

    my %errors;
    $errors{'NOTKPZ'}         = 1 if ( $uploadfilename !~ /\.kpz$/i );
    $errors{'NOWRITEPLUGINS'} = 1 unless ( -w $plugins_dir );

    # Stopgap only: rejects every install while plugins_restricted is on --
    # there's no allowlist check against anything yet, only the ability to
    # reject, which is the correct fail-closed tradeoff for closing an
    # active security gap quickly. Task 4 replaces this whole block with
    # Koha::Plugins::Install, checked against the plugin's actual origin
    # repo, which can actually pass.
    $errors{'RESTRICTED'} = 1 if $plugins_restricted;

    # Checked before downloading anything, deliberately -- no point fetching
    # a URL we're going to reject regardless of its contents.
    return $c->render( status => 403, openapi => { error => 'Install rejected', details => \%errors } )
        if %errors;

    use File::Fetch;
    my $ff   = File::Fetch->new( uri => $kpz_url );
    my $file = eval { $ff->fetch };
    return $c->render( status => 500, openapi => { error => 'Could not download kpz_url' } )
        unless $file;

    my $ae = Archive::Extract->new( archive => $file, type => 'zip' );
    unless ( $ae->extract( to => $plugins_dir ) ) {
        return $c->render( status => 500, openapi => { error => 'Could not unzip kpz_url' } );
    }

    Koha::Plugins->new->InstallPlugins( { verbose => 0 } );

    return try {
        return $c->render(
            status  => 201,
            openapi => { success => 'Plugin installed' }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
