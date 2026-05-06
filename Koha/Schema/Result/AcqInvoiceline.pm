use utf8;
package Koha::Schema::Result::AcqInvoiceline;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqInvoiceline

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_invoicelines>

=cut

__PACKAGE__->table("acq_invoicelines");

=head1 ACCESSORS

=head2 invoiceline_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 invoice_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

invoice the line belongs to

=head2 quantity_invoiced

  data_type: 'smallint'
  is_nullable: 0

quantity invoiced on this line

=head2 type

  data_type: 'enum'
  extra: {list => ["orderline","adjustment"]}
  is_nullable: 0

type of invoice line

=head2 adjustment_reason

  data_type: 'varchar'
  is_nullable: 1
  size: 80

reason for adjustment

=head2 adjustment_note

  data_type: 'mediumtext'
  is_nullable: 1

note for adjustment

=head2 invoice_unitprice_oc

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

unit price in the order currency

=head2 invoice_currency_oc

  data_type: 'varchar'
  is_nullable: 0
  size: 10

order currency code

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

creation date of the invoice line

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

last update of the invoice line

=cut

__PACKAGE__->add_columns(
  "invoiceline_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "invoice_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quantity_invoiced",
  { data_type => "smallint", is_nullable => 0 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["orderline", "adjustment"] },
    is_nullable => 0,
  },
  "adjustment_reason",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "adjustment_note",
  { data_type => "mediumtext", is_nullable => 1 },
  "invoice_unitprice_oc",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "invoice_currency_oc",
  { data_type => "varchar", is_nullable => 0, size => 10 },
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

=item * L</invoiceline_id>

=back

=cut

__PACKAGE__->set_primary_key("invoiceline_id");

=head1 RELATIONS

=head2 acq_accessions

Type: has_many

Related object: L<Koha::Schema::Result::AcqAccession>

=cut

__PACKAGE__->has_many(
  "acq_accessions",
  "Koha::Schema::Result::AcqAccession",
  { "foreign.invoiceline_id" => "self.invoiceline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_invoiceline_fund_distributions

Type: has_many

Related object: L<Koha::Schema::Result::AcqInvoicelineFundDistribution>

=cut

__PACKAGE__->has_many(
  "acq_invoiceline_fund_distributions",
  "Koha::Schema::Result::AcqInvoicelineFundDistribution",
  { "foreign.invoiceline_id" => "self.invoiceline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 invoice

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqInvoice>

=cut

__PACKAGE__->belongs_to(
  "invoice",
  "Koha::Schema::Result::AcqInvoice",
  { invoice_id => "invoice_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-05-06 13:10:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:onPcpAYkeT8PzasEmCBjew


sub koha_object_class {
    'Koha::Acquisition::Invoicing::Invoiceline';
}

sub koha_objects_class {
    'Koha::Acquisition::Invoicing::Invoicelines';
}

1;
