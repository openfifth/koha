use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
use JSON;

return {
    bug_number  => "39224",
    description =>
        "Unified identity providers: normalized mappings, hostname-based selection, SAML2/Shibboleth migration",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # ── 1. Update identity_providers.protocol enum ─────────────────────────────
        # Remove CAS and LDAP (unsupported via this interface), add SAML2.

        if ( column_exists( 'identity_providers', 'protocol' ) ) {
            my ($current_type) = $dbh->selectrow_array(
                "SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                 AND TABLE_NAME = 'identity_providers'
                 AND COLUMN_NAME = 'protocol'"
            );

            unless ( $current_type && $current_type eq "enum('OAuth','OIDC','SAML2')" ) {

                # Warn about and remove any providers using protocols no longer in the enum.
                for my $protocol (qw(CAS LDAP)) {
                    my ($count) = $dbh->selectrow_array(
                        "SELECT COUNT(*) FROM identity_providers WHERE protocol = ?",
                        undef, $protocol
                    );
                    if ($count) {
                        say_warning(
                            $out,
                            "Removing $count identity provider(s) with protocol '$protocol'"
                                . " (no longer supported via this interface)"
                        );
                        $dbh->do(
                            "DELETE FROM identity_providers WHERE protocol = ?",
                            undef, $protocol
                        );
                    }
                }

                $dbh->do(
                    q{
                    ALTER TABLE identity_providers
                        MODIFY COLUMN `protocol`
                        enum('OAuth','OIDC','SAML2')
                        COLLATE utf8mb4_unicode_ci NOT NULL
                        COMMENT 'Protocol provider speaks'
                }
                );
                say_success(
                    $out,
                    "Updated identity_providers.protocol enum to ('OAuth','OIDC','SAML2')"
                );
            }
        }

        # ── 2. Add enabled column to identity_providers ────────────────────────────

        unless ( column_exists( 'identity_providers', 'enabled' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_providers
                    ADD COLUMN `enabled` tinyint(1) NOT NULL DEFAULT 1
                    COMMENT 'Whether this provider is active'
                    AFTER `config`
            }
            );
            say_success( $out, "Added column 'identity_providers.enabled'" );
        }

        # ── 3. Drop matchpoint from identity_providers (moved to identity_provider_hostnames) ──

        if ( column_exists( 'identity_providers', 'matchpoint' ) ) {
            $dbh->do("ALTER TABLE identity_providers DROP COLUMN `matchpoint`");
            say_success( $out, "Dropped column 'identity_providers.matchpoint' (moved to hostname level)" );
        }

        # ── 4. Create identity_provider_mappings table ─────────────────────────────

        unless ( TableExists('identity_provider_mappings') ) {
            $dbh->do(
                q{
                CREATE TABLE `identity_provider_mappings` (
                    `mapping_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `identity_provider_id` int(11) NOT NULL COMMENT 'Reference to identity provider',
                    `provider_field` varchar(255) DEFAULT NULL COMMENT 'Attribute name from the identity provider',
                    `koha_field` varchar(255) NOT NULL COMMENT 'Corresponding field in Koha borrowers table',
                    `default_content` varchar(255) DEFAULT NULL COMMENT 'Default value if provider does not supply this field',
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

        # ── 5. Migrate OAuth/OIDC JSON mappings to normalized rows ─────────────────
        # The old identity_providers table stored mappings as a JSON blob and the
        # matchpoint as a simple column value; both are preserved in the new schema.

        if ( column_exists( 'identity_providers', 'mapping' ) ) {
            my $providers = $dbh->selectall_arrayref(
                "SELECT identity_provider_id, mapping FROM identity_providers
                 WHERE mapping IS NOT NULL AND mapping != '' AND mapping != '{}'",
                { Slice => {} }
            );

            my $migrated = 0;
            for my $provider (@$providers) {
                my $mapping_json = $provider->{mapping};
                my $provider_id  = $provider->{identity_provider_id};

                my $mapping;
                eval { $mapping = decode_json($mapping_json) };
                next unless $mapping && ref $mapping eq 'HASH';

                for my $koha_field ( keys %$mapping ) {
                    my $provider_field = $mapping->{$koha_field};

                    $dbh->do(
                        q{
                        INSERT IGNORE INTO identity_provider_mappings
                        (identity_provider_id, provider_field, koha_field)
                        VALUES (?, ?, ?)
                    }, undef,
                        $provider_id, $provider_field, $koha_field
                    );
                    $migrated++;
                }
            }

            say_success(
                $out,
                "Migrated $migrated OAuth/OIDC field mapping(s) to identity_provider_mappings"
            );

            $dbh->do("ALTER TABLE identity_providers DROP COLUMN `mapping`");
            say_success( $out, "Dropped column 'identity_providers.mapping'" );
        }

        # ── 5. Add send_welcome_email to identity_provider_domains ────────────────

        unless ( column_exists( 'identity_provider_domains', 'send_welcome_email' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_domains
                    ADD COLUMN `send_welcome_email` tinyint(1) NOT NULL DEFAULT 0
                    COMMENT 'Send welcome email to patron on first login'
                    AFTER `auto_register_staff`
            }
            );
            say_success( $out, "Added column 'identity_provider_domains.send_welcome_email'" );
        }

        # ── 6. Create canonical hostnames table ────────────────────────────────────

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

            # Seed reserved rows: hostname_id=1 for OPACBaseURL, hostname_id=2 for staffClientBaseURL.
            for my $info ( [ 'OPACBaseURL', 1 ], [ 'staffClientBaseURL', 2 ] ) {
                my ( $pref_name, $id ) = @$info;
                my ($url) = $dbh->selectrow_array(
                    "SELECT value FROM systempreferences WHERE LOWER(variable) = LOWER(?)",
                    undef, $pref_name
                );
                my ($hostname) = ( $url // '' ) =~ m{^https?://([^/:?#]+)} or next;
                $dbh->do(
                    "INSERT IGNORE INTO hostnames (hostname_id, hostname) VALUES (?, ?)",
                    undef, $id, $hostname
                );
                say_success( $out, "Seeded hostname_id=$id from $pref_name ($hostname)" );
            }
        }

        # ── 7. Create/upgrade identity_provider_hostnames bridge table ─────────────

        unless ( TableExists('identity_provider_hostnames') ) {
            $dbh->do(
                q{
                CREATE TABLE `identity_provider_hostnames` (
                    `identity_provider_hostname_id` int(11) NOT NULL AUTO_INCREMENT
                        COMMENT 'unique key, used to identify the hostname entry',
                    `hostname_id` int(11) NOT NULL
                        COMMENT 'FK to hostnames table',
                    `identity_provider_id` int(11) NOT NULL
                        COMMENT 'Identity provider associated with this hostname',
                    `is_enabled` tinyint(1) NOT NULL DEFAULT 1
                        COMMENT 'Whether this hostname is active for this provider',
                    `is_exclusive` tinyint(1) NOT NULL DEFAULT 0
                        COMMENT 'Exclusive provider for this hostname; suppress all other auth methods',
                    `matchpoint` varchar(255) DEFAULT NULL
                        COMMENT 'Koha field used to match incoming users against existing patrons',
                    PRIMARY KEY (`identity_provider_hostname_id`),
                    UNIQUE KEY `hostname_id_provider` (`hostname_id`, `identity_provider_id`),
                    KEY `idp_hostname_provider_idx` (`identity_provider_id`),
                    CONSTRAINT `fk_iph_hostname` FOREIGN KEY (`hostname_id`)
                        REFERENCES `hostnames` (`hostname_id`)
                        ON DELETE CASCADE,
                    CONSTRAINT `idp_hostname_ibfk_1` FOREIGN KEY (`identity_provider_id`)
                        REFERENCES `identity_providers` (`identity_provider_id`)
                        ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                COMMENT='Maps server hostnames to identity providers (many-to-many).'
            }
            );
            say_success( $out, "Added new table 'identity_provider_hostnames'" );
        }

        unless ( column_exists( 'identity_provider_hostnames', 'matchpoint' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_hostnames
                    ADD COLUMN `matchpoint` varchar(255) DEFAULT NULL
                    COMMENT 'Koha field used to match incoming users against existing patrons'
            }
            );
            say_success( $out, "Added column 'identity_provider_hostnames.matchpoint'" );
        }

        # ── 8. Migrate Shibboleth config from koha-conf.xml to identity_providers ─────────────────────
        # Reads useshibboleth from koha-conf.xml and migrates it to a DB syspref.
        # Also migrates the <shibboleth> mapping config to a SAML2 identity provider.

        {
            require C4::Context;
            my $use_shib = C4::Context->config('useshibboleth') // 0;

            if ($use_shib) {
                my $shib_cfg = C4::Context->config('shibboleth');
                unless ($shib_cfg) {
                    say_warning(
                        $out,
                        "ACTION REQUIRED: useshibboleth=1 in koha-conf.xml but no <shibboleth> section was found, "
                            . "so no SAML2 identity provider could be created. Shibboleth logins WILL NOT WORK "
                            . "until you configure a SAML2 identity provider manually under "
                            . "Administration > Identity providers."
                    );
                } else {

                    # Check if a SAML2 provider already exists (idempotent)
                    my ($saml2_id) = $dbh->selectrow_array(
                        "SELECT identity_provider_id FROM identity_providers
                         WHERE protocol = 'SAML2' LIMIT 1"
                    );

                    unless ($saml2_id) {
                        my $config = encode_json(
                            {
                                autocreate => $shib_cfg->{autocreate} ? 1 : 0,
                                sync       => $shib_cfg->{sync}       ? 1 : 0,
                                welcome    => $shib_cfg->{welcome}    ? 1 : 0,
                            }
                        );

                        $dbh->do(
                            q{
                            INSERT INTO identity_providers
                            (code, description, protocol, config, enabled)
                            VALUES ('shibboleth', 'Shibboleth (migrated from koha-conf.xml)', 'SAML2', ?, 1)
                        }, undef, $config
                        );
                        $saml2_id = $dbh->last_insert_id( undef, undef, 'identity_providers', undef );
                        say_success(
                            $out,
                            "Migrated Shibboleth config to identity_providers (id=$saml2_id)"
                        );

                        # Create a default wildcard domain entry for the Shibboleth provider
                        $dbh->do(
                            q{
                            INSERT IGNORE INTO identity_provider_domains
                            (identity_provider_id, domain, allow_opac, allow_staff,
                             auto_register_opac, auto_register_staff, update_on_auth, send_welcome_email)
                            VALUES (?, NULL, 1, 1, ?, 0, ?, ?)
                        }, undef,
                            $saml2_id,
                            $shib_cfg->{autocreate} ? 1 : 0,
                            $shib_cfg->{sync}       ? 1 : 0,
                            $shib_cfg->{welcome}    ? 1 : 0,
                        );
                        say_success(
                            $out,
                            "Created default domain entry for Shibboleth provider"
                        );
                    }

                    # Migrate field mappings from the <shibboleth><mapping> section
                    if ( $saml2_id && $shib_cfg->{mapping} && ref $shib_cfg->{mapping} eq 'HASH' ) {
                        my $mapped = 0;

                        for my $koha_field ( keys %{ $shib_cfg->{mapping} } ) {
                            my $entry = $shib_cfg->{mapping}{$koha_field};

                            # Entry may be a hashref with {is => 'attr'} or just a string
                            my $provider_field = ref $entry eq 'HASH' ? $entry->{is} : $entry;

                            $dbh->do(
                                q{
                                INSERT IGNORE INTO identity_provider_mappings
                                (identity_provider_id, provider_field, koha_field)
                                VALUES (?, ?, ?)
                            }, undef,
                                $saml2_id, $provider_field, $koha_field
                            );
                            $mapped++;
                        }

                        # Store the matchpoint on hostname entries (hostname_id=1=OPACBaseURL, hostname_id=2=staffClientBaseURL)
                        if ( my $matchpoint = $shib_cfg->{matchpoint} ) {
                            for my $hostname_id ( 1, 2 ) {
                                $dbh->do(
                                    q{
                                    INSERT IGNORE INTO identity_provider_hostnames
                                    (hostname_id, identity_provider_id, is_enabled, is_exclusive, matchpoint)
                                    VALUES (?, ?, 1, 0, ?)
                                }, undef, $hostname_id, $saml2_id, $matchpoint
                                );
                            }
                            say_success(
                                $out,
                                "Migrated Shibboleth matchpoint '$matchpoint' to hostname entries"
                            );
                        }

                        say_success(
                            $out,
                            "Migrated $mapped Shibboleth field mapping(s) to identity_provider_mappings"
                        );
                    }
                }
            }
        }

        # ── 9. Migrate OPACShibOnly / staffShibOnly to hostname-based is_exclusive ─
        # For each shibOnly syspref that is ON, create an is_exclusive=1 entry in the
        # identity_provider_hostnames table using the corresponding base URL syspref
        # to determine the hostname.

        my %shib_only_map = (
            OPACShibOnly  => 'OPACBaseURL',
            staffShibOnly => 'staffClientBaseURL',
        );

        for my $pref_name ( sort keys %shib_only_map ) {
            my ($shib_only) = $dbh->selectrow_array(
                "SELECT value FROM systempreferences WHERE variable = ?",
                undef, $pref_name
            );
            next unless $shib_only;

            my ($saml2_id) = $dbh->selectrow_array(
                "SELECT identity_provider_id FROM identity_providers
                 WHERE protocol = 'SAML2' LIMIT 1"
            );
            unless ($saml2_id) {
                say_warning(
                    $out,
                    "'$pref_name' is enabled but no SAML2 provider found; "
                        . "please configure is_exclusive manually after adding a SAML2 provider"
                );
                next;
            }

            my $url_pref = $shib_only_map{$pref_name};
            my ($url) = $dbh->selectrow_array(
                "SELECT value FROM systempreferences WHERE variable = ?",
                undef, $url_pref
            );
            unless ( $url && $url =~ m{^https?://([^/:]+)} ) {
                say_warning(
                    $out,
                    "'$pref_name' is enabled but '$url_pref' is not set or not a valid URL; "
                        . "please configure is_exclusive manually"
                );
                next;
            }
            my $hostname = $1;

            $dbh->do(
                "INSERT IGNORE INTO hostnames (hostname) VALUES (?)",
                undef, $hostname
            );
            my ($hostname_id) = $dbh->selectrow_array(
                "SELECT hostname_id FROM hostnames WHERE hostname = ?",
                undef, $hostname
            );

            $dbh->do(
                q{
                INSERT INTO identity_provider_hostnames
                (hostname_id, identity_provider_id, is_enabled, is_exclusive)
                VALUES (?, ?, 1, 1)
                ON DUPLICATE KEY UPDATE is_exclusive = 1
            }, undef, $hostname_id, $saml2_id
            );
            say_success(
                $out,
                "Enabled is_exclusive for hostname '$hostname' (migrated from $pref_name)"
            );
        }

        $dbh->do("DELETE FROM systempreferences WHERE variable IN ('OPACShibOnly', 'staffShibOnly')");
        say_success(
            $out,
            "Removed system preferences 'OPACShibOnly' and 'staffShibOnly'"
        );

        # ── 10. Add wildcard hostname and migrate providers without any hostname entries ──
        # The '*' wildcard hostname makes a provider available on all server hostnames,
        # preserving the pre-hostname-support behaviour for any existing providers that
        # were not explicitly linked to a specific hostname.

        $dbh->do("INSERT IGNORE INTO hostnames (hostname) VALUES ('*')");
        my ($wildcard_id) = $dbh->selectrow_array("SELECT hostname_id FROM hostnames WHERE hostname = '*'");

        if ($wildcard_id) {
            say_success( $out, "Ensured wildcard hostname '*' exists (hostname_id=$wildcard_id)" );

            # Find all enabled providers that have no hostname entries at all.
            my $orphan_providers = $dbh->selectall_arrayref(
                q{
                SELECT ip.identity_provider_id, ip.code
                FROM identity_providers ip
                LEFT JOIN identity_provider_hostnames iph
                    ON iph.identity_provider_id = ip.identity_provider_id
                WHERE ip.enabled = 1
                  AND iph.identity_provider_hostname_id IS NULL
            },
                { Slice => {} }
            );

            for my $provider ( @{$orphan_providers} ) {
                $dbh->do(
                    q{
                    INSERT IGNORE INTO identity_provider_hostnames
                    (hostname_id, identity_provider_id, is_enabled, is_exclusive)
                    VALUES (?, ?, 1, 0)
                }, undef, $wildcard_id, $provider->{identity_provider_id}
                );
                say_success(
                    $out,
                    "Added wildcard hostname entry for provider '$provider->{code}'"
                );
            }
        }

        return 1;
    },
};
