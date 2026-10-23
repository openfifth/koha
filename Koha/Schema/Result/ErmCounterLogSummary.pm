use utf8;

package Koha::Schema::Result::ErmCounterLogSummary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmCounterLogSummary - VIEW

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<erm_counter_log_summary>

=cut

__PACKAGE__->table("erm_counter_log_summary");
__PACKAGE__->result_source_instance->view_definition(
    "select min(`latest`.`erm_counter_log_id`) AS `erm_counter_log_summary_id`,`latest`.`usage_data_provider_id` AS `usage_data_provider_id`,`providers`.`name` AS `provider_name`,`latest`.`report_type` AS `report_type`,`latest`.`report_year` AS `report_year`,max(case when `latest`.`report_month` = 1 then `latest`.`status` end) AS `month_1`,max(case when `latest`.`report_month` = 2 then `latest`.`status` end) AS `month_2`,max(case when `latest`.`report_month` = 3 then `latest`.`status` end) AS `month_3`,max(case when `latest`.`report_month` = 4 then `latest`.`status` end) AS `month_4`,max(case when `latest`.`report_month` = 5 then `latest`.`status` end) AS `month_5`,max(case when `latest`.`report_month` = 6 then `latest`.`status` end) AS `month_6`,max(case when `latest`.`report_month` = 7 then `latest`.`status` end) AS `month_7`,max(case when `latest`.`report_month` = 8 then `latest`.`status` end) AS `month_8`,max(case when `latest`.`report_month` = 9 then `latest`.`status` end) AS `month_9`,max(case when `latest`.`report_month` = 10 then `latest`.`status` end) AS `month_10`,max(case when `latest`.`report_month` = 11 then `latest`.`status` end) AS `month_11`,max(case when `latest`.`report_month` = 12 then `latest`.`status` end) AS `month_12` from ((select `dbic`.`erm_counter_logs`.`erm_counter_log_id` AS `erm_counter_log_id`,`dbic`.`erm_counter_logs`.`usage_data_provider_id` AS `usage_data_provider_id`,`dbic`.`erm_counter_logs`.`report_type` AS `report_type`,`dbic`.`erm_counter_logs`.`report_year` AS `report_year`,`dbic`.`erm_counter_logs`.`report_month` AS `report_month`,`dbic`.`erm_counter_logs`.`status` AS `status`,row_number() over ( partition by `dbic`.`erm_counter_logs`.`usage_data_provider_id`,`dbic`.`erm_counter_logs`.`report_type`,`dbic`.`erm_counter_logs`.`report_year`,`dbic`.`erm_counter_logs`.`report_month` order by `dbic`.`erm_counter_logs`.`importdate` desc,`dbic`.`erm_counter_logs`.`erm_counter_log_id` desc) AS `rn` from `dbic`.`erm_counter_logs` where `dbic`.`erm_counter_logs`.`report_year` is not null and `dbic`.`erm_counter_logs`.`report_month` is not null and `dbic`.`erm_counter_logs`.`report_type` is not null) `latest` join `dbic`.`erm_usage_data_providers` `providers` on(`providers`.`erm_usage_data_provider_id` = `latest`.`usage_data_provider_id`)) where `latest`.`rn` = 1 group by `latest`.`usage_data_provider_id`,`providers`.`name`,`latest`.`report_type`,`latest`.`report_year`"
);

=head1 ACCESSORS

=head2 erm_counter_log_summary_id

  data_type: 'integer'
  is_nullable: 1

primary key

=head2 usage_data_provider_id

  data_type: 'integer'
  is_nullable: 1

foreign key to erm_usage_data_providers

=head2 provider_name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

name of the data provider

=head2 report_type

  data_type: 'varchar'
  is_nullable: 1
  size: 10

report type

=head2 report_year

  data_type: 'integer'
  is_nullable: 1

year of the harvested report period

=head2 month_1

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_2

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_3

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_4

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_5

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_6

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_7

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_8

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_9

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_10

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_11

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 month_12

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=cut

__PACKAGE__->add_columns(
    "erm_counter_log_summary_id",
    { data_type => "integer", is_nullable => 1 },
    "usage_data_provider_id",
    { data_type => "integer", is_nullable => 1 },
    "provider_name",
    { data_type => "varchar", is_nullable => 0, size => 80 },
    "report_type",
    { data_type => "varchar", is_nullable => 1, size => 10 },
    "report_year",
    { data_type => "integer", is_nullable => 1 },
    "month_1",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_2",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_3",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_4",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_5",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_6",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_7",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_8",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_9",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_10",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_11",
    { data_type => "varchar", is_nullable => 1, size => 16 },
    "month_12",
    { data_type => "varchar", is_nullable => 1, size => 16 },
);

# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-10-23 10:08:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+8lQ6biByCv3/WVqm+Sb9A

# erm_counter_log_summary is a view over erm_counter_logs, so the schema loader
# generates neither a primary key nor relationships. They are defined here by hand.
# MIN(erm_counter_log_id) is never NULL, so the key can be non-nullable.

__PACKAGE__->add_columns( '+erm_counter_log_summary_id' => { is_nullable => 0 } );

__PACKAGE__->set_primary_key("erm_counter_log_summary_id");

__PACKAGE__->belongs_to(
    "usage_data_provider",
    "Koha::Schema::Result::ErmUsageDataProvider",
    { erm_usage_data_provider_id => "usage_data_provider_id" },
    { join_type                  => "LEFT" },
);

=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::ERM::EUsage::CounterLogSummary';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ERM::EUsage::CounterLogSummaries';
}

1;
