use utf8;
package Koha::Schema::Result::ErmCounterLogSummary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmCounterLogSummary

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<erm_counter_log_summary>

=cut

__PACKAGE__->table("erm_counter_log_summary");

=head1 ACCESSORS

=head2 erm_counter_log_summary_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 usage_data_provider_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key to erm_usage_data_providers

=head2 report_type

  data_type: 'varchar'
  is_nullable: 0
  size: 10

report type of the harvests

=head2 report_year

  data_type: 'integer'
  is_nullable: 0

year of the harvested months

=head2 month_1

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for January

=head2 month_2

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for February

=head2 month_3

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for March

=head2 month_4

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for April

=head2 month_5

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for May

=head2 month_6

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for June

=head2 month_7

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for July

=head2 month_8

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for August

=head2 month_9

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for September

=head2 month_10

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for October

=head2 month_11

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for November

=head2 month_12

  data_type: 'varchar'
  is_nullable: 1
  size: 16

status of the latest harvest log for December

=cut

__PACKAGE__->add_columns(
  "erm_counter_log_summary_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "usage_data_provider_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "report_type",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "report_year",
  { data_type => "integer", is_nullable => 0 },
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

=head1 PRIMARY KEY

=over 4

=item * L</erm_counter_log_summary_id>

=back

=cut

__PACKAGE__->set_primary_key("erm_counter_log_summary_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<erm_counter_log_summary_period_idx>

=over 4

=item * L</usage_data_provider_id>

=item * L</report_type>

=item * L</report_year>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "erm_counter_log_summary_period_idx",
  ["usage_data_provider_id", "report_type", "report_year"],
);

=head1 RELATIONS

=head2 usage_data_provider

Type: belongs_to

Related object: L<Koha::Schema::Result::ErmUsageDataProvider>

=cut

__PACKAGE__->belongs_to(
  "usage_data_provider",
  "Koha::Schema::Result::ErmUsageDataProvider",
  { erm_usage_data_provider_id => "usage_data_provider_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-03 16:25:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+VJ/kz0xM+wrRUAR3wHSfA

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
