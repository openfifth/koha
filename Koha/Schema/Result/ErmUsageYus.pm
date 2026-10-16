use utf8;
package Koha::Schema::Result::ErmUsageYus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmUsageYus - VIEW

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<erm_usage_yus>

=cut

__PACKAGE__->table("erm_usage_yus");
__PACKAGE__->result_source_instance->view_definition("select min(`dbic`.`erm_usage_mus`.`monthly_usage_summary_id`) AS `yearly_usage_summary_id`,`dbic`.`erm_usage_mus`.`title_id` AS `title_id`,`dbic`.`erm_usage_mus`.`platform_id` AS `platform_id`,`dbic`.`erm_usage_mus`.`database_id` AS `database_id`,`dbic`.`erm_usage_mus`.`item_id` AS `item_id`,`dbic`.`erm_usage_mus`.`usage_data_provider_id` AS `usage_data_provider_id`,`dbic`.`erm_usage_mus`.`year` AS `year`,cast(sum(`dbic`.`erm_usage_mus`.`usage_count`) as signed) AS `totalcount`,`dbic`.`erm_usage_mus`.`metric_type` AS `metric_type`,`dbic`.`erm_usage_mus`.`access_type` AS `access_type`,`dbic`.`erm_usage_mus`.`yop` AS `yop`,`dbic`.`erm_usage_mus`.`report_type` AS `report_type` from `dbic`.`erm_usage_mus` group by `dbic`.`erm_usage_mus`.`title_id`,`dbic`.`erm_usage_mus`.`platform_id`,`dbic`.`erm_usage_mus`.`database_id`,`dbic`.`erm_usage_mus`.`item_id`,`dbic`.`erm_usage_mus`.`usage_data_provider_id`,`dbic`.`erm_usage_mus`.`year`,`dbic`.`erm_usage_mus`.`metric_type`,`dbic`.`erm_usage_mus`.`access_type`,`dbic`.`erm_usage_mus`.`yop`,`dbic`.`erm_usage_mus`.`report_type`");

=head1 ACCESSORS

=head2 yearly_usage_summary_id

  data_type: 'integer'
  is_nullable: 1

primary key

=head2 title_id

  data_type: 'integer'
  is_nullable: 1

item title id number

=head2 platform_id

  data_type: 'integer'
  is_nullable: 1

platform id number

=head2 database_id

  data_type: 'integer'
  is_nullable: 1

database id number

=head2 item_id

  data_type: 'integer'
  is_nullable: 1

item id number

=head2 usage_data_provider_id

  data_type: 'integer'
  is_nullable: 1

item title id number

=head2 year

  data_type: 'integer'
  is_nullable: 1

year of usage statistics

=head2 totalcount

  data_type: 'bigint'
  is_nullable: 1

=head2 metric_type

  data_type: 'varchar'
  is_nullable: 1
  size: 50

metric type for the usage statistic

=head2 access_type

  data_type: 'varchar'
  is_nullable: 1
  size: 50

access type for the usage statistic

=head2 yop

  data_type: 'varchar'
  is_nullable: 1
  size: 255

year of publication for the usage statistic

=head2 report_type

  data_type: 'varchar'
  is_nullable: 1
  size: 50

report type for the usage statistic

=cut

__PACKAGE__->add_columns(
  "yearly_usage_summary_id",
  { data_type => "integer", is_nullable => 1 },
  "title_id",
  { data_type => "integer", is_nullable => 1 },
  "platform_id",
  { data_type => "integer", is_nullable => 1 },
  "database_id",
  { data_type => "integer", is_nullable => 1 },
  "item_id",
  { data_type => "integer", is_nullable => 1 },
  "usage_data_provider_id",
  { data_type => "integer", is_nullable => 1 },
  "year",
  { data_type => "integer", is_nullable => 1 },
  "totalcount",
  { data_type => "bigint", is_nullable => 1 },
  "metric_type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "access_type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "yop",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "report_type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-10-14 15:22:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RxXN0Gt/wxGCwtv7TQk3gg

# erm_usage_yus is a view over erm_usage_mus, so the schema loader generates
# neither a primary key nor relationships. They are defined here by hand.
# MIN(monthly_usage_summary_id) is never NULL, so the key can be non-nullable.

__PACKAGE__->add_columns( '+yearly_usage_summary_id' => { is_nullable => 0 } );

__PACKAGE__->set_primary_key("yearly_usage_summary_id");

__PACKAGE__->belongs_to(
    "database",
    "Koha::Schema::Result::ErmUsageDatabase",
    { database_id => "database_id" },
    { join_type   => "LEFT" },
);

__PACKAGE__->belongs_to(
    "item",
    "Koha::Schema::Result::ErmUsageItem",
    { item_id   => "item_id" },
    { join_type => "LEFT" },
);

__PACKAGE__->belongs_to(
    "platform",
    "Koha::Schema::Result::ErmUsagePlatform",
    { platform_id => "platform_id" },
    { join_type   => "LEFT" },
);

__PACKAGE__->belongs_to(
    "title",
    "Koha::Schema::Result::ErmUsageTitle",
    { title_id  => "title_id" },
    { join_type => "LEFT" },
);

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
    'Koha::ERM::EUsage::YearlyUsage';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ERM::EUsage::YearlyUsages';
}

1;
