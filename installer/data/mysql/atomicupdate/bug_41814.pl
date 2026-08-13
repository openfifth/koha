use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41814",
    description => "Add a new system preference for PatronAgeRestriction",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Do you stuffs here
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('PatronAgeRestriction', '', NULL, 'Patron\'s maximum age during registration. If empty, no age restriction is applied.', 'Integer')
        }
        );
        say_success( $out, "Added new system preference 'PatronAgeRestriction'" );

        $dbh->do(
            q{
            UPDATE IGNORE systempreferences SET `explanation` = 'Patron\'s maximum age during self registration. If empty, honor PatronAgeRestriction.' WHERE `variable` = 'PatronSelfRegistrationAgeRestriction'
        }
        );
        say_success( $out, "Updated explanation for system preference 'PatronSelfRegistrationAgeRestriction'" );
    },
};
