use Modern::Perl;

return {
    bug_number  => "38666",
    description => "Closed stack requests",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'items', 'is_closed_stack' ) ) {
            $dbh->do(
                "ALTER TABLE `items` ADD COLUMN `is_closed_stack` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'if true, special rules apply for holds on this item' AFTER `itype`"
            );
            say $out "Column items.is_closed_stack created";
        } else {
            say $out "Column items.is_closed_stack not created (already exists)";
        }

        unless ( column_exists( 'deleteditems', 'is_closed_stack' ) ) {
            $dbh->do(
                "ALTER TABLE `deleteditems` ADD COLUMN `is_closed_stack` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'if true, special rules apply for holds on this item' AFTER `itype`"
            );
            say $out "Column deleteditems.is_closed_stack created";
        } else {
            say $out "Column deleteditems.is_closed_stack not created (already exists)";
        }

        unless ( column_exists( 'reserves', 'closed_stack_request_slip_printed' ) ) {
            $dbh->do(
                "ALTER TABLE `reserves` ADD COLUMN `closed_stack_request_slip_printed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'boolean flag to track if closed stack request slip was printed (useful for display/filtering)' AFTER `non_priority`"
            );
            say $out "Column reserves.closed_stack_request_slip_printed created";
        } else {
            say $out "Column reserves.closed_stack_request_slip_printed not created (already exists)";
        }

        unless ( column_exists( 'old_reserves', 'closed_stack_request_slip_printed' ) ) {
            $dbh->do(
                "ALTER TABLE `old_reserves` ADD COLUMN `closed_stack_request_slip_printed` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'boolean flag to track if closed stack request slip was printed (useful for display/filtering)' AFTER `non_priority`"
            );
            say $out "Column old_reserves.closed_stack_request_slip_printed created";
        } else {
            say $out "Column old_reserves.closed_stack_request_slip_printed not created (already exists)";
        }

    },
};
