use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41311",
    description => "Add patron_branchcode_in_ao to sip_accounts table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'sip_accounts', 'patron_branchcode_in_ao' ) ) {
            $dbh->do(
                q{
                ALTER TABLE sip_accounts ADD COLUMN `patron_branchcode_in_ao` tinyint(1) AFTER `send_patron_home_library_in_af`;
            }
            );
        }

        say_success( $out, "Added column 'sip_accounts.patron_branchcode_in_ao'" );
    },
};
