use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "44187",
    description => "Add EdifactCancelledItemNotForLoanValue system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'EdifactCancelledItemNotForLoanValue',
                '',
                NULL,
                'Not for loan status given to an on-order item that cannot be deleted when a supplier cancels the order line by EDIFACT ORDRSP',
                'Choice'
            )
        }
        );

        say_success( $out, "Added new system preference 'EdifactCancelledItemNotForLoanValue'" );
    },
};
