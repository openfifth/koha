use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "tbc",
    description => "Add accession and invoicing tables",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('acq_invoices') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_invoices` (
                `invoice_id` INT(11) NOT NULL AUTO_INCREMENT,
                `vendor_invoice_number` LONGTEXT NOT NULL COMMENT 'vendor-issued invoice number',
                `vendor_id` INT(11) NOT NULL COMMENT 'link to the vendor',
                `received_date` DATE DEFAULT NULL COMMENT 'date the invoice was received',
                `billed_date` DATE DEFAULT NULL COMMENT 'date the invoice was billed',
                `created_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() COMMENT 'creation date of the invoice',
                `modified_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'last update of the invoice',
                `closed_date` TIMESTAMP NULL DEFAULT NULL COMMENT 'date the invoice was closed',
                `status` TINYINT(1) NOT NULL COMMENT 'status of the invoice',
                `approved` TINYINT(1) DEFAULT NULL COMMENT 'has the invoice been approved',
                `approved_by` INT(11) DEFAULT NULL COMMENT 'borrower who approved the invoice',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the invoice',
                `invoice_total_amount` DECIMAL(28,6) DEFAULT NULL COMMENT 'total amount of the invoice',
                `payment_due` DATE DEFAULT NULL COMMENT 'date payment is due',
                `external_financial_system` TINYINT(1) DEFAULT NULL COMMENT 'is this managed by an external financial system',
                `external_invoice_number` MEDIUMTEXT DEFAULT NULL COMMENT 'invoice number in the external financial system',
                `external_accounting_id` MEDIUMTEXT DEFAULT NULL COMMENT 'accounting id in the external financial system',
                `exported_date` TIMESTAMP NULL DEFAULT NULL COMMENT 'date the invoice was exported to an external system',
                `edifact_message_id` INT(11) DEFAULT NULL COMMENT 'link to the edifact message',
                PRIMARY KEY (`invoice_id`),
                FOREIGN KEY (`vendor_id`) REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`approved_by`) REFERENCES `borrowers` (`borrowernumber`),
                FOREIGN KEY (`edifact_message_id`) REFERENCES `edifact_messages` (`id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_invoices'" );
        } else {
            say_info( $out, "Table 'acq_invoices' already exists" );
        }

        unless ( TableExists('acq_invoicelines') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_invoicelines` (
                `invoiceline_id` INT(11) NOT NULL AUTO_INCREMENT,
                `invoice_id` INT(11) NOT NULL COMMENT 'invoice the line belongs to',
                `quantity_invoiced` SMALLINT(6) NOT NULL COMMENT 'quantity invoiced on this line',
                `type` ENUM('orderline','adjustment') NOT NULL COMMENT 'type of invoice line',
                `adjustment_reason` VARCHAR(80) DEFAULT NULL COMMENT 'reason for adjustment',
                `adjustment_note` MEDIUMTEXT DEFAULT NULL COMMENT 'note for adjustment',
                `invoice_unitprice_oc` DECIMAL(28,6) NOT NULL COMMENT 'unit price in the order currency',
                `invoice_currency_oc` VARCHAR(10) NOT NULL COMMENT 'order currency code',
                `created_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() COMMENT 'creation date of the invoice line',
                `modified_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'last update of the invoice line',
                PRIMARY KEY (`invoiceline_id`),
                FOREIGN KEY (`invoice_id`) REFERENCES `acq_invoices` (`invoice_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_invoicelines'" );
        } else {
            say_info( $out, "Table 'acq_invoicelines' already exists" );
        }

        unless ( TableExists('acq_invoiceline_fund_distributions') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_invoiceline_fund_distributions` (
                `invoiceline_fund_distribution_id` INT(11) NOT NULL AUTO_INCREMENT,
                `invoiceline_id` INT(11) NOT NULL COMMENT 'invoice line the distribution was made against',
                `fund_id` INT(11) NOT NULL COMMENT 'fund the distribution was made against',
                `percentage` DECIMAL(5,2) DEFAULT NULL COMMENT 'distribution percentage',
                `distributed_amount_oc` DECIMAL(28,6) NOT NULL COMMENT 'distribution amount in the order currency',
                `exchange_rate` DECIMAL(20,10) NOT NULL COMMENT 'exchange rate for the distribution',
                `distributed_amount` DECIMAL(28,6) NOT NULL COMMENT 'distribution amount in the active currency',
                `distributed_amount_tax_excluded` DECIMAL(28,6) NOT NULL COMMENT 'distributed amount excluding tax',
                `distributed_amount_tax_included` DECIMAL(28,6) NOT NULL COMMENT 'distributed amount including tax',
                `tax_rate` DECIMAL(6,4) NOT NULL COMMENT 'tax rate applied',
                `tax_value` DECIMAL(28,6) NOT NULL COMMENT 'tax value',
                `distribution_reason` VARCHAR(80) DEFAULT NULL COMMENT 'reason for distribution',
                `distribution_note` MEDIUMTEXT DEFAULT NULL COMMENT 'note for distribution',
                `created_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() COMMENT 'creation date of the distribution',
                `modified_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'last update of the distribution',
                PRIMARY KEY (`invoiceline_fund_distribution_id`),
                FOREIGN KEY (`invoiceline_id`) REFERENCES `acq_invoicelines` (`invoiceline_id`) ON DELETE CASCADE,
                FOREIGN KEY (`fund_id`) REFERENCES `acq_funds` (`fund_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_invoiceline_fund_distributions'" );
        } else {
            say_info( $out, "Table 'acq_invoiceline_fund_distributions' already exists" );
        }

        unless ( TableExists('acq_accessions') ) {
            $dbh->do(
                q{
                CREATE TABLE `acq_accessions` (
                `accession_id` INT(11) NOT NULL AUTO_INCREMENT,
                `orderline_id` INT(11) DEFAULT NULL COMMENT 'order line the accession was made against',
                `invoiceline_id` INT(11) DEFAULT NULL COMMENT 'invoice line the accession was made against',
                `received_biblionumber` INT(11) DEFAULT NULL COMMENT 'bibliographic record received',
                `received_date` DATE DEFAULT NULL COMMENT 'date item was received',
                `quantity_received` SMALLINT(6) DEFAULT NULL COMMENT 'quantity received',
                `type` ENUM('INVOICE_AND_RECEIVE','INVOICE_ONLY','RECEIVE_ONLY','CANCELLATION') NOT NULL COMMENT 'type of accession event',
                `accession_description` LONGTEXT DEFAULT NULL COMMENT 'description of the accession',
                `cancellation_date` DATE DEFAULT NULL COMMENT 'date of cancellation',
                `cancellation_reason` MEDIUMTEXT DEFAULT NULL COMMENT 'reason for cancellation',
                `quantity_cancelled` SMALLINT(6) DEFAULT NULL COMMENT 'quantity cancelled',
                `created_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() COMMENT 'creation date of the accession',
                `modified_date` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'last update of the accession',
                PRIMARY KEY (`accession_id`),
                FOREIGN KEY (`orderline_id`) REFERENCES `acq_orderlines` (`orderline_id`) ON DELETE CASCADE,
                FOREIGN KEY (`invoiceline_id`) REFERENCES `acq_invoicelines` (`invoiceline_id`) ON DELETE CASCADE,
                FOREIGN KEY (`received_biblionumber`) REFERENCES `biblio` (`biblionumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'acq_accessions'" );
        } else {
            say_info( $out, "Table 'acq_accessions' already exists" );
        }

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_onetime_orderlines` AS (
                SELECT *
                FROM acq_orderlines
                JOIN (
                    SELECT ol.orderline_id AS calculated_attributes_orderline_id,
                           COALESCE(
                                   (SELECT SUM(il.quantity_invoiced)
                                    FROM acq_accessions a
                                    JOIN acq_invoicelines il ON il.invoiceline_id = a.invoiceline_id
                                    WHERE a.orderline_id = ol.orderline_id), 0
                           ) AS quantity_invoiced,
                           COALESCE(
                                   (SELECT quantity_cancelled
                                    FROM acq_accessions a
                                    WHERE a.orderline_id = ol.orderline_id
                                    AND a.`type` = 'CANCELLATION'), 0
                           ) AS quantity_cancelled,
                           ol.quantity_ordered -
                           COALESCE(
                                   (SELECT SUM(il.quantity_invoiced)
                                    FROM acq_accessions a
                                    JOIN acq_invoicelines il ON il.invoiceline_id = a.invoiceline_id
                                    WHERE a.orderline_id = ol.orderline_id), 0
                           ) -
                           COALESCE((
                                        SELECT quantity_cancelled
                                        FROM acq_accessions a
                                        WHERE a.orderline_id = ol.orderline_id
                                          AND a.`type` = 'CANCELLATION'), 0)
                             AS quantity_open
                    FROM acq_orderlines ol
                ) calculated_attributes ON acq_orderlines.orderline_id = calculated_attributes.calculated_attributes_orderline_id
                WHERE acq_orderlines.is_continuous = 0
            )
        }
        );
        say_success( $out, "Created view 'acq_onetime_orderlines'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_open_onetime_orderlines` AS (
                SELECT *
                FROM acq_onetime_orderlines ool
                WHERE ool.`status` IN ('ORDERED', 'PARTIAL')
                AND ool.quantity_open > 0
            )
        }
        );
        say_success( $out, "Created view 'acq_open_onetime_orderlines'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_open_onetime_orderline_distributions` AS (
                SELECT *
                FROM acq_orderline_fund_distributions
                JOIN (SELECT ofd.orderline_fund_distribution_id AS additional_attributes_orderline_fund_distribution_id,
                             ooo.quantity_open,
                             ooo.status AS orderline_status,
                             CASE
                                 WHEN (SELECT VALUE FROM systempreferences WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                                     THEN ofd.distributed_amount_tax_excluded
                                 ELSE ofd.distributed_amount_tax_included
                                 END AS price,
                             CASE
                                 WHEN (SELECT VALUE FROM systempreferences WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                                     THEN ofd.distributed_amount_tax_excluded
                                 ELSE ofd.distributed_amount_tax_included
                                 END / ooo.quantity_ordered AS price_per_unit,
                             CASE
                                 WHEN (SELECT VALUE FROM systempreferences WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                                     THEN ofd.distributed_amount_tax_excluded
                                 ELSE ofd.distributed_amount_tax_included
                                 END / ooo.quantity_ordered * ooo.quantity_open AS amount_open
                      FROM acq_open_onetime_orderlines ooo
                      JOIN acq_orderline_fund_distributions ofd ON ooo.orderline_id = ofd.orderline_id
                    ) additional_attributes ON acq_orderline_fund_distributions.orderline_fund_distribution_id
                        = additional_attributes.additional_attributes_orderline_fund_distribution_id
            )
        }
        );
        say_success( $out, "Created view 'acq_open_onetime_orderline_distributions'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_continuous_orderlines` AS (
                SELECT *
                FROM acq_orderlines
                WHERE is_continuous = 1
            )
        }
        );
        say_success( $out, "Created view 'acq_continuous_orderlines'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_open_continuous_orderlines` AS (
                SELECT *
                FROM acq_orderlines ol
                WHERE ol.is_continuous = 1
                AND ol.`status` IN ('ORDERED', 'CONTINUING')
            )
        }
        );
        say_success( $out, "Created view 'acq_open_continuous_orderlines'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_open_continuous_orderline_distributions` AS (
                SELECT *
                FROM acq_orderline_fund_distributions
                JOIN (SELECT
                           ofd.orderline_fund_distribution_id AS additional_attributes_orderline_fund_distribution_id,
                           CASE
                               WHEN (SELECT VALUE
                                     FROM systempreferences
                                     WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                               THEN ofd.distributed_amount_tax_excluded
                               ELSE ofd.distributed_amount_tax_included
                           END AS distributed_ordered_amount
                      FROM acq_open_continuous_orderlines oco
                      JOIN acq_orderline_fund_distributions ofd ON oco.orderline_id = ofd.orderline_id
                  ) additional_attributes ON acq_orderline_fund_distributions.orderline_fund_distribution_id
                      = additional_attributes.additional_attributes_orderline_fund_distribution_id
            )
        }
        );
        say_success( $out, "Created view 'acq_open_continuous_orderline_distributions'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_spent_invoiceline_distributions` AS (
                SELECT ifd.invoiceline_fund_distribution_id,
                       ifd.percentage,
                       CASE WHEN (SELECT VALUE FROM systempreferences WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                           THEN ifd.distributed_amount_tax_excluded
                           ELSE ifd.distributed_amount_tax_included
                       END AS price,
                       CASE WHEN (SELECT VALUE FROM systempreferences WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                           THEN ifd.distributed_amount_tax_excluded
                           ELSE ifd.distributed_amount_tax_included
                       END / il.quantity_invoiced AS unit_price,
                       il.quantity_invoiced,
                       ifd.fund_id,
                       il.type,
                       i.status AS invoice_status
                FROM acq_invoiceline_fund_distributions ifd
                JOIN acq_invoicelines il ON il.invoiceline_id = ifd.invoiceline_id
                JOIN acq_invoices i ON il.invoice_id = i.invoice_id
            )
        }
        );
        say_success( $out, "Created view 'acq_spent_invoiceline_distributions'" );

        $dbh->do(
            q{
            CREATE OR REPLACE VIEW `acq_fund_summary` AS
            SELECT
                f.fund_id,
                fp.`name`          AS period,
                l.`name`           AS ledger,
                f.`code`,
                f.`name`,
                f.owner_id         AS owner,
                f.managing_branch,
                f.fund_amount,
                COALESCE(orders_status_new.orders_status_new, 0) AS orders_status_new,
                COALESCE(ordered.ordered,                    0) AS ordered,
                COALESCE(spent.spent,                        0) AS spent
            FROM acq_funds f
            JOIN acq_ledgers l           ON l.ledger_id        = f.ledger_id
            JOIN acq_fiscal_periods fp   ON fp.fiscal_period_id = l.fiscal_period_id

            LEFT JOIN (
                SELECT fund_id, SUM(amount_open) AS ordered
                FROM (
                    SELECT orderline_id, amount_open, fund_id
                    FROM   acq_open_onetime_orderline_distributions
                    UNION ALL
                    SELECT orderline_id, distributed_ordered_amount AS amount_open, fund_id
                    FROM   acq_open_continuous_orderline_distributions
                ) ofd
                GROUP BY fund_id
            ) ordered ON f.fund_id = ordered.fund_id

            LEFT JOIN (
                SELECT fund_id,
                       SUM(CASE
                           WHEN (SELECT VALUE FROM systempreferences WHERE variable = 'CalculateFundValuesIncludingTax') = 0
                           THEN ofd.distributed_amount_tax_excluded
                           ELSE ofd.distributed_amount_tax_included
                       END) AS orders_status_new
                FROM (
                    SELECT ool.orderline_id,
                           ofd.distributed_amount_tax_included / ool.quantity_ordered * ool.quantity_open AS distributed_amount_tax_included,
                           ofd.distributed_amount_tax_excluded / ool.quantity_ordered * ool.quantity_open AS distributed_amount_tax_excluded,
                           ofd.fund_id
                    FROM   acq_onetime_orderlines ool
                    JOIN   acq_orderline_fund_distributions ofd ON ool.orderline_id = ofd.orderline_id
                    WHERE  ool.status = 'NEW'
                    UNION ALL
                    SELECT ocol.orderline_id,
                           ofd.distributed_amount_tax_included,
                           ofd.distributed_amount_tax_excluded,
                           ofd.fund_id
                    FROM   acq_continuous_orderlines ocol
                    JOIN   acq_orderline_fund_distributions ofd ON ocol.orderline_id = ofd.orderline_id
                    WHERE  ocol.status = 'NEW'
                ) ofd
                GROUP BY fund_id
            ) orders_status_new ON f.fund_id = orders_status_new.fund_id

            LEFT JOIN (
                SELECT fund_id, SUM(price) AS spent
                FROM   acq_spent_invoiceline_distributions
                GROUP BY fund_id
            ) spent ON f.fund_id = spent.fund_id

            WHERE l.`status` = 1
        }
        );
        say_success( $out, "Created view 'acq_fund_summary'" );
    },
};
