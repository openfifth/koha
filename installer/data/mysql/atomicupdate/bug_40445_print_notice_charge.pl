use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "40445",
    description => "Add print_notice_charge column to patron categories table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'categories', 'print_notice_charge' ) ) {
            $dbh->do(
                q{ALTER TABLE categories
                  ADD COLUMN `print_notice_charge` decimal(28,6) DEFAULT 0.000000
                  COMMENT 'charge for print notices (0.00 = disabled)'
                  AFTER `overduenoticerequired`}
            );
            say_success( $out, "Added print_notice_charge column to categories table" );
        } else {
            say_info( $out, "print_notice_charge column already exists in categories table" );
        }
    },
};
