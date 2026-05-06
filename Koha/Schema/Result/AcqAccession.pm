use utf8;
package Koha::Schema::Result::AcqAccession;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqAccession

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_accessions>

=cut

__PACKAGE__->table("acq_accessions");

=head1 ACCESSORS

=head2 accession_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 orderline_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

order line the accession was made against

=head2 invoiceline_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

invoice line the accession was made against

=head2 received_biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

bibliographic record received

=head2 received_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date item was received

=head2 quantity_received

  data_type: 'smallint'
  is_nullable: 1

quantity received

=head2 type

  data_type: 'enum'
  extra: {list => ["INVOICE_AND_RECEIVE","INVOICE_ONLY","RECEIVE_ONLY","CANCELLATION"]}
  is_nullable: 0

type of accession event

=head2 accession_description

  data_type: 'longtext'
  is_nullable: 1

description of the accession

=head2 cancellation_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date of cancellation

=head2 cancellation_reason

  data_type: 'mediumtext'
  is_nullable: 1

reason for cancellation

=head2 quantity_cancelled

  data_type: 'smallint'
  is_nullable: 1

quantity cancelled

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

creation date of the accession

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

last update of the accession

=cut

__PACKAGE__->add_columns(
  "accession_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "orderline_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "invoiceline_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "received_biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "received_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "quantity_received",
  { data_type => "smallint", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => {
      list => [
        "INVOICE_AND_RECEIVE",
        "INVOICE_ONLY",
        "RECEIVE_ONLY",
        "CANCELLATION",
      ],
    },
    is_nullable => 0,
  },
  "accession_description",
  { data_type => "longtext", is_nullable => 1 },
  "cancellation_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "cancellation_reason",
  { data_type => "mediumtext", is_nullable => 1 },
  "quantity_cancelled",
  { data_type => "smallint", is_nullable => 1 },
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

=item * L</accession_id>

=back

=cut

__PACKAGE__->set_primary_key("accession_id");

=head1 RELATIONS

=head2 invoiceline

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqInvoiceline>

=cut

__PACKAGE__->belongs_to(
  "invoiceline",
  "Koha::Schema::Result::AcqInvoiceline",
  { invoiceline_id => "invoiceline_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 orderline

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqOrderline>

=cut

__PACKAGE__->belongs_to(
  "orderline",
  "Koha::Schema::Result::AcqOrderline",
  { orderline_id => "orderline_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);

=head2 received_biblionumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
  "received_biblionumber",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "received_biblionumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-05-06 13:10:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WL7JJvUwCiG+86uXDIerwQ


sub koha_object_class {
    'Koha::Acquisition::Invoicing::Accession';
}

sub koha_objects_class {
    'Koha::Acquisition::Invoicing::Accessions';
}

1;
