-- All one-time orderlines
-- Shows all orderline attributes plus quantity_invoiced, quantity_cancelled and quantity_open.
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
);

-- All OPEN one-time orderlines.
-- In the acquisitions module one-time orders are open if status is ordered or partial.
CREATE OR REPLACE VIEW `acq_open_onetime_orderlines` AS (
    SELECT *
    FROM acq_onetime_orderlines ool
    WHERE ool.`status` IN ('ORDERED', 'PARTIAL')
    AND ool.quantity_open > 0
);

-- Shows all acq_orderline_fund_distributions attributes plus the additional attributes for open one-time orderlines.
-- Calculates price_per_unit (distributed_amount / quantity_ordered) and amount_open
-- based on the CalculateFundValuesIncludingTax system preference.
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
);

-- All continuous orderlines
CREATE OR REPLACE VIEW `acq_continuous_orderlines` AS (
    SELECT *
    FROM acq_orderlines
    WHERE is_continuous = 1
);

-- All open continuous orderlines
CREATE OR REPLACE VIEW `acq_open_continuous_orderlines` AS (
    SELECT *
    FROM acq_orderlines ol
    WHERE ol.is_continuous = 1
    AND ol.`status` IN ('ORDERED', 'CONTINUING')
);

-- Shows all acq_orderline_fund_distributions attributes plus the distributed_ordered_amount
-- for open continuous orderlines, based on the CalculateFundValuesIncludingTax system preference.
-- Note: amounts from invoice_adjustments with active "encumber while open" checkbox are not included.
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
);

-- Shows all invoiceline fund distributions with calculated price and unit_price
-- based on the CalculateFundValuesIncludingTax system preference.
-- Note: adjustments are included, see the type attribute.
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
);

-- Per-fund financial summary: fund amount, estimated (NEW orders), ordered (open), spent (invoiced)
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

WHERE l.`status` = 1;
