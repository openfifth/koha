use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "38822",
    description => "Add a period index to erm_counter_logs and the erm_counter_log_summary table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # updatedatabase runs the atomicupdate files in name order, so this file
        # runs before bug_41307.pl, which adds the columns the index and the summary
        # read. They are added here too, under the same guards, so either order
        # works: the file that runs second skips them.
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
                q{ALTER TABLE erm_counter_logs ADD COLUMN status varchar(16) NOT NULL DEFAULT 'success' COMMENT 'outcome of the harvest or import: success, no_usage, no_data, retry, error' AFTER report_month}
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

        # A development database can hold the view of an earlier version of this patch
        my ($table_type) = $dbh->selectrow_array(
            q{
                SELECT TABLE_TYPE
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = schema()
                  AND TABLE_NAME = 'erm_counter_log_summary'
            }
        );

        if ( $table_type && $table_type eq 'VIEW' ) {
            $dbh->do(q{ DROP VIEW `erm_counter_log_summary` });
            say_success( $out, "Dropped view 'erm_counter_log_summary'" );
            $table_type = undef;
        }

        unless ($table_type) {
            $dbh->do(
                q{
                    CREATE TABLE `erm_counter_log_summary` (
                      `erm_counter_log_summary_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                      `usage_data_provider_id` int(11) NOT NULL COMMENT 'foreign key to erm_usage_data_providers',
                      `report_type` varchar(10) NOT NULL COMMENT 'report type of the harvests',
                      `report_year` int(4) NOT NULL COMMENT 'year of the harvested months',
                      `month_1` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for January',
                      `month_2` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for February',
                      `month_3` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for March',
                      `month_4` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for April',
                      `month_5` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for May',
                      `month_6` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for June',
                      `month_7` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for July',
                      `month_8` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for August',
                      `month_9` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for September',
                      `month_10` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for October',
                      `month_11` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for November',
                      `month_12` varchar(16) DEFAULT NULL COMMENT 'status of the latest harvest log for December',
                      PRIMARY KEY (`erm_counter_log_summary_id`),
                      UNIQUE KEY `erm_counter_log_summary_period_idx` (`usage_data_provider_id`,`report_type`,`report_year`),
                      CONSTRAINT `erm_counter_log_summary_ibfk_1` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                }
            );
            say_success( $out, "Created table 'erm_counter_log_summary'" );

            # The newest log of each month, pivoted into month_1 to month_12
            $dbh->do(
                q{
                    INSERT INTO `erm_counter_log_summary` (
                        `usage_data_provider_id`, `report_type`, `report_year`,
                        `month_1`, `month_2`, `month_3`, `month_4`, `month_5`, `month_6`, `month_7`, `month_8`, `month_9`, `month_10`, `month_11`, `month_12`
                    )
                    SELECT
                        `latest`.`usage_data_provider_id`,
                        `latest`.`report_type`,
                        `latest`.`report_year`,
                        MAX(CASE WHEN `latest`.`report_month` = 1 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 2 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 3 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 4 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 5 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 6 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 7 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 8 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 9 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 10 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 11 THEN `latest`.`status` END),
                        MAX(CASE WHEN `latest`.`report_month` = 12 THEN `latest`.`status` END)
                    FROM (
                        SELECT
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
                        WHERE `usage_data_provider_id` IS NOT NULL
                          AND `report_type` IS NOT NULL
                          AND `report_year` IS NOT NULL
                          AND `report_month` IS NOT NULL
                    ) `latest`
                    WHERE `latest`.`rn` = 1
                    GROUP BY
                        `latest`.`usage_data_provider_id`,
                        `latest`.`report_type`,
                        `latest`.`report_year`
                }
            );
            say_success( $out, "Filled 'erm_counter_log_summary' from 'erm_counter_logs'" );
        }
    },
};
