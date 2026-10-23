use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "38822",
    description => "Add a period index and the erm_counter_log_summary view for the counter logs",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( index_exists( 'erm_counter_logs', 'erm_counter_log_period_idx' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD KEY erm_counter_log_period_idx (usage_data_provider_id, report_type, report_year, report_month)}
            );

            say_success( $out, "Added index 'erm_counter_logs.erm_counter_log_period_idx'" );
        }

        # The view is created on every run: CREATE OR REPLACE keeps it in step with kohastructure.sql
        $dbh->do(
            q{
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
                    `latest`.`report_year`
            }
        );
        say_success( $out, "Created view 'erm_counter_log_summary'" );
    },
};
