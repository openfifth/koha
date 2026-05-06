use utf8;
package Koha::Schema::Result::AcqInvoice;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqInvoice

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_invoices>

=cut

__PACKAGE__->table("acq_invoices");

=head1 ACCESSORS

=head2 invoice_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 vendor_invoice_number

  data_type: 'longtext'
  is_nullable: 0

vendor-issued invoice number

=head2 vendor_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

link to the vendor

=head2 received_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the invoice was received

=head2 billed_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the invoice was billed

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

creation date of the invoice

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

last update of the invoice

=head2 closed_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the invoice was closed

=head2 status

  data_type: 'tinyint'
  is_nullable: 0

status of the invoice

=head2 approved

  data_type: 'tinyint'
  is_nullable: 1

has the invoice been approved

=head2 approved_by

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

borrower who approved the invoice

=head2 currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency of the invoice

=head2 invoice_total_amount

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

total amount of the invoice

=head2 payment_due

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date payment is due

=head2 external_financial_system

  data_type: 'tinyint'
  is_nullable: 1

is this managed by an external financial system

=head2 external_invoice_number

  data_type: 'mediumtext'
  is_nullable: 1

invoice number in the external financial system

=head2 external_accounting_id

  data_type: 'mediumtext'
  is_nullable: 1

accounting id in the external financial system

=head2 exported_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the invoice was exported to an external system

=head2 edifact_message_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

link to the edifact message

=cut

__PACKAGE__->add_columns(
  "invoice_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "vendor_invoice_number",
  { data_type => "longtext", is_nullable => 0 },
  "vendor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "received_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "billed_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
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
  "closed_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "status",
  { data_type => "tinyint", is_nullable => 0 },
  "approved",
  { data_type => "tinyint", is_nullable => 1 },
  "approved_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "currency",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "invoice_total_amount",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "payment_due",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "external_financial_system",
  { data_type => "tinyint", is_nullable => 1 },
  "external_invoice_number",
  { data_type => "mediumtext", is_nullable => 1 },
  "external_accounting_id",
  { data_type => "mediumtext", is_nullable => 1 },
  "exported_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "edifact_message_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</invoice_id>

=back

=cut

__PACKAGE__->set_primary_key("invoice_id");

=head1 RELATIONS

=head2 acq_invoicelines

Type: has_many

Related object: L<Koha::Schema::Result::AcqInvoiceline>

=cut

__PACKAGE__->has_many(
  "acq_invoicelines",
  "Koha::Schema::Result::AcqInvoiceline",
  { "foreign.invoice_id" => "self.invoice_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 approved_by

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "approved_by",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "approved_by" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 edifact_message

Type: belongs_to

Related object: L<Koha::Schema::Result::EdifactMessage>

=cut

__PACKAGE__->belongs_to(
  "edifact_message",
  "Koha::Schema::Result::EdifactMessage",
  { id => "edifact_message_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 vendor

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqbookseller>

=cut

__PACKAGE__->belongs_to(
  "vendor",
  "Koha::Schema::Result::Aqbookseller",
  { id => "vendor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-05-06 13:10:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7QNTjvpNoCRGFzkBuCjGyA


__PACKAGE__->add_columns(
    '+status'                    => { is_boolean => 1 },
    '+approved'                  => { is_boolean => 1 },
    '+external_financial_system' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::Invoicing::Invoice';
}

sub koha_objects_class {
    'Koha::Acquisition::Invoicing::Invoices';
}

1;
