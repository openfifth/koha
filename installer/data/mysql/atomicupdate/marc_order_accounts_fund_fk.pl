use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "ORDERLINES",
    description => "Change marc_order_accounts.budget_id FK to reference acq_funds",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( foreign_key_exists( 'marc_order_accounts', 'fk_marc_order_accounts_fund_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE marc_order_accounts
                    DROP FOREIGN KEY IF EXISTS fk_marc_order_accounts_budget_id,
                    DROP FOREIGN KEY IF EXISTS marc_ordering_account_ibfk_2,
                    ADD CONSTRAINT fk_marc_order_accounts_fund_id
                        FOREIGN KEY (budget_id) REFERENCES acq_funds(fund_id)
                        ON DELETE SET NULL ON UPDATE CASCADE
            }
            );

            say_success( $out, "Updated marc_order_accounts.budget_id FK to reference acq_funds(fund_id)" );
        } else {
            say_info( $out, "marc_order_accounts.budget_id FK already references acq_funds(fund_id)" );
        }
    },
};
