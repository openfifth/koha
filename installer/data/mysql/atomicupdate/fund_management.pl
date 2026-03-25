use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "tbc",
    description => "Funds and ledgers tables",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('fiscal_period') ) {
            $dbh->do(
                q{
                CREATE TABLE `fiscal_period` (
                `fiscal_period_id` INT(11) NOT NULL AUTO_INCREMENT,
                `description` longtext DEFAULT '' COMMENT 'description for the fiscal period',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the fiscal period',
                `start_date` date DEFAULT NULL COMMENT 'start date of the event',
                `end_date` date DEFAULT NULL COMMENT 'end date of the event',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the fiscal period',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the fiscal period currently active',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fiscal period',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fiscal period',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                PRIMARY KEY (`fiscal_period_id`),
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'fiscal_period'" );
        } else {
            say_info( $out, "Table 'fiscal_period' already exists" );
        }

        unless ( TableExists('ledgers') ) {
            $dbh->do(
                q{
                CREATE TABLE `ledgers` (
                `ledger_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the ledger applies to',
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the ledger',
                `description` longtext DEFAULT '' COMMENT 'description for the ledger',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the ledger',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the ledger for use with external accounting systems',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the ledger',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the ledger currently active',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the ledger',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the ledger',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the ledger',
                `over_spend_allowed` TINYINT(1) DEFAULT '1' COMMENT 'is an overspend allowed on the ledger',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_limit_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'limit for overspend',
                `os_warning_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a warning for overspend',
                `os_limit_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a block on the ledger for overspend',
                PRIMARY KEY (`ledger_id`),
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'ledgers'" );
        } else {
            say_info( $out, "Table 'ledgers' already exists" );
        }

        unless ( TableExists('fund_group') ) {
            $dbh->do(
                q{
                CREATE TABLE `fund_group` (
                `fund_group_id` INT(11) NOT NULL AUTO_INCREMENT,
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the fund group',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund allocation',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                PRIMARY KEY (`fund_group_id`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'fund_group'" );
        } else {
            say_info( $out, "Table 'fund_group' already exists" );
        }

        unless ( TableExists('funds') ) {
            $dbh->do(
                q{
                CREATE TABLE `funds` (
                `fund_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fund_parent_id` INT(11) DEFAULT NULL COMMENT 'if this fund is a child of another the parent fund id will be stored here',
                `ledger_id` INT(11) DEFAULT NULL COMMENT 'ledger the fund applies to',
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the fund applies to',
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the fund',
                `description` longtext DEFAULT '' COMMENT 'description for the fund',
                `fund_type` VARCHAR(255) DEFAULT NULL COMMENT 'type for the fund',
                `fund_group_id` INT(11) DEFAULT NULL COMMENT 'group for the fund',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the fund',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the fund for use with external accounting systems',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the fund currently active',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fund',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the fund',
                `over_spend_allowed` TINYINT(1) DEFAULT '1' COMMENT 'is an overspend allowed on the fund',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_limit_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'limit for overspend',
                `os_warning_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a warning for overspend',
                `os_limit_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a block on the fund for overspend',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fund',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                PRIMARY KEY (`fund_id`),
                FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fund_group_id`) REFERENCES `fund_group` (`fund_group_id`) ON DELETE SET NULL ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'funds'" );
        } else {
            say_info( $out, "Table 'funds' already exists" );
        }

        unless ( TableExists('fund_allocation') ) {
            $dbh->do(
                q{
                CREATE TABLE `fund_allocation` (
                `fund_allocation_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fund_id` INT(11) DEFAULT NULL COMMENT 'fund the fund allocation applies to',
                `ledger_id` INT(11) DEFAULT NULL COMMENT 'ledger the fund allocation applies to',
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the fund allocation applies to',
                `allocation_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'amount for the allocation',
                `reference` VARCHAR(255) DEFAULT NULL COMMENT 'allocation reference',
                `note` longtext DEFAULT '' COMMENT 'any notes associated to the allocation',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund allocation',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fund allocation',
                `type` enum('encumbered','spent', 'transfer', 'credit') DEFAULT NULL COMMENT 'type of the fund allocation',
                `is_transfer` TINYINT(1) DEFAULT '0' COMMENT 'is the fund allocation a transfer to/from another fund',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fund allocation',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                PRIMARY KEY (`fund_allocation_id`),
                FOREIGN KEY (`fund_id`) REFERENCES `funds` (`fund_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'fund_allocation'" );
        } else {
            say_info( $out, "Table 'fund_allocation' already exists" );
        }

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_value_categories(  category_name, is_system  ) VALUES
                ('FUND_TYPE', 1);
                }
        );
        say_success( $out, "Added new category 'FUND_TYPE''" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_values(  category, authorised_value, lib  ) VALUES
                ('FUND_TYPE', "PRINT", "Print materials"),
                ('FUND_TYPE', "ELECTRONIC", "Electronic materials"),
                ('FUND_TYPE', "SUBSCRIPTION", "Subscription materials"),
                ('FUND_TYPE', "MISC", "Miscellaneous expenses");
                }
        );
        say_success( $out, "Added new authorised values to those categories" );

    },
};
