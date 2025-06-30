use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "4858",
    description => "Add print notice charge to patron categories and setup print transports",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add print_notice_charge column to categories table
        $dbh->do(
            q{ALTER TABLE categories
              ADD COLUMN print_notice_charge decimal(28,6) DEFAULT 0.00
              COMMENT 'charge for print notices (0.00 = disabled)'
              AFTER reservefee}
        );

        # Add PRINT_NOTICE debit type
        $dbh->do(
            q{
            INSERT IGNORE INTO account_debit_types (code, description, can_be_invoiced, can_be_sold, default_amount, is_system, restricts_checkouts)
            VALUES ('PRINT_NOTICE', 'Print notice charge', 0, 0, 0.50, 1, 0)
        }
        );

        # Add comprehensive print transport entries for all standard notice types
        # This enables print checkboxes to appear in messaging preferences
        $dbh->do(
            q{
            INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code, branchcode)
            VALUES
                (1, 'print', 0, 'circulation', 'DUE', ''),
                (1, 'print', 1, 'circulation', 'DUEDGST', ''),
                (2, 'print', 0, 'circulation', 'PREDUE', ''),
                (2, 'print', 1, 'circulation', 'PREDUEDGST', ''),
                (4, 'print', 0, 'reserves', 'HOLD', ''),
                (4, 'print', 1, 'reserves', 'HOLDDGST', ''),
                (5, 'print', 0, 'circulation', 'CHECKIN', ''),
                (6, 'print', 0, 'circulation', 'CHECKOUT', ''),
                (7, 'print', 0, 'ill', 'ILL_PICKUP_READY', ''),
                (8, 'print', 0, 'ill', 'ILL_REQUEST_UNAVAIL', ''),
                (9, 'print', 0, 'circulation', 'AUTO_RENEWALS', ''),
                (9, 'print', 1, 'circulation', 'AUTO_RENEWALS_DGST', ''),
                (10, 'print', 0, 'circulation', 'HOLD_REMINDER', ''),
                (11, 'print', 0, 'ill', 'ILL_REQUEST_UPDATE', ''),
                (12, 'print', 0, 'circulation', 'PICKUP_RECALLED_ITEM', ''),
                (13, 'print', 0, 'circulation', 'RETURN_RECALLED_ITEM', ''),
                (14, 'print', 0, 'members', 'MEMBERSHIP_EXPIRY', '')
        }
        );

        say_success(
            $out,
            "Added print_notice_charge column to categories table, debit type, and comprehensive print transport entries for print notice charging"
        );
    },
};
