use utf8;
package Koha::Schema::Result::AcqInvoicelineFundDistribution;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqInvoicelineFundDistribution

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_invoiceline_fund_distributions>

=cut

__PACKAGE__->table("acq_invoiceline_fund_distributions");

=head1 ACCESSORS

=head2 invoiceline_fund_distribution_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 invoiceline_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

invoice line the distribution was made against

=head2 fund_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

fund the distribution was made against

=head2 percentage

  data_type: 'decimal'
  is_nullable: 1
  size: [5,2]

distribution percentage

=head2 distributed_amount_oc

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distribution amount in the order currency

=head2 exchange_rate

  data_type: 'decimal'
  is_nullable: 0
  size: [20,10]

exchange rate for the distribution

=head2 distributed_amount

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distribution amount in the active currency

=head2 distributed_amount_tax_excluded

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distributed amount excluding tax

=head2 distributed_amount_tax_included

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distributed amount including tax

=head2 tax_rate

  data_type: 'decimal'
  is_nullable: 0
  size: [6,4]

tax rate applied

=head2 tax_value

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

tax value

=head2 distribution_reason

  data_type: 'varchar'
  is_nullable: 1
  size: 80

reason for distribution

=head2 distribution_note

  data_type: 'mediumtext'
  is_nullable: 1

note for distribution

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

creation date of the distribution

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

last update of the distribution

=cut

__PACKAGE__->add_columns(
  "invoiceline_fund_distribution_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "invoiceline_id",
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
  "distributed_amount_tax_excluded",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distributed_amount_tax_included",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "tax_rate",
  { data_type => "decimal", is_nullable => 0, size => [6, 4] },
  "tax_value",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distribution_reason",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "distribution_note",
  { data_type => "mediumtext", is_nullable => 1 },
  "created_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "modified_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</invoiceline_fund_distribution_id>

=back

=cut

__PACKAGE__->set_primary_key("invoiceline_fund_distribution_id");

=head1 RELATIONS

=head2 fund

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->belongs_to(
  "fund",
  "Koha::Schema::Result::AcqFund",
  { fund_id => "fund_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 invoiceline

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqInvoiceline>

=cut

__PACKAGE__->belongs_to(
  "invoiceline",
  "Koha::Schema::Result::AcqInvoiceline",
  { invoiceline_id => "invoiceline_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-05-06 13:10:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jqbTXF8fT46W9QH8e746uQ


sub koha_object_class {
    'Koha::Acquisition::Invoicing::InvoicelineFundDistribution';
}

sub koha_objects_class {
    'Koha::Acquisition::Invoicing::InvoicelineFundDistributions';
}

1;
