use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "42088",
    description => "Add status, background_job_id, report_type, report_year and report_month to erm_counter_logs",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'erm_counter_logs', 'background_job_id' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD COLUMN background_job_id int(11) DEFAULT NULL COMMENT 'foreign key to background_jobs' AFTER usage_data_provider_id}
            );

            say_success( $out, "Added column 'erm_counter_logs.background_job_id'" );
        }
        unless ( index_exists( 'erm_counter_logs', 'erm_counter_log_ibfk_4' ) ) {
            $dbh->do(q{ALTER TABLE erm_counter_logs ADD KEY erm_counter_log_ibfk_4 (background_job_id)});

            say_success( $out, "Added index 'erm_counter_logs.erm_counter_log_ibfk_4'" );
        }
        unless ( foreign_key_exists( 'erm_counter_logs', 'erm_counter_log_ibfk_4' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD CONSTRAINT erm_counter_log_ibfk_4 FOREIGN KEY (background_job_id) REFERENCES background_jobs (id) ON DELETE SET NULL ON UPDATE CASCADE}
            );

            say_success( $out, "Added foreign key 'erm_counter_logs.erm_counter_log_ibfk_4'" );
        }
        unless ( column_exists( 'erm_counter_logs', 'report_type' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD COLUMN report_type varchar(10) DEFAULT NULL COMMENT 'report type' AFTER logdetails}
            );

            say_success( $out, "Added column 'erm_counter_logs.report_type'" );
        }
        unless ( column_exists( 'erm_counter_logs', 'report_year' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD COLUMN report_year int(4) DEFAULT NULL COMMENT 'year of the harvested report period' AFTER report_type}
            );

            say_success( $out, "Added column 'erm_counter_logs.report_year'" );
        }
        unless ( column_exists( 'erm_counter_logs', 'report_month' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD COLUMN report_month int(2) DEFAULT NULL COMMENT 'month of the harvested report period' AFTER report_year}
            );

            say_success( $out, "Added column 'erm_counter_logs.report_month'" );
        }
        unless ( column_exists( 'erm_counter_logs', 'status' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD COLUMN status varchar(16) NOT NULL DEFAULT 'success' COMMENT 'outcome of the harvest or import: success, no_data, retry, error' AFTER report_month}
            );

            say_success( $out, "Added column 'erm_counter_logs.status'" );
        }
        unless ( index_exists( 'erm_counter_logs', 'erm_counter_log_status_idx' ) ) {
            $dbh->do(q{ALTER TABLE erm_counter_logs ADD KEY erm_counter_log_status_idx (status)});

            say_success( $out, "Added index 'erm_counter_logs.erm_counter_log_status_idx'" );
        }
        unless ( index_exists( 'erm_counter_logs', 'erm_counter_log_period_idx' ) ) {
            $dbh->do(
                q{ALTER TABLE erm_counter_logs ADD KEY erm_counter_log_period_idx (usage_data_provider_id, report_type, report_year, report_month)}
            );

            say_success( $out, "Added index 'erm_counter_logs.erm_counter_log_period_idx'" );
        }

        # The view is created on every run: CREATE OR REPLACE keeps it in step with erm_views.sql
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
