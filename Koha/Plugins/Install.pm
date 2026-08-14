package Koha::Plugins::Install;

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

use List::Util  qw(any);
use Digest::SHA qw(sha256_hex);
use Mojo::URL;
use Archive::Extract;
use Crypt::PK::Ed25519;
use MIME::Base64 qw(decode_base64);
use Mojo::JSON   qw(decode_json);

use C4::Context;
use Koha::Plugins;

=head1 NAME

Koha::Plugins::Install

=head1 API

=head2 Class methods

=head3 install

    my ( $ok, $result ) = Koha::Plugins::Install->install({
        kpz_path            => $local_path_to_kpz,
        filename            => $original_filename,     # used for the .kpz extension check
        repo_url            => $repo_url,               # optional; the plugin's origin repo, if known
        certification_tier  => $tier,                   # optional; the plugin-store's tier for this version, if known
        signed_manifest     => $signed_manifest_json,   # optional; the plugin-store's signed manifest for this version, if known
        signature           => $signature_b64,          # optional; the plugin-store's signature over signed_manifest, if known
        confirm_unsigned    => $bool,                    # optional; bypasses UNSIGNEDCONFIRMREQUIRED once the caller has confirmed
    });

Validates, then extracts and installs, a plugin already downloaded to a local path. On success
returns C<(1, { digest => $sha256_hex })>. On failure returns C<(0, \%errors)> where C<%errors>
keys are any of C<NOTKPZ>, C<NOWRITEPLUGINS>, C<RESTRICTED>, C<SIGNATUREMISMATCH>, C<UNSIGNED>,
C<UNSIGNEDCONFIRMREQUIRED>, C<BELOWMINIMUMLEVEL>, C<UNZIPFAIL> -- never installs anything if any
check fails.

This is called by the plugin management REST API endpoint (C<Koha::REST::V1::Plugins::add()>)
to ensure consistent security checks.

=cut

# The real community plugin-store's Ed25519 public key. Deployments (or dev/testing
# environments pointed at a different store, e.g. a self-hosted mirror) can override
# via koha-conf.xml's plugin_store_public_key -- see _store_public_key below.
use constant DEFAULT_STORE_PUBLIC_KEY => <<'PEM';
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA7RcwcVqFedy1ILYWF7C74l1osE4+2fH/WcVIhydbfu4=
-----END PUBLIC KEY-----
PEM

sub install {
    my ( $class, $params ) = @_;

    my $kpz_path         = $params->{kpz_path};
    my $filename         = $params->{filename} // '';
    my $repo_url         = $params->{repo_url};
    my $tier             = $params->{certification_tier};
    my $signed_manifest  = $params->{signed_manifest};
    my $signature        = $params->{signature};
    my $confirm_unsigned = $params->{confirm_unsigned};

    my %errors;
    $errors{NOTKPZ} = 1 if $filename !~ /\.kpz$/i;

    my $plugins_dir = C4::Context->config('pluginsdir');
    $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;
    $errors{NOWRITEPLUGINS} = 1 unless -w $plugins_dir;

    $errors{RESTRICTED} = 1 unless $class->_repo_allowed($repo_url);

    # Computed here (rather than after the early-return below, as before) because the
    # signature check needs it -- the manifest's own digest must match this exact file,
    # not merely verify against something the store once signed.
    my $digest = $class->_digest($kpz_path);

    if ( $signed_manifest && $signature ) {
        $errors{SIGNATUREMISMATCH} = 1
            unless $class->_verify_signature( $signed_manifest, $signature, $digest );
    } else {
        my $allow_unsigned = C4::Context->config('plugins_allow_unsigned') // 1;
        if ( !$allow_unsigned ) {
            $errors{UNSIGNED} = 1;
        } elsif ( !$confirm_unsigned ) {
            $errors{UNSIGNEDCONFIRMREQUIRED} = 1;
        }
    }

    $errors{BELOWMINIMUMLEVEL} = 1 unless $class->_meets_minimum_level($tier);

    return ( 0, \%errors ) if %errors;

    my $ae = Archive::Extract->new( archive => $kpz_path, type => 'zip' );
    unless ( $ae->extract( to => $plugins_dir ) ) {
        return ( 0, { UNZIPFAIL => $ae->error } );
    }

    Koha::Plugins->new->InstallPlugins( { verbose => 0 } );

    return ( 1, { digest => $digest } );
}

sub _digest {
    my ( $class, $kpz_path ) = @_;

    open my $fh, '<:raw', $kpz_path or die "Could not open $kpz_path: $!";
    local $/;
    return sha256_hex(<$fh>);
}

sub _store_public_key {
    my ($class) = @_;
    return C4::Context->config('plugin_store_public_key') // DEFAULT_STORE_PUBLIC_KEY;
}

sub _verify_signature {
    my ( $class, $signed_manifest_json, $signature_b64, $digest ) = @_;

    my $manifest = eval { decode_json($signed_manifest_json) };
    return 0 unless $manifest;
    return 0 unless ( $manifest->{digest} // '' ) eq ( $digest // '' );

    my $public_key_pem = $class->_store_public_key;
    my $pk             = eval { Crypt::PK::Ed25519->new( \$public_key_pem ) };
    return 0 unless $pk;

    my $signature = eval { decode_base64($signature_b64) };
    return 0 unless $signature;

    return eval { $pk->verify_message( $signature, $signed_manifest_json ) } ? 1 : 0;
}

my %EXPECTED_HOST = ( github => 'github.com', gitlab => 'gitlab.com' );

sub _repo_allowed {
    my ( $class, $repo_url ) = @_;

    return 1 unless C4::Context->config('plugins_restricted');
    return 0 unless $repo_url;

    my $repos = C4::Context->config('plugin_repos') or return 0;
    $repos = { repo => [ $repos->{repo} ] } if ref( $repos->{repo} ) eq 'HASH';

    my $url      = Mojo::URL->new($repo_url);
    my $host     = lc( $url->host // '' );
    my @segments = grep { length } @{ $url->path->parts };
    my $owner    = lc( $segments[0] // '' );

    return any {
        my $expected_host = $EXPECTED_HOST{ $_->{service} } // '';
        lc( $_->{org_name} ) eq $owner && $host eq $expected_host;
    } @{ $repos->{repo} };
}

sub _meets_minimum_level {
    my ( $class, $tier ) = @_;

    my $minimum = C4::Context->preference('PluginStoreMinimumLevel');
    return 1 unless $minimum;    # syspref off -- no gate
    return 1 unless $tier;       # no known plugin-store provenance -- gated by _repo_allowed instead, not this check

    my %rank = ( INCOMPLETE => 0, STRUCTURAL => 1, CERTIFIED => 2 );
    return ( $rank{$tier} // -1 ) >= ( $rank{$minimum} // 0 );
}

1;

=head1 AUTHOR

Koha Development Team

=cut
