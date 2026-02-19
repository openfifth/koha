use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "26355",
    description => "Patron self-renewal",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'categories', 'self_renewal_enabled' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories ADD COLUMN `self_renewal_enabled` tinyint(1) NOT NULL DEFAULT 0
                COMMENT 'allow self renewal for this category'
                AFTER `enforce_expiry_notice`
                }
            );

            say_success( $out, "Added column 'self_renewal_enabled' to categories" );
        }
        unless ( column_exists( 'categories', 'self_renewal_availability_start' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories ADD COLUMN `self_renewal_availability_start` smallint(6) DEFAULT NULL
                COMMENT 'how long before the patron expiry date self-renewal should be made available (overrides system default of NotifyBorrowerDeparture)'
                AFTER `self_renewal_enabled`
                }
            );

            say_success( $out, "Added column 'self_renewal_availability_start' to categories" );
        }
        unless ( column_exists( 'categories', 'self_renewal_fines_block' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories ADD COLUMN `self_renewal_fines_block` int(11) DEFAULT NULL
                COMMENT 'the amount owed in fines before self renewal is blocked (overrides system default of noissuescharge)'
                AFTER `self_renewal_availability_start`
                }
            );

            say_success( $out, "Added column 'self_renewal_fines_block' to categories" );
        }
        unless ( column_exists( 'categories', 'self_renewal_if_expired' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories ADD COLUMN `self_renewal_if_expired` smallint(6) DEFAULT 0
                COMMENT 'how long after expiry a patron can self renew their account'
                AFTER `self_renewal_fines_block`
                }
            );

            say_success( $out, "Added column 'self_renewal_if_expired' to categories" );
        }
        unless ( column_exists( 'categories', 'self_renewal_failure_message' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories ADD COLUMN `self_renewal_failure_message` mediumtext DEFAULT NULL
                COMMENT 'the message to display if self renewal is not successful'
                AFTER `self_renewal_fines_block`
                }
            );

            say_success( $out, "Added column 'self_renewal_failure_message' to categories" );
        }
        unless ( column_exists( 'categories', 'self_renewal_information_message' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories ADD COLUMN `self_renewal_information_message` mediumtext DEFAULT NULL
                COMMENT 'the message to display if self renewal is not successful'
                AFTER `self_renewal_failure_message`
                }
            );

            say_success( $out, "Added column 'self_renewal_information_message' to categories" );
        }
    },
};
