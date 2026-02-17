use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
use JSON;

return {
    bug_number  => "39224",
    description => "Unify identity providers schema: normalized mappings table, SAML2 support, migrate Shibboleth",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # 1. Add SAML2 to identity_providers protocol enum
        if ( column_exists( 'identity_providers', 'protocol' ) ) {
            my ($current_type) = $dbh->selectrow_array(
                "SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'identity_providers'
                 AND COLUMN_NAME = 'protocol'"
            );

            unless ( $current_type =~ /SAML2/ ) {
                $dbh->do(
                    q{
                    ALTER TABLE identity_providers
                        MODIFY COLUMN `protocol`
                        enum('OAuth','OIDC','LDAP','CAS','SAML2')
                        COLLATE utf8mb4_unicode_ci NOT NULL
                        COMMENT 'Protocol provider speaks'
                }
                );
                say_success( $out, "Added 'SAML2' to identity_providers.protocol enum" );
            }
        }

        # 2. Add force_sso_opac and force_sso_staff to identity_providers
        unless ( column_exists( 'identity_providers', 'force_sso_opac' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_providers
                    ADD COLUMN `force_sso_opac` tinyint(1) NOT NULL DEFAULT 0
                    COMMENT 'Force SSO redirect for OPAC users'
                    AFTER `icon_url`
            }
            );
            say_success( $out, "Added column 'identity_providers.force_sso_opac'" );
        }

        unless ( column_exists( 'identity_providers', 'force_sso_staff' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_providers
                    ADD COLUMN `force_sso_staff` tinyint(1) NOT NULL DEFAULT 0
                    COMMENT 'Force SSO redirect for staff interface users'
                    AFTER `force_sso_opac`
            }
            );
            say_success( $out, "Added column 'identity_providers.force_sso_staff'" );
        }

        unless ( column_exists( 'identity_providers', 'enabled' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_providers
                    ADD COLUMN `enabled` tinyint(1) NOT NULL DEFAULT 1
                    COMMENT 'Whether this provider is active'
                    AFTER `force_sso_staff`
            }
            );
            say_success( $out, "Added column 'identity_providers.enabled'" );
        }

        # 3. Create unified identity_provider_mappings table
        unless ( TableExists('identity_provider_mappings') ) {
            $dbh->do(
                q{
                CREATE TABLE `identity_provider_mappings` (
                    `mapping_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `identity_provider_id` int(11) NOT NULL COMMENT 'Reference to identity provider',
                    `provider_field` varchar(255) DEFAULT NULL COMMENT 'Attribute name from the identity provider',
                    `koha_field` varchar(255) NOT NULL COMMENT 'Corresponding field in Koha borrowers table',
                    `default_content` varchar(255) DEFAULT NULL COMMENT 'Default value if provider does not supply this field',
                    `is_matchpoint` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Use this field to match existing patrons',
                    PRIMARY KEY (`mapping_id`),
                    UNIQUE KEY `provider_koha_field` (`identity_provider_id`, `koha_field`),
                    KEY `provider_field_idx` (`provider_field`),
                    CONSTRAINT `idp_mapping_ibfk_1` FOREIGN KEY (`identity_provider_id`)
                        REFERENCES `identity_providers` (`identity_provider_id`) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );
            say_success( $out, "Added new table 'identity_provider_mappings'" );
        }

        # 4. Migrate existing OAuth/OIDC JSON mappings to normalized rows
        if ( column_exists( 'identity_providers', 'mapping' ) ) {
            my $providers = $dbh->selectall_arrayref(
                "SELECT identity_provider_id, mapping, matchpoint FROM identity_providers
                 WHERE mapping IS NOT NULL AND mapping != '' AND mapping != '{}'",
                { Slice => {} }
            );

            my $migrated = 0;
            for my $provider (@$providers) {
                my $mapping_json = $provider->{mapping};
                my $matchpoint   = $provider->{matchpoint};
                my $provider_id  = $provider->{identity_provider_id};

                my $mapping;
                eval { $mapping = decode_json($mapping_json) };
                next unless $mapping && ref $mapping eq 'HASH';

                for my $koha_field ( keys %$mapping ) {
                    my $provider_field = $mapping->{$koha_field};
                    my $is_matchpoint  = ( defined $matchpoint && $matchpoint eq $koha_field ) ? 1 : 0;

                    $dbh->do(
                        q{
                        INSERT IGNORE INTO identity_provider_mappings
                        (identity_provider_id, provider_field, koha_field, is_matchpoint)
                        VALUES (?, ?, ?, ?)
                    }, undef,
                        $provider_id, $provider_field, $koha_field, $is_matchpoint
                    );
                    $migrated++;
                }
            }

            say_success( $out, "Migrated $migrated OAuth/OIDC field mappings to identity_provider_mappings" );

            # Drop old mapping and matchpoint columns
            $dbh->do("ALTER TABLE identity_providers DROP COLUMN `mapping`");
            say_success( $out, "Dropped column 'identity_providers.mapping'" );

            $dbh->do("ALTER TABLE identity_providers DROP COLUMN `matchpoint`");
            say_success( $out, "Dropped column 'identity_providers.matchpoint'" );
        }

        # 5. Migrate Shibboleth config to a unified identity_providers row
        if ( TableExists('shibboleth_config') ) {
            my $shib_config = $dbh->selectrow_hashref("SELECT * FROM shibboleth_config WHERE shibboleth_config_id = 1");

            if ($shib_config) {

                # Check if a SAML2 provider already exists (idempotent)
                my ($saml2_exists) = $dbh->selectrow_array(
                    "SELECT identity_provider_id FROM identity_providers WHERE protocol = 'SAML2' LIMIT 1");

                unless ($saml2_exists) {
                    my $config = encode_json(
                        {
                            autocreate => $shib_config->{autocreate} ? JSON::true : JSON::false,
                            sync       => $shib_config->{sync}       ? JSON::true : JSON::false,
                            welcome    => $shib_config->{welcome}    ? JSON::true : JSON::false,
                        }
                    );

                    $dbh->do(
                        q{
                        INSERT INTO identity_providers
                        (code, description, protocol, config, force_sso_opac, force_sso_staff, enabled)
                        VALUES (?, ?, 'SAML2', ?, ?, ?, 1)
                    }, undef,
                        'shibboleth',
                        'Shibboleth (migrated)',
                        $config,
                        $shib_config->{force_opac_sso}  || 0,
                        $shib_config->{force_staff_sso} || 0,
                    );

                    $saml2_exists = $dbh->last_insert_id( undef, undef, 'identity_providers', undef );
                    say_success( $out, "Migrated Shibboleth config to identity_providers (id=$saml2_exists)" );

                    # Create default wildcard domain for the Shibboleth provider
                    $dbh->do(
                        q{
                        INSERT IGNORE INTO identity_provider_domains
                        (identity_provider_id, domain, allow_opac, allow_staff, auto_register_opac, auto_register_staff, update_on_auth)
                        VALUES (?, NULL, 1, 1, ?, 0, ?)
                    }, undef,
                        $saml2_exists,
                        $shib_config->{autocreate} || 0,
                        $shib_config->{sync}       || 0,
                    );
                    say_success( $out, "Created default domain entry for migrated Shibboleth provider" );
                }

                # Migrate shibboleth_field_mappings if present
                if ( TableExists('shibboleth_field_mappings') ) {
                    my $mappings = $dbh->selectall_arrayref(
                        "SELECT * FROM shibboleth_field_mappings",
                        { Slice => {} }
                    );

                    for my $m (@$mappings) {
                        $dbh->do(
                            q{
                            INSERT IGNORE INTO identity_provider_mappings
                            (identity_provider_id, provider_field, koha_field, default_content, is_matchpoint)
                            VALUES (?, ?, ?, ?, ?)
                        }, undef,
                            $saml2_exists,
                            $m->{idp_field},
                            $m->{koha_field},
                            $m->{default_content},
                            $m->{is_matchpoint},
                        );
                    }

                    say_success( $out, "Migrated Shibboleth field mappings to identity_provider_mappings" );

                    $dbh->do("DROP TABLE shibboleth_field_mappings");
                    say_success( $out, "Dropped table 'shibboleth_field_mappings'" );
                }
            }

            $dbh->do("DROP TABLE shibboleth_config");
            say_success( $out, "Dropped table 'shibboleth_config'" );
        }

        return 1;
    },
};
