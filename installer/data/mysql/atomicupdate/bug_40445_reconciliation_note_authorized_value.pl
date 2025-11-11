use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "40445",
    description => "Add system preference for cashup reconciliation note authorized values",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add CashupReconciliationNoteAuthorisedValue preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'CashupReconciliationNoteAuthorisedValue',
                '',
                '',
                'Authorized value category to use for cashup reconciliation notes (leave empty for free text)',
                'Free'
            )
        }
        );

        say_success( $out, "Added CashupReconciliationNoteAuthorisedValue system preference" );
        say_info(
            $out,
            "CashupReconciliationNoteAuthorisedValue: Optionally restrict reconciliation notes to authorized values"
        );
    },
};
