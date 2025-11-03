use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "40445",
    description => "Add two-phase cashup workflow support with CASHUP_START action code",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Check if CASHUP_START already exists
        my $existing = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM cash_register_actions WHERE code = 'CASHUP_START'"
        );

        if (!$existing) {
            say_info( $out, "CASHUP_START action code will be available for new two-phase cashup workflow" );
        } else {
            say_warning( $out, "CASHUP_START actions already exist in the database" );
        }

        say_success( $out, "Two-phase cashup workflow support enabled" );
        say_info(
            $out,
            "Staff can now start cashup (begin counting) and complete cashup (finish reconciliation) as separate operations"
        );
    },
};