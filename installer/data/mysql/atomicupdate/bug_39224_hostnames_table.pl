use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "39224",
    description => "Introduce hostnames table and refactor identity_provider_hostnames to use hostname_id FK",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Step 1: Create canonical hostnames table
        unless ( TableExists('hostnames') ) {
            $dbh->do(
                q{
                CREATE TABLE `hostnames` (
                    `hostname_id` int(11) NOT NULL AUTO_INCREMENT
                        COMMENT 'Unique identifier for this hostname',
                    `hostname` varchar(255) NOT NULL
                        COMMENT 'Server hostname string',
                    PRIMARY KEY (`hostname_id`),
                    UNIQUE KEY `hostname` (`hostname`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                COMMENT='Canonical hostname registry for identity provider selection'
            }
            );
            say_success( $out, "Added new table 'hostnames'" );
        }

        # Step 2: Populate hostnames from existing bridge table data
        if (   TableExists('identity_provider_hostnames')
            && column_exists( 'identity_provider_hostnames', 'hostname' ) )
        {
            $dbh->do(
                q{
                INSERT IGNORE INTO hostnames (hostname)
                SELECT DISTINCT hostname FROM identity_provider_hostnames
            }
            );
            say_success( $out, "Populated 'hostnames' from existing identity_provider_hostnames data" );
        }

        # Step 3: Add hostname_id FK column to bridge table
        unless ( column_exists( 'identity_provider_hostnames', 'hostname_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_hostnames
                    ADD COLUMN `hostname_id` int(11) NOT NULL DEFAULT 0
                        COMMENT 'FK to hostnames table'
                        AFTER `identity_provider_hostname_id`
            }
            );
            say_success( $out, "Added column 'identity_provider_hostnames.hostname_id'" );
        }

        # Step 4: Back-fill hostname_id from the hostname string
        if ( column_exists( 'identity_provider_hostnames', 'hostname' ) ) {
            $dbh->do(
                q{
                UPDATE identity_provider_hostnames iph
                JOIN hostnames h ON h.hostname = iph.hostname
                SET iph.hostname_id = h.hostname_id
            }
            );
            say_success( $out, "Back-filled identity_provider_hostnames.hostname_id values" );
        }

        # Step 5: Add FK constraint for hostname_id
        unless ( foreign_key_exists( 'identity_provider_hostnames', 'fk_iph_hostname' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_hostnames
                    ADD CONSTRAINT `fk_iph_hostname` FOREIGN KEY (`hostname_id`)
                        REFERENCES `hostnames` (`hostname_id`)
                        ON DELETE CASCADE ON UPDATE RESTRICT
            }
            );
            say_success( $out, "Added FK constraint 'fk_iph_hostname'" );
        }

        # Replace unique key: (hostname string, provider) → (hostname_id, provider)
        if ( index_exists( 'identity_provider_hostnames', 'hostname_provider' ) ) {
            $dbh->do(q{ ALTER TABLE identity_provider_hostnames DROP KEY `hostname_provider` });
        }
        unless ( index_exists( 'identity_provider_hostnames', 'hostname_id_provider' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_hostnames
                    ADD UNIQUE KEY `hostname_id_provider` (`hostname_id`, `identity_provider_id`)
            }
            );
            say_success( $out, "Added unique key 'hostname_id_provider' on (hostname_id, identity_provider_id)" );
        }

        # Step 6: Drop old hostname varchar column from bridge table
        if ( column_exists( 'identity_provider_hostnames', 'hostname' ) ) {
            $dbh->do(q{ ALTER TABLE identity_provider_hostnames DROP COLUMN `hostname` });
            say_success( $out, "Dropped column 'identity_provider_hostnames.hostname'" );
        }

        return 1;
    },
};
