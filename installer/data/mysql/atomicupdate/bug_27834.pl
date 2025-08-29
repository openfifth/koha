use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "27834",
    description => "Add CircControlCheckoutLimitScope system preference with explicit scope options",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add new system preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type) VALUES
            ('CircControlCheckoutLimitScope', 'all', 'all|item|checkout', 'Determines how checkout limits are calculated. "all" counts all patron checkouts across all libraries. "item" counts only checkouts of items from the same library as the item being checked out (uses HomeOrHoldingBranch preference). "checkout" counts only checkouts made at the same library as the current checkout.', 'Choice')
        }
        );

        say_success( $out, "Added CircControlCheckoutLimitScope system preference" );
    },
};
