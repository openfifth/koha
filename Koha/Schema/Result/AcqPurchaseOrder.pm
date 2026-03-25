use utf8;
package Koha::Schema::Result::AcqPurchaseOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqPurchaseOrder

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_purchase_orders>

=cut

__PACKAGE__->table("acq_purchase_orders");

=head1 ACCESSORS

=head2 purchase_order_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 vendor_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

link to the vendor

=head2 status

  data_type: 'enum'
  extra: {list => ["new","ordered","cancelled"]}
  is_nullable: 1

status of the purchase order

=head2 po_name

  data_type: 'varchar'
  is_nullable: 1
  size: 50

name for the purchase order

=head2 po_internal_note

  data_type: 'longtext'
  is_nullable: 1

internal note for the purchase order

=head2 po_vendor_note

  data_type: 'longtext'
  is_nullable: 1

vendor note for the purchase order

=head2 external_po_number

  data_type: 'longtext'
  is_nullable: 1

external po number for the purchase order

=head2 contract_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

link to the contract

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

creation date of the purchase order

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

last update of the purchase order

=head2 ordered_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

ordering date of the purchase order

=head2 order_method

  data_type: 'varchar'
  is_nullable: 1
  size: 255

method of purchase for the purchase order

=head2 created_by

  data_type: 'integer'
  is_nullable: 1

creator of the purchase order

=head2 delivery_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch to deliver to

=head2 billing_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch to bill for the order

=cut

__PACKAGE__->add_columns(
  "purchase_order_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "vendor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status",
  {
    data_type => "enum",
    extra => { list => ["new", "ordered", "cancelled"] },
    is_nullable => 1,
  },
  "po_name",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "po_internal_note",
  { data_type => "longtext", is_nullable => 1 },
  "po_vendor_note",
  { data_type => "longtext", is_nullable => 1 },
  "external_po_number",
  { data_type => "longtext", is_nullable => 1 },
  "contract_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
  "ordered_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "order_method",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "created_by",
  { data_type => "integer", is_nullable => 1 },
  "delivery_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "billing_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</purchase_order_id>

=back

=cut

__PACKAGE__->set_primary_key("purchase_order_id");

=head1 RELATIONS

=head2 acq_orderlines

Type: has_many

Related object: L<Koha::Schema::Result::AcqOrderline>

=cut

__PACKAGE__->has_many(
  "acq_orderlines",
  "Koha::Schema::Result::AcqOrderline",
  { "foreign.purchase_order_id" => "self.purchase_order_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 billing_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "billing_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "billing_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 contract

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqcontract>

=cut

__PACKAGE__->belongs_to(
  "contract",
  "Koha::Schema::Result::Aqcontract",
  { contractnumber => "contract_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "CASCADE" },
);

=head2 delivery_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "delivery_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "delivery_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-08-18 10:28:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AWQ1XUgDd9QjlOQQFmirhA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
