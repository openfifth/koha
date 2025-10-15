use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "40504",
    description => "Add managedby column to illrequests table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'illrequests', 'managedby' ) ) {
            $dbh->do(
                q{ALTER TABLE illrequests ADD COLUMN managedby int(11) DEFAULT NULL COMMENT 'Staff member manager of request' AFTER borrowernumber}
            );
            $dbh->do(q{ALTER TABLE illrequests ADD KEY illrequests_manfk (managedby)});
            $dbh->do(
                q{ALTER TABLE illrequests ADD CONSTRAINT illrequests_manfk FOREIGN KEY (managedby) REFERENCES borrowers (borrowernumber) ON DELETE SET NULL ON UPDATE CASCADE}
            );

            say_success( $out, "Added column 'illrequests.managedby'" );
        }
    },
};
