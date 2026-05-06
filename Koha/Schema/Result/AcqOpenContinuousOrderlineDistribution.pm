use utf8;
package Koha::Schema::Result::AcqOpenContinuousOrderlineDistribution;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("acq_open_continuous_orderline_distributions");

__PACKAGE__->add_columns(
  "orderline_fund_distribution_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "orderline_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "percentage",
  { data_type => "decimal", is_nullable => 1, size => [5, 2] },
  "distributed_amount_oc",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "exchange_rate",
  { data_type => "decimal", is_nullable => 0, size => [20, 10] },
  "distributed_amount",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "tax_rate",
  { data_type => "decimal", is_nullable => 0, size => [6, 4] },
  "tax_value",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distributed_amount_tax_excluded",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distributed_amount_tax_included",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distributed_ordered_amount",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
);

__PACKAGE__->set_primary_key("orderline_fund_distribution_id");

__PACKAGE__->belongs_to(
  "fund",
  "Koha::Schema::Result::AcqFund",
  { fund_id => "fund_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

sub koha_object_class {
    'Koha::Acquisition::Invoicing::OpenContinuousOrderlineDistribution';
}

sub koha_objects_class {
    'Koha::Acquisition::Invoicing::OpenContinuousOrderlineDistributions';
}

1;
