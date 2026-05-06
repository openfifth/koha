use utf8;
package Koha::Schema::Result::AcqFundSummary;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("acq_fund_summary");

__PACKAGE__->add_columns(
  "fund_id",
  { data_type => "integer", is_nullable => 0 },
  "period",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "ledger",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "code",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "owner",
  { data_type => "integer", is_nullable => 1 },
  "managing_branch",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "fund_amount",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "orders_status_new",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "ordered",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "spent",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
);

__PACKAGE__->set_primary_key("fund_id");

__PACKAGE__->belongs_to(
  "fund",
  "Koha::Schema::Result::AcqFund",
  { fund_id => "fund_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

sub koha_object_class  { 'Koha::Acquisition::Finances::FundSummary' }
sub koha_objects_class { 'Koha::Acquisition::Finances::FundSummaries' }

1;
