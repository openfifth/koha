use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "41307",
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
                q{ALTER TABLE erm_counter_logs ADD COLUMN status varchar(16) NOT NULL DEFAULT 'success' COMMENT 'outcome of the harvest or import: success, no_usage, no_data, retry, error' AFTER report_month}
            );

            say_success( $out, "Added column 'erm_counter_logs.status'" );
        }
        unless ( index_exists( 'erm_counter_logs', 'erm_counter_log_status_idx' ) ) {
            $dbh->do(q{ALTER TABLE erm_counter_logs ADD KEY erm_counter_log_status_idx (status)});

            say_success( $out, "Added index 'erm_counter_logs.erm_counter_log_status_idx'" );
        }
    },
};
