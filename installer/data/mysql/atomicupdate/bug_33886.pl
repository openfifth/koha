use Modern::Perl;

return {
    bug_number  => "33886",
    description => "Remove DateInputStyle system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                DELETE FROM systempreferences WHERE variable = 'DateInputStyle'
            }
        );

        say $out "Removed system preference 'DateInputStyle'";
    },
};
