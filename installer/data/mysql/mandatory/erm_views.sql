--
-- ERM views
--
-- These views depend on tables created by kohastructure.sql, so this file is
-- loaded after it by C4::Installer::load_sql_in_order. On upgrade the views are
-- created by the matching database revision.
--

--
-- View structure for view `erm_usage_yus`
--
-- Yearly usage is derived from the monthly usage in `erm_usage_mus`.
--

DROP VIEW IF EXISTS `erm_usage_yus`;
CREATE OR REPLACE VIEW `erm_usage_yus` AS
SELECT
    MIN(`monthly_usage_summary_id`)    AS `yearly_usage_summary_id`,
    `title_id`,
    `platform_id`,
    `database_id`,
    `item_id`,
    `usage_data_provider_id`,
    `year`,
    CAST(SUM(`usage_count`) AS SIGNED) AS `totalcount`,
    `metric_type`,
    `access_type`,
    `yop`,
    `report_type`
FROM `erm_usage_mus`
GROUP BY
    `title_id`,
    `platform_id`,
    `database_id`,
    `item_id`,
    `usage_data_provider_id`,
    `year`,
    `metric_type`,
    `access_type`,
    `yop`,
    `report_type`;
