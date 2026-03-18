use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "42110",
    description => "Migrate marc_order_accounts.download_directory to local type file transport",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( column_exists( 'marc_order_accounts', 'download_directory' ) ) {
            my $accounts = $dbh->selectall_arrayref(
                q{
                    SELECT id, description, download_directory
                    FROM marc_order_accounts
                    WHERE download_directory IS NOT NULL
                      AND download_directory != ''
                      AND file_transport_id IS NULL
                },
                { Slice => {} }
            );

            for my $acct ( @{$accounts} ) {
                $dbh->do(
                    q{
                        INSERT INTO file_transports (name, host, port, transport, passive, auth_mode, download_directory, debug)
                        VALUES (?, 'localhost', 0, 'local', 1, 'noauth', ?, 0)
                    },
                    undef,
                    "MARC order account: $acct->{description} [$acct->{id}] (Migrated)",
                    $acct->{download_directory}
                );
                my $file_transport_id = $dbh->last_insert_id( undef, undef, 'file_transports', undef );

                $dbh->do(
                    q{ UPDATE marc_order_accounts SET file_transport_id = ? WHERE id = ? },
                    undef,
                    $file_transport_id,
                    $acct->{id}
                    ) == 1
                    && say_success(
                    $out,
                    "Migrated download_directory for account '$acct->{description}' to file_transport $file_transport_id"
                    );
            }

            $dbh->do(q{ ALTER TABLE `marc_order_accounts` DROP COLUMN `download_directory` });
            say_success( $out, "Dropped column 'marc_order_accounts.download_directory'" );
        }

    },
};
