use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "39224",
    description => "Add identity_provider_hostnames table for hostname-based provider selection",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('identity_provider_hostnames') ) {
            $dbh->do(
                q{
                CREATE TABLE `identity_provider_hostnames` (
                    `identity_provider_hostname_id` int(11) NOT NULL AUTO_INCREMENT
                        COMMENT 'unique key, used to identify the hostname entry',
                    `hostname` varchar(255) NOT NULL
                        COMMENT 'Server hostname (matches SERVER_NAME) used for automatic provider selection',
                    `identity_provider_id` int(11) NOT NULL
                        COMMENT 'Identity provider associated with this hostname',
                    `is_enabled` tinyint(1) NOT NULL DEFAULT 1
                        COMMENT 'Whether this hostname is active for this provider',
                    `force_sso_opac` tinyint(1) NOT NULL DEFAULT 0
                        COMMENT 'Force SSO redirect for OPAC users on this hostname',
                    `force_sso_staff` tinyint(1) NOT NULL DEFAULT 0
                        COMMENT 'Force SSO redirect for staff interface users on this hostname',
                    PRIMARY KEY (`identity_provider_hostname_id`),
                    UNIQUE KEY `hostname_provider` (`hostname`, `identity_provider_id`),
                    KEY `idp_hostname_provider_idx` (`identity_provider_id`),
                    CONSTRAINT `idp_hostname_ibfk_1` FOREIGN KEY (`identity_provider_id`)
                        REFERENCES `identity_providers` (`identity_provider_id`)
                        ON DELETE CASCADE ON UPDATE RESTRICT
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                COMMENT='Maps server hostnames to identity providers (many-to-many). A hostname may be linked to multiple providers.'
            }
            );
            say_success( $out, "Added new table 'identity_provider_hostnames'" );
        }

        # Add force_sso columns to existing installations that already have the table
        unless ( column_exists( 'identity_provider_hostnames', 'force_sso_opac' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_hostnames
                    ADD COLUMN `force_sso_opac` tinyint(1) NOT NULL DEFAULT 0
                    COMMENT 'Force SSO redirect for OPAC users on this hostname'
                    AFTER `is_enabled`
            }
            );
            say_success( $out, "Added column 'identity_provider_hostnames.force_sso_opac'" );
        }

        unless ( column_exists( 'identity_provider_hostnames', 'force_sso_staff' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_hostnames
                    ADD COLUMN `force_sso_staff` tinyint(1) NOT NULL DEFAULT 0
                    COMMENT 'Force SSO redirect for staff interface users on this hostname'
                    AFTER `force_sso_opac`
            }
            );
            say_success( $out, "Added column 'identity_provider_hostnames.force_sso_staff'" );
        }

        return 1;
    },
};
