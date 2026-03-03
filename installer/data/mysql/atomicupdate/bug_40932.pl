use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "40932",
    description => "Add automatic invoice closing on physical item receipt",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'aqorders_items', 'received' ) ) {
            $dbh->do(
                q{
                ALTER TABLE aqorders_items
                    ADD COLUMN `received` datetime DEFAULT NULL
                    COMMENT 'Datetime the item was first physically received via circulation check-in'
            }
            );
            say_success( $out, "Added column 'aqorders_items.received'" );
        }

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES
            ('AutoCloseInvoicesOnCheckin', '0', NULL,
             'Automatically close acquisitions invoices when all their items have been physically checked in at circulation', 'YesNo'),
            ('AutoCloseInvoiceAlertDays', '14', NULL,
             'Show staff alert for open invoices with outstanding items older than this many days. 0 = disabled.', 'Integer')
        }
        );
        say_success( $out, "Added system preferences 'AutoCloseInvoicesOnCheckin' and 'AutoCloseInvoiceAlertDays'" );
    },
};
