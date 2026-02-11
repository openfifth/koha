use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "XXXXX",
    description => "Add a new syspref for PatronAgeRestriction",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Do you stuffs here
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('PatronAgeRestriction', '', NULL, 'Patron\'s maximum age during registration. If empty, no age restriction is applied.', 'Integer')
        }
        );
        say $out "Added new syspref 'PatronAgeRestriction'";

        $dbh->do(
            q{
            UPDATE IGNORE systempreferences SET `explanation` = 'Patron\'s maximum age during self registration. If empty, honor PatronAgeRestriction.' WHERE `variable` = 'PatronSelfRegistrationAgeRestriction'
        }
        );
        say $out "Updated explanation for syspref 'PatronSelfRegistrationAgeRestriction'";
    },
};
