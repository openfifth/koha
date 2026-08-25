use Modern::Perl;

return {
    bug_number  => "43127",
    description => "Add UseNewHoldsInterface system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES ('UseNewHoldsInterface', '0', NULL, 'the new holds interface in the staff interface.', 'YesNo')
        }
        );

        say $out "Added new system preference 'UseNewHoldsInterface'";
    },
};
