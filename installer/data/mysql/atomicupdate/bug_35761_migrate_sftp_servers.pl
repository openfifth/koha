use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "35761",
    description => "Migrate sftp_servers table data to file_transports (25.11.o5th upgrade)",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Only run if sftp_servers table exists (24.11.o5th customer branches)
        return unless TableExists('sftp_servers');

        say_info( $out, "Found sftp_servers table — migrating to file_transports" );

        # file_transports should already exist (created by community upgrade path)
        unless ( TableExists('file_transports') ) {
            say_warning( $out, "file_transports table not found — skipping migration" );
            return;
        }

        # Migrate sftp_servers rows into file_transports
        # Use name as deduplication key to avoid creating duplicates on re-run
        my $servers = $dbh->selectall_arrayref(
            q{
                SELECT id, name, host, port, transport, passive,
                       user_name, password, key_file, auth_mode,
                       download_directory, upload_directory, status, debug
                FROM sftp_servers
                WHERE name NOT IN (SELECT name FROM file_transports)
            },
            { Slice => {} }
        );

        my %sftp_id_to_transport_id;

        for my $server ( @{$servers} ) {
            $dbh->do(
                q{
                    INSERT INTO file_transports
                        (name, host, port, transport, passive, user_name, password,
                         key_file, auth_mode, download_directory, upload_directory,
                         status, debug)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                },
                undef,
                $server->{name},
                $server->{host},
                $server->{port},
                $server->{transport},
                $server->{passive},
                $server->{user_name},
                $server->{password},
                $server->{key_file},
                $server->{auth_mode},
                $server->{download_directory},
                $server->{upload_directory},
                $server->{status},
                $server->{debug},
            );

            my $new_id = $dbh->last_insert_id( undef, undef, 'file_transports', undef );
            $sftp_id_to_transport_id{ $server->{id} } = $new_id;

            say_success( $out, "Migrated sftp_server '$server->{name}' (id=$server->{id}) to file_transport $new_id" );
        }

        # Also build mapping for servers that already existed in file_transports (name match)
        my $existing = $dbh->selectall_arrayref(
            q{
                SELECT s.id AS sftp_id, ft.file_transport_id
                FROM sftp_servers s
                JOIN file_transports ft ON ft.name = s.name
            },
            { Slice => {} }
        );
        for my $row ( @{$existing} ) {
            $sftp_id_to_transport_id{ $row->{sftp_id} } ||= $row->{file_transport_id};
        }

        # If vendor_edi_accounts has sftp_server_id, migrate to file_transport_id
        if ( column_exists( 'vendor_edi_accounts', 'sftp_server_id' ) ) {
            say_info( $out, "Migrating vendor_edi_accounts.sftp_server_id to file_transport_id" );

            # Ensure file_transport_id column exists
            unless ( column_exists( 'vendor_edi_accounts', 'file_transport_id' ) ) {
                $dbh->do(
                    q{
                        ALTER TABLE vendor_edi_accounts
                        ADD COLUMN file_transport_id int(11) DEFAULT NULL,
                        ADD KEY `vendor_edi_accounts_file_transport_id` (`file_transport_id`),
                        ADD CONSTRAINT `vendor_edi_accounts_ibfk_file_transport`
                            FOREIGN KEY (`file_transport_id`) REFERENCES `file_transports` (`file_transport_id`)
                            ON DELETE SET NULL ON UPDATE CASCADE
                    }
                );
                say_success( $out, "Added file_transport_id column to vendor_edi_accounts" );
            }

            # Update each row that has an sftp_server_id set
            my $edi_accounts = $dbh->selectall_arrayref(
                q{ SELECT id, sftp_server_id FROM vendor_edi_accounts WHERE sftp_server_id IS NOT NULL },
                { Slice => {} }
            );

            for my $acct ( @{$edi_accounts} ) {
                my $new_transport_id = $sftp_id_to_transport_id{ $acct->{sftp_server_id} };
                if ($new_transport_id) {
                    $dbh->do(
                        q{ UPDATE vendor_edi_accounts SET file_transport_id = ? WHERE id = ? },
                        undef, $new_transport_id, $acct->{id}
                    );
                    say_success(
                        $out,
                        "Migrated vendor_edi_account $acct->{id}: sftp_server_id=$acct->{sftp_server_id} -> file_transport_id=$new_transport_id"
                    );
                } else {
                    say_warning(
                        $out,
                        "No matching file_transport found for vendor_edi_account $acct->{id} (sftp_server_id=$acct->{sftp_server_id})"
                    );
                }
            }

            # Drop sftp_server_id column
            $dbh->do(q{ ALTER TABLE vendor_edi_accounts DROP FOREIGN KEY vendor_edi_accounts_sftp_server_id })
                if column_exists( 'vendor_edi_accounts', 'sftp_server_id' );
            $dbh->do(q{ ALTER TABLE vendor_edi_accounts DROP COLUMN sftp_server_id });
            say_success( $out, "Dropped sftp_server_id column from vendor_edi_accounts" );
        }

        # Drop sftp_servers table
        $dbh->do(q{ DROP TABLE IF EXISTS sftp_servers });
        say_success( $out, "Dropped sftp_servers table" );
    },
};
