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

        return 1;
    },
};
