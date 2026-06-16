use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "39058",
    description => "Add new system preference IntranetStickyHeader",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences ( variable, value, options, explanation, type )
                VALUES (
                    'IntranetStickyHeader',
                    '1',
                    NULL,
                    'Pin the main navigation bar and search bar to the top of the page while scrolling in the staff interface.',
                    'YesNo'
                )
            }
        );

        say_success( $out, "Added new system preference 'IntranetStickyHeader'" );
    },
};
