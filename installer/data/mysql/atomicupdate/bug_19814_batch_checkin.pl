use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "19814",
    description => "Add BatchCheckinDefaults preference and BATCH_CHECKIN_DEFAULTS authorised values",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
                VALUES (
                    'BatchCheckinDefaults',
                    '',
                    NULL,
                    'Default choices for the batch checkin feature',
                    'multiple'
                )
            }
        );
        say_success( $out, "Added new system preference 'BatchCheckinDefaults'" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_value_categories(category_name, is_system)
                VALUES ('BATCH_CHECKIN_DEFAULTS', 1)
            }
        );
        say_success( $out, "Added new authorised value category 'BATCH_CHECKIN_DEFAULTS'" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_values(category, authorised_value, lib, lib_opac) VALUES
                ('BATCH_CHECKIN_DEFAULTS', 'BATCH_CHECKIN_ENABLED',          'Enable batch mode for multiple returns', 'Enable batch mode for multiple returns'),
                ('BATCH_CHECKIN_DEFAULTS', 'BATCH_CHECKIN_KEEP_SELECTION',   'Remember batch mode settings',           'Remember batch mode settings'),
                ('BATCH_CHECKIN_DEFAULTS', 'BATCH_CHECKIN_IGNORE_NOTISSUED', "Hide 'not checked out' warnings",        "Hide 'not checked out' warnings"),
                ('BATCH_CHECKIN_DEFAULTS', 'BATCH_CHECKIN_CONFIRM_HOLD',     'Automatically capture holds',            'Automatically capture holds'),
                ('BATCH_CHECKIN_DEFAULTS', 'BATCH_CHECKIN_CONFIRM_TRANSFER', 'Automatically create transfers',         'Automatically create transfers')
            }
        );
        say_success( $out, "Added authorised values for 'BATCH_CHECKIN_DEFAULTS'" );
    },
};
