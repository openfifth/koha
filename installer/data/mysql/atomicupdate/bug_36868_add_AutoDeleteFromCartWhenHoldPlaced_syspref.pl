use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "36868",
    description => "Add system preference AutoDeleteFromCartWhenHoldPlaced",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Do your stuff here
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES
            ('AutoDeleteFromCartWhenHoldPlaced', '','', 'Automatically delete items from cart when a hold is placed','Choice')
        }
        );

        say $out "Added new system preference 'AutoDeleteFromCartWhenHoldPlaced'";
    },
};
