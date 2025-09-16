use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "40817",
    description => "Add reserve_id and old_reserve_id fields to accountlines table for hold-fee linking",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add reserve_id field to accountlines table
        unless ( column_exists( 'accountlines', 'reserve_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE accountlines
                ADD COLUMN reserve_id int(11) DEFAULT NULL AFTER old_issue_id,
                ADD KEY `accountlines_ibfk_reserves` (`reserve_id`),
                ADD CONSTRAINT `accountlines_ibfk_reserves`
                    FOREIGN KEY (`reserve_id`) REFERENCES `reserves` (`reserve_id`)
                    ON DELETE SET NULL ON UPDATE CASCADE
            }
            );
            say_success( $out, "Added reserve_id field to accountlines table" );
        } else {
            say_info( $out, "reserve_id field already exists in accountlines table" );
        }

        # Add old_reserve_id field to accountlines table
        unless ( column_exists( 'accountlines', 'old_reserve_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE accountlines
                ADD COLUMN old_reserve_id int(11) DEFAULT NULL AFTER reserve_id,
                ADD KEY `accountlines_ibfk_old_reserves` (`old_reserve_id`),
                ADD CONSTRAINT `accountlines_ibfk_old_reserves`
                    FOREIGN KEY (`old_reserve_id`) REFERENCES `old_reserves` (`reserve_id`)
                    ON DELETE SET NULL ON UPDATE CASCADE
            }
            );
            say_success( $out, "Added old_reserve_id field to accountlines table" );
        } else {
            say_info( $out, "old_reserve_id field already exists in accountlines table" );
        }

        say_success( $out, "Bug 40817: Hold-fee linking via direct foreign keys implemented successfully" );
    },
};
