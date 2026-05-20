use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "42652",
    description => "Add patron_restriction_blocks_inet to sip_accounts table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'sip_accounts', 'patron_restriction_blocks_inet' ) ) {
            $dbh->do(
                q{
                ALTER TABLE sip_accounts ADD COLUMN `patron_restriction_blocks_inet` tinyint(1) DEFAULT NULL
                    AFTER `patron_branchcode_in_ao`
            }
            );
            say_success( $out, "Added column 'sip_accounts.patron_restriction_blocks_inet'" );
        }
    },
};
