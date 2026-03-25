use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "tbc",
    description => "Funds and ledgers tables",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('acq_fiscal_period') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_fiscal_period` (
                `fiscal_period_id` INT(11) NOT NULL AUTO_INCREMENT,
                `name` VARCHAR(80) NOT NULL COMMENT 'name for the fiscal period',
                `description` longtext DEFAULT '' COMMENT 'description for the fiscal period',
                `start_date` date DEFAULT NULL COMMENT 'start date of the event',
                `end_date` date DEFAULT NULL COMMENT 'end date of the event',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the fiscal period currently active',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fiscal period',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                `created_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'time of the creation to the fiscal period',
                `modified_date` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fiscal period',
                PRIMARY KEY (`fiscal_period_id`),
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_fiscal_period'" );
        } else {
            say_info( $out, "Table 'acq_fiscal_period' already exists" );
        }

        unless ( TableExists('acq_ledgers') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_ledgers` (
                `ledger_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the ledger applies to',
                `name` VARCHAR(80) NOT NULL DEFAULT '' COMMENT 'name for the ledger',
                `description` longtext DEFAULT '' COMMENT 'description for the ledger',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the ledger for use with external accounting systems',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the ledger currently active',
                `locked` TINYINT(1) DEFAULT '1' COMMENT 'is the ledger currently locked',
                `currency` VARCHAR(10) NOT NULL COMMENT 'currency of the ledger',
                `ledger_amount` decimal(28,2) NOT NULL DEFAULT 0.00 COMMENT 'spend limit for the ledger',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the ledger',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_warning_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'warning limit for overencumbrance',
                `created_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'time of the creation of the ledger',
                `modified_date` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the ledger',
                PRIMARY KEY (`ledger_id`),
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `acq_fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_ledgers'" );
        } else {
            say_info( $out, "Table 'acq_ledgers' already exists" );
        }

        unless ( TableExists('acq_fund_group') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_fund_group` (
                `fund_group_id` INT(11) NOT NULL AUTO_INCREMENT,
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the fund group',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund allocation',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                PRIMARY KEY (`fund_group_id`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_fund_group'" );
        } else {
            say_info( $out, "Table 'acq_fund_group' already exists" );
        }

        unless ( TableExists('acq_funds') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_funds` (
                `fund_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fund_parent_id` INT(11) DEFAULT NULL COMMENT 'if this fund is a child of another the parent fund id will be stored here',
                `ledger_id` INT(11) NOT NULL COMMENT 'ledger the fund applies to',
                `fiscal_period_id` INT(11) NOT NULL COMMENT 'fiscal period the fund applies to',
                `fund_group_id` INT(11) DEFAULT NULL COMMENT 'group for the fund',
                `name` VARCHAR(80) DEFAULT NULL COMMENT 'name for the fund',
                `code` VARCHAR(30) DEFAULT NULL COMMENT 'code for the fund',
                `description` longtext DEFAULT '' COMMENT 'description for the fund',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the fund for use with external accounting systems',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the fund currently active',
                `fund_type` VARCHAR(255) DEFAULT NULL COMMENT 'type for the fund',
                `fund_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the fund',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fund',
                `fund_permission` INT(11) DEFAULT NULL COMMENT 'level of permission for this fund',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_warning_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'limit for overencumbrance',
                `created_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'time of the creation of the fund',
                `modified_date` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fund',
                PRIMARY KEY (`fund_id`),
                FOREIGN KEY (`ledger_id`) REFERENCES `acq_ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `acq_fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fund_group_id`) REFERENCES `acq_fund_group` (`fund_group_id`) ON DELETE SET NULL ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_funds'" );
        } else {
            say_info( $out, "Table 'acq_funds' already exists" );
        }

        unless ( TableExists('acq_allocations') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_allocations` (
                `allocation_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fund_id` INT(11) DEFAULT NULL COMMENT 'fund the allocation applies to',
                `ledger_id` INT(11) DEFAULT NULL COMMENT 'ledger the allocation applies to',
                `allocation_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'amount for the allocation',
                `is_transferred_to` INT(11) DEFAULT NULL COMMENT 'entity making the allocation',
                `is_transferred_from` INT(11) DEFAULT NULL COMMENT 'entity receiving the allocation',
                `type` enum('increase','decrease','transfer') NOT NULL COMMENT 'type of the allocation',
                `reference` VARCHAR(255) DEFAULT NULL COMMENT 'allocation reference',
                `note` longtext DEFAULT '' COMMENT 'any notes associated to the allocation',
                `created_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'when the allocation was made',
                PRIMARY KEY (`allocation_id`),
                FOREIGN KEY (`fund_id`) REFERENCES `acq_funds` (`fund_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`ledger_id`) REFERENCES `acq_ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_allocations'" );
        } else {
            say_info( $out, "Table 'acq_allocations' already exists" );
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
