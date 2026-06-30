use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "38924",
    description => "Remove stale UseEmailReceipts system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # UseEmailReceipts was renamed to AutomaticEmailReceipts upstream
        # (DBRev 24.12.00.031). A bad backport re-added the old name to
        # mandatory/sysprefs.sql, so fresh installs ended up with an orphaned
        # UseEmailReceipts row alongside AutomaticEmailReceipts. Drop the orphan.
        my ($count) = $dbh->selectrow_array(
            q|SELECT COUNT(*) FROM systempreferences WHERE variable = 'UseEmailReceipts'|
        );

        if ($count) {
            $dbh->do(q|DELETE FROM systempreferences WHERE variable = 'UseEmailReceipts'|);
            say_success( $out, "Removed stale 'UseEmailReceipts' system preference (use 'AutomaticEmailReceipts')" );
        } else {
            say_info( $out, "System preference 'UseEmailReceipts' not present, nothing to do" );
        }
    },
};
