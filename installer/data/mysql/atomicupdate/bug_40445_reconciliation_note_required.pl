use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "40445",
    description => "Add system preference for required cashup reconciliation notes",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add CashupReconciliationNoteRequired preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'CashupReconciliationNoteRequired',
                '0',
                '',
                'Require a reconciliation note when completing cashup with discrepancies between expected and actual amounts',
                'YesNo'
            )
        }
        );

        say_success( $out, "Added CashupReconciliationNoteRequired system preference" );
        say_info(
            $out,
            "CashupReconciliationNoteRequired: Controls whether reconciliation notes are required during cashup with discrepancies"
        );
    },
};
