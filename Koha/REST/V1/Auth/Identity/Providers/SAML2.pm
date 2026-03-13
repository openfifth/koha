package Koha::REST::V1::Auth::Identity::Providers::SAML2;

# Copyright 2025 Koha Development Team
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

use Mojo::Base 'Mojolicious::Controller';

use File::Temp qw( tempdir );
use IPC::Cmd   qw( run );
use Try::Tiny;

use Koha::Logger;

=head1 NAME

Koha::REST::V1::Auth::Identity::Providers::SAML2 - Controller for SAML2-specific
identity provider operations.

=head2 Operations

=head3 generate_certificate

Generate a self-signed X.509 certificate and RSA private key for use as a
SAML2 Service Provider credential.

=cut

sub generate_certificate {
    my $c = shift->openapi->valid_input or return;

    my $body     = $c->req->json;
    my $cn       = $body->{common_name}   // '';
    my $key_size = $body->{key_size}      // 2048;
    my $days     = $body->{validity_days} // 365;

    # Validate common_name
    unless ( $cn =~ /\S/ ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => 'common_name is required',
                error_code => 'missing_parameter',
            }
        );
    }

    # Sanitise: allow only characters valid in a CN / Subject (letters, digits,
    # dots, hyphens, colons, slashes, at-signs, spaces — enough for URLs and hostnames).
    unless ( $cn =~ m{^[\w\.\-\:/\@ ]+$} ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => 'common_name contains invalid characters',
                error_code => 'invalid_parameter_value',
            }
        );
    }

    unless ( grep { $_ == $key_size } ( 2048, 4096 ) ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => 'key_size must be 2048 or 4096',
                error_code => 'invalid_parameter_value',
            }
        );
    }

    unless ( $days >= 1 && $days <= 3650 ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => 'validity_days must be between 1 and 3650',
                error_code => 'invalid_parameter_value',
            }
        );
    }

    return try {
        my $tmpdir      = tempdir( CLEANUP => 1 );
        my $cert_file   = "$tmpdir/sp.crt";
        my $key_file    = "$tmpdir/sp.key";
        my $pkcs1_file  = "$tmpdir/sp_pkcs1.key";
        my $config_file = "$tmpdir/openssl.cnf";

        # Write CN to a config file to avoid OpenSSL's -subj parsing problems
        # when the CN contains '/' characters (e.g. entity IDs like https://...).
        open my $cfg_fh, '>', $config_file or die "Cannot write openssl config: $!";
        print $cfg_fh "[req]\ndistinguished_name = req_dn\nprompt = no\n[req_dn]\nCN = $cn\n";
        close $cfg_fh;

        # Generate self-signed cert with private key (OpenSSL 3 produces PKCS#8)
        my ( $ok, $err ) = run(
            command => [
                'openssl', 'req',
                '-x509',
                '-newkey', "rsa:$key_size",
                '-nodes',
                '-days',   $days,
                '-config', $config_file,
                '-keyout', $key_file,
                '-out',    $cert_file,
            ]
        );

        unless ($ok) {
            Koha::Logger->get->error("SAML2 cert generation (step 1) failed: $err");
            return $c->render(
                status  => 500,
                openapi => {
                    error      => 'Certificate generation failed',
                    error_code => 'internal_server_error',
                }
            );
        }

        # Convert to traditional PKCS#1 RSA key (BEGIN RSA PRIVATE KEY) so
        # that Net::SAML2 can load it regardless of OpenSSL version.
        my ($ok2) = run(
            command => [
                'openssl', 'rsa',
                '-in',     $key_file,
                '-traditional',
                '-out', $pkcs1_file,
            ]
        );

        my $final_key_file = $ok2 ? $pkcs1_file : $key_file;

        open my $cfh, '<', $cert_file or die "Cannot read certificate: $!";
        my $cert = do { local $/; <$cfh> };
        close $cfh;

        open my $kfh, '<', $final_key_file or die "Cannot read private key: $!";
        my $key = do { local $/; <$kfh> };
        close $kfh;

        return $c->render(
            status  => 201,
            openapi => {
                certificate => $cert,
                private_key => $key,
            }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
