use utf8;
package Koha::Schema::Result::AcqSpentInvoicelineDistribution;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("acq_spent_invoiceline_distributions");

__PACKAGE__->add_columns(
  "invoiceline_fund_distribution_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "percentage",
  { data_type => "decimal", is_nullable => 1, size => [5, 2] },
  "price",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "unit_price",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "quantity_invoiced",
  { data_type => "smallint", is_nullable => 0 },
  "fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["orderline", "adjustment"] },
    is_nullable => 0,
  },
  "invoice_status",
  { data_type => "tinyint", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("invoiceline_fund_distribution_id");

__PACKAGE__->belongs_to(
  "fund",
  "Koha::Schema::Result::AcqFund",
  { fund_id => "fund_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

__PACKAGE__->add_columns(
    '+invoice_status' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::Invoicing::SpentInvoicelineDistribution';
}

sub koha_objects_class {
    'Koha::Acquisition::Invoicing::SpentInvoicelineDistributions';
}

1;
