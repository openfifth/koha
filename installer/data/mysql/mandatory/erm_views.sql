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

--
-- View structure for view `erm_counter_log_summary`
--
-- One row per usage data provider, report type and harvest year, with the status
-- of the latest counter log for each month. Logs without a single-month period
-- (multi-month harvests, uploads over several months) are not included.
--

DROP VIEW IF EXISTS `erm_counter_log_summary`;
CREATE OR REPLACE VIEW `erm_counter_log_summary` AS
SELECT
    MIN(`latest`.`erm_counter_log_id`) AS `erm_counter_log_summary_id`,
    `latest`.`usage_data_provider_id`,
    `providers`.`name`                 AS `provider_name`,
    `latest`.`report_type`,
    `latest`.`report_year`,
    MAX(CASE WHEN `latest`.`report_month` = 1  THEN `latest`.`status` END) AS `month_1`,
    MAX(CASE WHEN `latest`.`report_month` = 2  THEN `latest`.`status` END) AS `month_2`,
    MAX(CASE WHEN `latest`.`report_month` = 3  THEN `latest`.`status` END) AS `month_3`,
    MAX(CASE WHEN `latest`.`report_month` = 4  THEN `latest`.`status` END) AS `month_4`,
    MAX(CASE WHEN `latest`.`report_month` = 5  THEN `latest`.`status` END) AS `month_5`,
    MAX(CASE WHEN `latest`.`report_month` = 6  THEN `latest`.`status` END) AS `month_6`,
    MAX(CASE WHEN `latest`.`report_month` = 7  THEN `latest`.`status` END) AS `month_7`,
    MAX(CASE WHEN `latest`.`report_month` = 8  THEN `latest`.`status` END) AS `month_8`,
    MAX(CASE WHEN `latest`.`report_month` = 9  THEN `latest`.`status` END) AS `month_9`,
    MAX(CASE WHEN `latest`.`report_month` = 10 THEN `latest`.`status` END) AS `month_10`,
    MAX(CASE WHEN `latest`.`report_month` = 11 THEN `latest`.`status` END) AS `month_11`,
    MAX(CASE WHEN `latest`.`report_month` = 12 THEN `latest`.`status` END) AS `month_12`
FROM (
    SELECT
        `erm_counter_log_id`,
        `usage_data_provider_id`,
        `report_type`,
        `report_year`,
        `report_month`,
        `status`,
        ROW_NUMBER() OVER (
            PARTITION BY `usage_data_provider_id`, `report_type`, `report_year`, `report_month`
            ORDER BY `importdate` DESC, `erm_counter_log_id` DESC
        ) AS `rn`
    FROM `erm_counter_logs`
    WHERE `report_year` IS NOT NULL
      AND `report_month` IS NOT NULL
      AND `report_type` IS NOT NULL
) `latest`
JOIN `erm_usage_data_providers` `providers`
    ON `providers`.`erm_usage_data_provider_id` = `latest`.`usage_data_provider_id`
WHERE `latest`.`rn` = 1
GROUP BY
    `latest`.`usage_data_provider_id`,
    `providers`.`name`,
    `latest`.`report_type`,
    `latest`.`report_year`;
