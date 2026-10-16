use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "42218",
    description => "Replace erm_usage_yus table with a view computed from erm_usage_mus",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # TableExists cannot tell a table from a view, so ask information_schema
        my ($table_type) = $dbh->selectrow_array(
            q{
                SELECT TABLE_TYPE
                FROM information_schema.TABLES
                WHERE TABLE_SCHEMA = schema()
                  AND TABLE_NAME = 'erm_usage_yus'
            }
        );

        if ( $table_type && $table_type eq 'BASE TABLE' ) {
            $dbh->do(q{ DROP TABLE `erm_usage_yus` });
            say_success( $out, "Dropped table 'erm_usage_yus'" );
        }

        $dbh->do(
            q{
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
                    `report_type`
            }
        );
        say_success( $out, "Created view 'erm_usage_yus'" );
    },
};
