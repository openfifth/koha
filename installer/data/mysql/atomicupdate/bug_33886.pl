use Modern::Perl;

return {
    bug_number  => "33886",
    description => "Add DateInputStyle system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences ( variable, value, options, explanation, type )
                VALUES (
                    'DateInputStyle',
                    'single',
                    'single|split',
                    'Controls how date input fields are displayed. "single" uses the standard flatpickr calendar widget with maskito input masking. "split" shows three separate inputs for day, month, and year (order follows the dateformat preference) with an optional calendar button; does not apply to time, datetime, or booking date range fields.',
                    'Choice'
                )
            }
        );

        say $out "Removed system preference 'DateInputStyle'";
    },
};
