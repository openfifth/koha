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
