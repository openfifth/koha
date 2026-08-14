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
use File::Temp;
use Koha::Plugins::Install;
use Koha::Plugins::Store;
use Mojo::JSON qw( true false decode_json );

use Koha::Plugins;
use Koha::Plugins::Handler;
use C4::Context;
use C4::Auth;
use Koha::Auth::Permissions;

=head2 Internal methods

=head3 _search_terms

Recursively collects every string value out of a decoded C<q> query-filter
structure, to use as free-text search terms. C<q> is built by
_dt_default_ajax to express DBIC-style filters; the plugin list isn't backed
by a DBIC resultset, so rather than interpreting the full filter language we
treat every string literal found in it as a term to substring-match against
the searchable columns -- adequate for the small, non-paginated dataset a
list of installed plugins actually is.

=cut

sub _search_terms {
    my ($value) = @_;

    return ()       unless defined $value;
    return ($value) unless ref $value;
    return map { _search_terms($_) } @$value        if ref $value eq 'ARRAY';
    return map { _search_terms($_) } values %$value if ref $value eq 'HASH';
    return ();
}

=head1 NAME

Koha::REST::V1::Plugins

=head1 API

=head2 Class methods

=head3 add

Installs the uploaded plugin

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body             = $c->req->json // {};
    my $kpz_url          = $body->{kpz_url};
    my $confirm_unsigned = $body->{confirm_unsigned};

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
            signed_manifest    => $lookup ? $lookup->{signed_manifest}    : undef,
            signature          => $lookup ? $lookup->{signature}          : undef,
            confirm_unsigned   => $confirm_unsigned,
        }
    );

    return $c->render( status => 403, openapi => { error => _priority_error($result) } )
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

    # KohaTable always drives this endpoint through DataTables' serverSide
    # mode, so it always sends _page/_per_page, and sends _order_by/q
    # whenever the table is sorted or searched. The list isn't backed by a
    # DBIC resultset, so pagination/sorting/searching are applied here by
    # hand instead of via the generic $c->objects->search helper.
    my @search_terms =
        map { _search_terms($_) } grep { defined } map {
        eval { decode_json($_) }
        } @{ $c->every_param('q') };
    if (@search_terms) {
        @result = grep {
            my $row = $_;
            my $matched;
            for my $term (@search_terms) {
                $matched = 1
                    if grep { defined $row->{$_} && lc( $row->{$_} ) =~ /\Q\L$term\E/ } qw(name description author);
            }
            $matched;
        } @result;
    }

    if ( my ($order_by) = @{ $c->every_param('_order_by') } ) {
        my ( $dir, $column ) = $order_by =~ /^([+-]?)(?:me\.)?(\w+)$/;
        if ($column) {
            @result = sort {
                my ( $x, $y ) = ( $a->{$column} // '', $b->{$column} // '' );
                ( $dir eq '-' ) ? ( $y cmp $x ) : ( $x cmp $y );
            } @result;
        }
    }

    my $total    = scalar @result;
    my $page     = $c->param('_page') || 1;
    my $per_page = $c->param('_per_page') // C4::Context->preference('RESTdefaultPageSize') // 20;

    if ( $per_page != -1 ) {
        my $offset = ( $page - 1 ) * $per_page;
        @result = splice( @result, $offset, $per_page ) if $offset < @result;
        @result = ()                                    if $offset >= $total;
    }

    $c->add_pagination_headers( { total => $total, page => $page, per_page => $per_page } );

    if ( my $request_id = $c->req->headers->header('x-koha-request-id') ) {
        $c->res->headers->add( 'x-koha-request-id' => $request_id );
    }

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

=head3 upload

Upload and install a plugin from a local .kpz file

=cut

sub upload {
    my $c = shift->openapi->valid_input or return;

    return $c->render( status => 403, openapi => { error => 'RESTRICTED' } )
        if C4::Context->config('plugins_restricted');

    my $upload = $c->req->upload('file');
    return $c->render( status => 400, openapi => { error => 'EMPTYUPLOAD' } )
        unless $upload;

    my $dirname = File::Temp::tempdir( CLEANUP => 1 );
    my ($filesuffix) = $upload->filename =~ m/(\..+)$/i;
    my ( undef, $tempfile ) = File::Temp::tempfile( DIR => $dirname, SUFFIX => $filesuffix // '', UNLINK => 1 );
    $upload->move_to($tempfile);

    my $digest = Koha::Plugins::Install->_digest($tempfile);
    my $lookup = Koha::Plugins::Store->lookup_by_digest($digest);

    my $confirm_unsigned = $c->req->body_params->param('confirm_unsigned');

    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path           => $tempfile,
            filename           => $upload->filename,
            certification_tier => $lookup ? $lookup->{certification_tier} : undef,
            signed_manifest    => $lookup ? $lookup->{signed_manifest}    : undef,
            signature          => $lookup ? $lookup->{signature}          : undef,
            confirm_unsigned   => $confirm_unsigned,
        }
    );

    return $c->render( status => 403, openapi => { error => _priority_error($result) } )
        unless $ok;

    return $c->render(
        status  => 201,
        openapi => { success => 'Plugin installed' }
    );
}

=head3 _priority_error

    my $code = _priority_error($errors_hashref);

Picks a single error code to report from Koha::Plugins::Install::install()'s C<%errors>
hash, in a fixed priority order -- deliberately NOT C<(keys %$errors)[0]>, since Perl hash
key order is randomized per-instance and must never be relied on for anything meaningful.

=cut

sub _priority_error {
    my ($errors) = @_;

    for my $code (
        qw(NOTKPZ NOWRITEPLUGINS RESTRICTED SIGNATUREMISMATCH UNSIGNED UNSIGNEDCONFIRMREQUIRED BELOWMINIMUMLEVEL UNZIPFAIL)
        )
    {
        return $code if $errors->{$code};
    }

    return ( keys %$errors )[0] // 'unknown_error';
}

1;
