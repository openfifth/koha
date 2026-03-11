use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
use JSON;

return {
    bug_number  => "40596",
    description => "Migrate CAS authentication to identity providers",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # ── 1. Add CAS to identity_providers.protocol enum ─────────────────────

        if ( column_exists( 'identity_providers', 'protocol' ) ) {
            my ($current_type) = $dbh->selectrow_array(
                "SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'identity_providers'
                 AND COLUMN_NAME = 'protocol'"
            );

            unless ( $current_type && $current_type eq "enum('CAS','OAuth','OIDC','SAML2')" ) {
                $dbh->do(
                    q{
                    ALTER TABLE identity_providers
                        MODIFY COLUMN `protocol`
                        enum('CAS','OAuth','OIDC','SAML2')
                        COLLATE utf8mb4_unicode_ci NOT NULL
                        COMMENT 'Protocol provider speaks'
                }
                );
                say_success( $out, "Added CAS to identity_providers.protocol enum" );
            }
        }

        # ── 2. Migrate existing CAS configuration to identity providers ────────

        my $version = C4::Context->preference('casServerVersion') || '2';

        # Check for a multi-server YAML config file first
        my $yamlauthfile = C4::Context->config('intranetdir') . "/C4/Auth_cas_servers.yaml";

        if ( -e $yamlauthfile ) {
            require YAML::XS;
            my ( $default_hash, $servers ) = YAML::XS::LoadFile($yamlauthfile);

            for my $code ( sort keys %$servers ) {
                my $server_url = $servers->{$code};
                next unless $server_url;

                my ($exists) = $dbh->selectrow_array(
                    "SELECT COUNT(*) FROM identity_providers WHERE code = ? AND protocol = 'CAS'",
                    undef, $code
                );
                if ($exists) {
                    say_info( $out, "CAS provider '$code' already exists - skipping" );
                    next;
                }

                $dbh->do(
                    "INSERT INTO identity_providers (code, description, protocol, config, enabled)
                     VALUES (?, ?, 'CAS', ?, 1)",
                    undef,
                    $code,
                    $code,
                    encode_json( { server_url => $server_url, version => $version } )
                );
                say_success( $out, "Migrated CAS server '$code' ($server_url) to identity providers" );
            }

            say_info(
                $out,
                "CAS servers migrated from $yamlauthfile - "
                    . "the file can be removed once you have verified the configuration"
            );

        } elsif ( C4::Context->preference('casAuthentication') && C4::Context->preference('casServerUrl') ) {

            # Single CAS server from system preferences
            my $server_url = C4::Context->preference('casServerUrl');

            my ($exists) = $dbh->selectrow_array("SELECT COUNT(*) FROM identity_providers WHERE protocol = 'CAS'");

            if ($exists) {
                say_info( $out, "CAS identity provider already exists - skipping syspref migration" );
            } else {
                $dbh->do(
                    "INSERT INTO identity_providers (code, description, protocol, config, enabled)
                     VALUES ('cas', 'CAS', 'CAS', ?, 1)",
                    undef,
                    encode_json( { server_url => $server_url, version => $version } )
                );
                say_success( $out, "Migrated CAS server ($server_url) to identity providers (code: 'cas')" );
                say_info(
                    $out,
                    "The casServerUrl and casServerVersion system preferences are now superseded "
                        . "by the Identity Providers configuration (Admin > Identity providers)"
                );
            }
        }
    },
};
