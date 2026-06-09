use Modern::Perl;
use Koha::Installer::Output qw(say_success say_info);

return {
    bug_number  => "WCC-LOCAL",
    description => "Add EDIServiceChargesBudgetMap system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
                VALUES (
                    'EDIServiceChargesBudgetMap',
                    'WCC=104\nRBKC=76',
                    NULL,
                    'Maps vendor name prefixes to acquisition budget IDs for EDI service charge adjustments. One mapping per line in the format VENDOR_PREFIX=BUDGET_ID (e.g. WCC=104). The prefix is matched case-insensitively against the start of the vendor name. Update budget IDs each financial year during rollover.',
                    'Textarea'
                )
            }
        );

        say_success( $out, "Added new system preference 'EDIServiceChargesBudgetMap'" );
        say_info( $out, "Default value preserves existing WCC=104 and RBKC=76 mappings" );
        say_info( $out, "Update budget IDs via Administration > System preferences each financial year" );
    },
};
