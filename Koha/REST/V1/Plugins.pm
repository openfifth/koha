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

use File::Fetch;
use Koha::Plugins::Install;
use Koha::Plugins::Store;
use Mojo::JSON qw( true false );

use Koha::Plugins;
use Koha::Plugins::Handler;
use C4::Context;
use C4::Auth;
use Koha::Auth::Permissions;

=head1 NAME

Koha::REST::V1::Plugins

=head1 API

=head2 Class methods

=head3 add

Installs the uploaded plugin

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body    = $c->req->json // {};
    my $kpz_url = $body->{kpz_url};

    return $c->render( status => 400, openapi => { error => 'Missing kpz_url' } )
        unless $kpz_url;

    my $lookup = Koha::Plugins::Store->lookup_by_kpz_url($kpz_url);

    my $ff   = File::Fetch->new( uri => $kpz_url );
    my $file = eval { $ff->fetch };
    return $c->render( status => 500, openapi => { error => 'Could not download kpz_url' } )
        unless $file;

    my ($filename) = $kpz_url =~ m{([^/]+)$};

    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path           => $file,
            filename           => $filename,
            repo_url           => $lookup ? $lookup->{repo_url}           : undef,
            certification_tier => $lookup ? $lookup->{certification_tier} : undef,
        }
    );

    return $c->render( status => 403, openapi => { error => 'Install rejected', details => $result } )
        unless $ok;

    return try {
        return $c->render(
            status  => 201,
            openapi => { success => 'Plugin installed' }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 list

List installed plugins

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my $capability = $c->param('capability');

    my ( $plugins, $failures ) = Koha::Plugins->new()->GetPlugins(
        {
            all    => 1,
            errors => 1,
        }
    );

    my @result = map {
        my $plugin   = $_;
        my $metadata = $plugin->get_metadata // {};
        {
            class           => $plugin->{class},
            name            => $metadata->{name},
            description     => $metadata->{description},
            author          => $metadata->{author},
            version         => $metadata->{version},
            minimum_version => $metadata->{minimum_version},
            maximum_version => $metadata->{maximum_version},
            date_updated    => $metadata->{date_updated},
            is_enabled      => $plugin->is_enabled       ? true : false,
            can_configure   => $plugin->can('configure') ? true : false,
            can_tool        => $plugin->can('tool')      ? true : false,
            can_report      => $plugin->can('report')    ? true : false,
            can_admin       => $plugin->can('admin')     ? true : false,
        };
    } @$plugins;

    @result = grep { $_->{ 'can_' . $capability } } @result
        if $capability;

    return $c->render( status => 200, openapi => \@result );
}

=head3 config

Return the current user's plugin-related permissions

=cut

sub config {
    my $c = shift->openapi->valid_input or return;

    my $patron      = $c->stash('koha.user');
    my $userflags   = C4::Auth::haspermission( $patron->userid );
    my $permissions = Koha::Auth::Permissions->get_authz_from_flags( { flags => $userflags } );

    return $c->render(
        status  => 200,
        openapi => { permissions => $permissions },
    );
}

=head3 update

Enable or disable an installed plugin

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $plugin_class = $c->param('plugin_class');
    my $body         = $c->req->json // {};

    return $c->render( status => 400, openapi => { error => 'Missing is_enabled' } )
        unless exists $body->{is_enabled};

    my $method = $body->{is_enabled} ? 'enable' : 'disable';

    Koha::Plugins::Handler->run( { class => $plugin_class, method => $method } );

    return $c->render( status => 200, openapi => { success => 'Plugin updated' } );
}

=head3 delete

Uninstall a plugin

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $plugin_class = $c->param('plugin_class');

    Koha::Plugins::Handler->delete( { class => $plugin_class } );

    return $c->render_resource_deleted;
}

1;
