use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "40136",
    description => "Add trace and diff columns to action_logs table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'action_logs', 'trace' ) ) {
            $dbh->do(
                q{ALTER TABLE action_logs ADD COLUMN `trace` text DEFAULT NULL COMMENT 'An optional stack trace enabled by ActionLogsTraceDepth' AFTER script}
            );
            say_success( $out, "Added column 'action_logs.trace'" );
        }

        unless ( column_exists( 'action_logs', 'diff' ) ) {
            $dbh->do(
                q{ALTER TABLE action_logs ADD COLUMN `diff` longtext DEFAULT NULL COMMENT 'Stores a diff of the changed object' AFTER trace}
            );
            say_success( $out, "Added column 'action_logs.diff'" );
        }
    },
};
