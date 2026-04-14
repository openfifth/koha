use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "tbc",
    description => "Ordering tables",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('acq_purchase_orders') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_purchase_orders` (
                `purchase_order_id` INT(11) NOT NULL AUTO_INCREMENT,
                `vendor_id` int(11) NOT NULL COMMENT 'link to the vendor',
                `status` enum('new', 'ordered','cancelled') DEFAULT NULL COMMENT 'status of the purchase order',
                `po_name` VARCHAR(50) DEFAULT NULL COMMENT 'name for the purchase order',
                `po_internal_note` LONGTEXT DEFAULT NULL COMMENT 'internal note for the purchase order',
                `po_vendor_note` LONGTEXT DEFAULT NULL COMMENT 'vendor note for the purchase order',
                `external_po_number` LONGTEXT DEFAULT NULL COMMENT 'external po number for the purchase order',
                `contract_id` int(11) NOT NULL COMMENT 'link to the contract',
                `created_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'creation date of the purchase order',
                `modified_date` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'last update of the purchase order',
                `ordered_date` timestamp NULL DEFAULT NULL COMMENT 'ordering date of the purchase order',
                `order_method` VARCHAR(255) DEFAULT NULL COMMENT 'method of purchase for the purchase order',
                `created_by` INT(11) DEFAULT NULL COMMENT 'creator of the purchase order',
                `delivery_branch` varchar(10) DEFAULT NULL COMMENT 'branch to deliver to',
                `billing_branch` varchar(10) DEFAULT NULL COMMENT 'branch to bill for the order',
                PRIMARY KEY (`purchase_order_id`),
                FOREIGN KEY (`vendor_id`) REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`contract_id`) REFERENCES `aqcontract` (`contractnumber`) ON UPDATE CASCADE,
                FOREIGN KEY (`delivery_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`billing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_purchase_orders'" );
        } else {
            say_info( $out, "Table 'acq_purchase_orders' already exists" );
        }

        unless ( TableExists('acq_orderlines') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_orderlines` (
                `orderline_id` INT(11) NOT NULL AUTO_INCREMENT,
                `biblionumber` INT(11) DEFAULT NULL COMMENT 'bibliographic record for the order line',
                `deleted_biblionumber` INT(11) DEFAULT NULL COMMENT 'deleted bibliographic record for the order line',
                `subscriptionid` INT(11) DEFAULT NULL COMMENT 'subscription record for the order line',
                `purchase_order_id` INT(11) DEFAULT NULL COMMENT 'purchase order for the order line',
                `created_by` INT(11) DEFAULT NULL COMMENT 'creator of the order line',
                `created_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'creation date of the order line',
                `modified_date` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'last update of the order line',
                `ordered_date` timestamp NULL DEFAULT NULL COMMENT 'ordering date of the order line',
                `status` enum('draft','new', 'ordered', 'continuing', 'complete', 'partial', 'unsubscribed', 'cancelled') NOT NULL COMMENT 'status of the order line',
                `payment_status` enum('pending', 'partial', 'paid', 'unpaid', 'cancelled') DEFAULT NULL COMMENT 'status of the order line',
                `is_continuous` TINYINT(1) DEFAULT '0' COMMENT 'is this a standing order line?',
                `renewal_required` TINYINT(1) DEFAULT '0' COMMENT 'does this need renewing?',
                `review_interval` INT(11) DEFAULT NULL COMMENT 'days between reviews',
                `last_review_date` date DEFAULT NULL COMMENT 'last date order line was reviewed',
                `planned_cancellation_date` date DEFAULT NULL COMMENT 'date the subscription is to be cancelled',
                `acquisition_method` VARCHAR(255) DEFAULT NULL COMMENT 'method of purchase for the order line',
                `create_items` enum('ordering','receiving','cataloging') DEFAULT NULL COMMENT 'item creation point for the order line',
                `managing_branch` varchar(10) DEFAULT NULL COMMENT 'branch responsible for the order line',
                `vendor_id` int(11) DEFAULT NULL COMMENT 'link to the vendor',
                `quantity_ordered` int(11) NOT NULL COMMENT 'quantity ordered',
                `uncertain_price` TINYINT(1) DEFAULT '0' COMMENT 'is the price uncertain?',
                `vendor_price_currency` varchar(10) DEFAULT NULL COMMENT 'currency used for the vendor price',
                `vendor_price` decimal(28,6) DEFAULT 0.00 COMMENT 'price charged by the vendor',
                `discount_percentage` decimal(5,2) DEFAULT NULL COMMENT 'discount applied to the price',
                `discount_amount_oc` decimal(28,6) DEFAULT NULL COMMENT 'discount amount in the original currency',
                `replacement_price` decimal(28,6) DEFAULT NULL COMMENT 'replacement cost for the purchase',
                `calculated_amount_oc` decimal(28,6) DEFAULT 0.00 COMMENT 'the total cost in the original currency including discount',
                `internal_note` longtext DEFAULT NULL COMMENT 'internal note',
                `receiving_note` longtext DEFAULT NULL COMMENT 'receiving note',
                `vendor_note` longtext DEFAULT NULL COMMENT 'vendor note',
                `urgent_order` TINYINT(1) DEFAULT '0' COMMENT 'is this an urgent order?',
                `statistic1` varchar(80) DEFAULT NULL COMMENT 'statistical field',
                `statistic2` varchar(80) DEFAULT NULL COMMENT 'second statistical field',
                `estimated_delivery_date` date DEFAULT NULL COMMENT 'date the delivery is expected',
                `edi_line_item_id` varchar(35) DEFAULT NULL COMMENT 'supplier article id for an edifact order line',
                `edi_suppliers_reference_number` varchar(35) DEFAULT NULL COMMENT 'supplier unique edifact quote ref',
                `edi_suppliers_reference_qualifier` varchar(3) DEFAULT NULL COMMENT 'supplier unique edifact quote ref qualifier',
                `edi_suppliers_report` mediumtext DEFAULT NULL COMMENT 'reports received from an edi supplier',
                PRIMARY KEY (`orderline_id`),
                FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`),
                FOREIGN KEY (`deleted_biblionumber`) REFERENCES `deletedbiblio` (`biblionumber`),
                FOREIGN KEY (`subscriptionid`) REFERENCES `subscription` (`subscriptionid`),
                FOREIGN KEY (`purchase_order_id`) REFERENCES `acq_purchase_orders` (`purchase_order_id`),
                FOREIGN KEY (`created_by`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`managing_branch`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`vendor_id`) REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_orderlines'" );
        } else {
            say_info( $out, "Table 'acq_orderlines' already exists" );
        }

        unless ( TableExists('acq_orderline_fund_distribution') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_orderline_fund_distribution` (
                `orderline_fund_distribution_id` INT(11) NOT NULL AUTO_INCREMENT,
                `orderline_id` INT(11) NOT NULL COMMENT 'orderline the distribution was made by',
                `fund_id` INT(11) NOT NULL COMMENT 'fund the distribution was made against',
                `percentage` decimal(5,2) DEFAULT NULL COMMENT 'distribution percentage',
                `distributed_amount_oc` decimal(28,6) NOT NULL COMMENT 'distribution amount in the original currency',
                `exchange_rate` decimal(20,10) NOT NULL COMMENT 'exchange rate for the distribution',
                `distributed_amount` decimal(28,6) NOT NULL COMMENT 'distribution amount in the active currency',
                `tax_rate` decimal(6,4) NOT NULL COMMENT 'tax rate on ordering',
                `tax_value` decimal(28,6) NOT NULL COMMENT 'tax value on ordering',
                `distributed_amount_tax_excluded` decimal(28,6) NOT NULL COMMENT 'distributed amount minus tax',
                `distributed_amount_tax_included` decimal(28,6) NOT NULL COMMENT 'distributed amount including tax',
                PRIMARY KEY (`orderline_fund_distribution_id`),
                FOREIGN KEY (`orderline_id`) REFERENCES `acq_orderlines` (`orderline_id`),
                FOREIGN KEY (`fund_id`) REFERENCES `funds` (`fund_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_orderline_fund_distribution'" );
        } else {
            say_info( $out, "Table 'acq_orderline_fund_distribution' already exists" );
        }

        unless ( TableExists('acq_orderline_users') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_orderline_users` (
                `orderline_id` INT(11) NOT NULL COMMENT 'orderline the user is for',
                `borrowernumber` INT(11) NOT NULL COMMENT 'the user',
                PRIMARY KEY (`orderline_id`,`borrowernumber`),
                FOREIGN KEY (`orderline_id`) REFERENCES `acq_orderlines` (`orderline_id`),
                FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_orderline_users'" );
        } else {
            say_info( $out, "Table 'acq_orderline_users' already exists" );
        }

        unless ( TableExists('acq_orderline_managers') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_orderline_managers` (
                `orderline_id` INT(11) NOT NULL COMMENT 'orderline the user is for',
                `borrowernumber` INT(11) NOT NULL COMMENT 'the user',
                PRIMARY KEY (`orderline_id`,`borrowernumber`),
                FOREIGN KEY (`orderline_id`) REFERENCES `acq_orderlines` (`orderline_id`),
                FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_orderline_managers'" );
        } else {
            say_info( $out, "Table 'acq_orderline_managers' already exists" );
        }

        unless ( TableExists('acq_orderline_items') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_orderline_items` (
                `orderline_id` INT(11) NOT NULL COMMENT 'orderline the item is linked to',
                `itemnumber` INT(11) NOT NULL COMMENT 'the linked item',
                PRIMARY KEY (`orderline_id`,`itemnumber`),
                FOREIGN KEY (`orderline_id`) REFERENCES `acq_orderlines` (`orderline_id`) ON DELETE CASCADE,
                FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_orderline_items'" );
        } else {
            say_info( $out, "Table 'acq_orderline_items' already exists" );
        }

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_value_categories(  category_name, is_system  ) VALUES
                ('ACQUISITION_METHOD', 1);
                }
        );
        say_success( $out, "Added new category 'ACQUISITION_METHOD'" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_values(  category, authorised_value, lib  ) VALUES
                ('ACQUISITION_METHOD', "PURCHASE", "Purchase"),
                ('ACQUISITION_METHOD', "GIFT", "Gift"),
                ('ACQUISITION_METHOD', "LEGAL_DEPOSIT", "Legal deposit"),
                ('ACQUISITION_METHOD', "EXCHANGE", "Exchange"),
                ('ACQUISITION_METHOD', "APPROVAL_PLAN", "Approval plan");
                }
        );
        say_success( $out, "Added new authorised values to those categories" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_value_categories(  category_name, is_system  ) VALUES
                ('NON_BIBLIOGRAPHIC_MATERIAL_TYPE', 1);
                }
        );
        say_success( $out, "Added new category 'NON_BIBLIOGRAPHIC_MATERIAL_TYPE'" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_values(  category, authorised_value, lib  ) VALUES
                ('NON_BIBLIOGRAPHIC_MATERIAL_TYPE', "EQUIPMENT", "Equipment"),
                ('NON_BIBLIOGRAPHIC_MATERIAL_TYPE', "SOFTWARE", "Software"),
                ('NON_BIBLIOGRAPHIC_MATERIAL_TYPE', "SERVICE", "Service"),
                ('NON_BIBLIOGRAPHIC_MATERIAL_TYPE', "OTHER", "Other");
                }
        );
        say_success( $out, "Added new authorised values to 'NON_BIBLIOGRAPHIC_MATERIAL_TYPE'" );

    },
};
