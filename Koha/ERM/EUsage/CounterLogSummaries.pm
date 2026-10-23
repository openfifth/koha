package Koha::ERM::EUsage::CounterLogSummaries;

# Copyright 2026 Open Fifth

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use C4::Context;
use Koha::Database;

use Koha::ERM::EUsage::CounterLogSummary;

use base qw(Koha::Objects);

=head1 NAME

Koha::ERM::EUsage::CounterLogSummaries - Koha ErmCounterLogSummary Object set class

=head1 API

=head2 Class Methods

=cut

=head3 rebuild

    my $rows = Koha::ERM::EUsage::CounterLogSummaries->rebuild(
        { usage_data_provider_id => $id, report_type => 'TR_J1', report_year => 2026 }
    );

Rebuilds the erm_counter_log_summary rows from the counter logs and returns the number
of rows written. erm_counter_log_summary is a derived table: a row holds the status of
the newest counter log of each month (by importdate, then id) of one usage data
provider, report type and year. Counter logs without a provider, report type, year or
month are not summarised.

C<usage_data_provider_id>, C<report_type> and C<report_year> are optional filters. A
key that is given limits the rebuild to the matching rows. Without any key the whole
table is rebuilt.

Koha::ERM::EUsage::CounterLog calls it when a counter log is stored or deleted. Call it
after any other write to erm_counter_logs.

=cut

sub rebuild {
    my ( $class, $params ) = @_;
    $params //= {};

    my @keys   = grep { exists $params->{$_} } qw( usage_data_provider_id report_type report_year );
    my @values = @{$params}{@keys};
    my $delete = @keys ? 'WHERE ' . join( ' AND ', map { "`$_` <=> ?" } @keys ) : q{};
    my $filter = join q{}, map { "\n                          AND `$_` <=> ?" } @keys;

    my $schema = Koha::Database->new->schema;
    my $dbh    = C4::Context->dbh;

    return $schema->txn_do(
        sub {

            # Several jobs of one provider can write counter logs at the same time, wait for the others to finish
            if ( defined $params->{usage_data_provider_id} ) {
                $dbh->do(
                    q{
                        SELECT erm_usage_data_provider_id
                        FROM erm_usage_data_providers
                        WHERE erm_usage_data_provider_id = ?
                        FOR UPDATE
                    },
                    undef, $params->{usage_data_provider_id}
                );
            }

            $dbh->do( qq{DELETE FROM `erm_counter_log_summary` $delete}, undef, @values );

            my $rows = $dbh->do(
                qq{
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
                          AND `report_month` IS NOT NULL$filter
                    ) `latest`
                    WHERE `latest`.`rn` = 1
                    GROUP BY
                        `latest`.`usage_data_provider_id`,
                        `latest`.`report_type`,
                        `latest`.`report_year`
                }, undef, @values
            );

            return $rows + 0;
        }
    );
}

=head3 _type

=cut

sub _type {
    return 'ErmCounterLogSummary';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ERM::EUsage::CounterLogSummary';
}

1;
