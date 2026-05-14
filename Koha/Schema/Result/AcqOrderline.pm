use utf8;
package Koha::Schema::Result::AcqOrderline;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqOrderline

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_orderlines>

=cut

__PACKAGE__->table("acq_orderlines");

=head1 ACCESSORS

=head2 orderline_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

bibliographic record for the order line

=head2 deleted_biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

deleted bibliographic record for the order line

=head2 subscriptionid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

subscription record for the order line

=head2 purchase_order_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

purchase order for the order line

=head2 created_by

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

creator of the order line

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

creation date of the order line

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

last update of the order line

=head2 ordered_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

ordering date of the order line

=head2 status

  data_type: 'enum'
  extra: {list => ["DRAFT","NEW","ORDERED","CONTINUING","COMPLETE","PARTIAL","UNSUBSCRIBED","CANCELLED"]}
  is_nullable: 0

status of the order line

=head2 payment_status

  data_type: 'enum'
  extra: {list => ["PENDING","PARTIAL","PAID","UNPAID","CANCELLED"]}
  is_nullable: 1

status of the order line

=head2 is_continuous

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

is this a standing order line?

=head2 renewal_required

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

does this need renewing?

=head2 review_interval

  data_type: 'integer'
  is_nullable: 1

days between reviews

=head2 last_review_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

last date order line was reviewed

=head2 planned_cancellation_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the subscription is to be cancelled

=head2 acquisition_method

  data_type: 'varchar'
  is_nullable: 1
  size: 255

method of purchase for the order line

=head2 create_items

  data_type: 'enum'
  extra: {list => ["ordering","receiving","cataloging"]}
  is_nullable: 1

item creation point for the order line

=head2 managing_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch responsible for the order line

=head2 vendor_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

link to the vendor

=head2 quantity_ordered

  data_type: 'integer'
  is_nullable: 0

quantity ordered

=head2 uncertain_price

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

is the price uncertain?

=head2 vendor_price_currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency used for the vendor price

=head2 vendor_price

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 1
  size: [28,6]

price charged by the vendor

=head2 discount_percentage

  data_type: 'decimal'
  is_nullable: 1
  size: [5,2]

discount applied to the price

=head2 discount_amount_oc

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

discount amount in the original currency

=head2 replacement_price

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

replacement cost for the purchase

=head2 calculated_amount_oc

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 1
  size: [28,6]

the total cost in the original currency including discount

=head2 internal_note

  data_type: 'longtext'
  is_nullable: 1

internal note

=head2 receiving_note

  data_type: 'longtext'
  is_nullable: 1

receiving note

=head2 vendor_note

  data_type: 'longtext'
  is_nullable: 1

vendor note

=head2 urgent_order

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

is this an urgent order?

=head2 statistic1

  data_type: 'varchar'
  is_nullable: 1
  size: 80

statistical field

=head2 statistic2

  data_type: 'varchar'
  is_nullable: 1
  size: 80

second statistical field

=head2 estimated_delivery_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the delivery is expected

=head2 edi_line_item_id

  data_type: 'varchar'
  is_nullable: 1
  size: 35

supplier article id for an edifact order line

=head2 edi_suppliers_reference_number

  data_type: 'varchar'
  is_nullable: 1
  size: 35

supplier unique edifact quote ref

=head2 edi_suppliers_reference_qualifier

  data_type: 'varchar'
  is_nullable: 1
  size: 3

supplier unique edifact quote ref qualifier

=head2 edi_suppliers_report

  data_type: 'mediumtext'
  is_nullable: 1

reports received from an edi supplier

=cut

__PACKAGE__->add_columns(
  "orderline_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "deleted_biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "subscriptionid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "purchase_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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
  "status",
  {
    data_type => "enum",
    extra => {
      list => [
        "DRAFT",
        "NEW",
        "ORDERED",
        "CONTINUING",
        "COMPLETE",
        "PARTIAL",
        "UNSUBSCRIBED",
        "CANCELLED",
      ],
    },
    is_nullable => 0,
  },
  "payment_status",
  {
    data_type => "enum",
    extra => { list => ["PENDING", "PARTIAL", "PAID", "UNPAID", "CANCELLED"] },
    is_nullable => 1,
  },
  "is_continuous",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "renewal_required",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "review_interval",
  { data_type => "integer", is_nullable => 1 },
  "last_review_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "planned_cancellation_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "acquisition_method",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "create_items",
  {
    data_type => "enum",
    extra => { list => ["ordering", "receiving", "cataloging"] },
    is_nullable => 1,
  },
  "managing_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "vendor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "quantity_ordered",
  { data_type => "integer", is_nullable => 0 },
  "uncertain_price",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "vendor_price_currency",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "vendor_price",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 1,
    size => [28, 6],
  },
  "discount_percentage",
  { data_type => "decimal", is_nullable => 1, size => [5, 2] },
  "discount_amount_oc",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "replacement_price",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "calculated_amount_oc",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 1,
    size => [28, 6],
  },
  "internal_note",
  { data_type => "longtext", is_nullable => 1 },
  "receiving_note",
  { data_type => "longtext", is_nullable => 1 },
  "vendor_note",
  { data_type => "longtext", is_nullable => 1 },
  "urgent_order",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "statistic1",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "statistic2",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "estimated_delivery_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "edi_line_item_id",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "edi_suppliers_reference_number",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "edi_suppliers_reference_qualifier",
  { data_type => "varchar", is_nullable => 1, size => 3 },
  "edi_suppliers_report",
  { data_type => "mediumtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</orderline_id>

=back

=cut

__PACKAGE__->set_primary_key("orderline_id");

=head1 RELATIONS

=head2 acq_accessions

Type: has_many

Related object: L<Koha::Schema::Result::AcqAccession>

=cut

__PACKAGE__->has_many(
  "acq_accessions",
  "Koha::Schema::Result::AcqAccession",
  { "foreign.orderline_id" => "self.orderline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_orderline_fund_distributions

Type: has_many

Related object: L<Koha::Schema::Result::AcqOrderlineFundDistribution>

=cut

__PACKAGE__->has_many(
  "acq_orderline_fund_distributions",
  "Koha::Schema::Result::AcqOrderlineFundDistribution",
  { "foreign.orderline_id" => "self.orderline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_orderline_items

Type: has_many

Related object: L<Koha::Schema::Result::AcqOrderlineItem>

=cut

__PACKAGE__->has_many(
  "acq_orderline_items",
  "Koha::Schema::Result::AcqOrderlineItem",
  { "foreign.orderline_id" => "self.orderline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_orderline_managers

Type: has_many

Related object: L<Koha::Schema::Result::AcqOrderlineManager>

=cut

__PACKAGE__->has_many(
  "acq_orderline_managers",
  "Koha::Schema::Result::AcqOrderlineManager",
  { "foreign.orderline_id" => "self.orderline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_orderline_users

Type: has_many

Related object: L<Koha::Schema::Result::AcqOrderlineUser>

=cut

__PACKAGE__->has_many(
  "acq_orderline_users",
  "Koha::Schema::Result::AcqOrderlineUser",
  { "foreign.orderline_id" => "self.orderline_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biblionumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
  "biblionumber",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblionumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 created_by

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "created_by",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "created_by" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 deleted_biblionumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Deletedbiblio>

=cut

__PACKAGE__->belongs_to(
  "deleted_biblionumber",
  "Koha::Schema::Result::Deletedbiblio",
  { biblionumber => "deleted_biblionumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 managing_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "managing_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "managing_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 purchase_order

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqPurchaseOrder>

=cut

__PACKAGE__->belongs_to(
  "purchase_order",
  "Koha::Schema::Result::AcqPurchaseOrder",
  { purchase_order_id => "purchase_order_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 subscriptionid

Type: belongs_to

Related object: L<Koha::Schema::Result::Subscription>

=cut

__PACKAGE__->belongs_to(
  "subscriptionid",
  "Koha::Schema::Result::Subscription",
  { subscriptionid => "subscriptionid" },
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
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 borrowernumbers

Type: many_to_many

Composing rels: L</acq_orderline_managers> -> borrowernumber

=cut

__PACKAGE__->many_to_many("borrowernumbers", "acq_orderline_managers", "borrowernumber");

=head2 borrowernumbers_2s

Type: many_to_many

Composing rels: L</acq_orderline_users> -> borrowernumber

=cut

__PACKAGE__->many_to_many("borrowernumbers_2s", "acq_orderline_users", "borrowernumber");

=head2 itemnumbers

Type: many_to_many

Composing rels: L</acq_orderline_items> -> itemnumber

=cut

__PACKAGE__->many_to_many("itemnumbers", "acq_orderline_items", "itemnumber");


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-05-14 10:33:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xCMVx6FE1KirBZvhC9Ck4A


=head2 koha_object_class

=cut

sub koha_object_class {
    'Koha::Acquisition::OrderManagement::Orderline';
}

=head2 koha_objects_class

=cut

sub koha_objects_class {
    'Koha::Acquisition::OrderManagement::Orderlines';
}


__PACKAGE__->has_many(
    "additional_field_values",
    "Koha::Schema::Result::AdditionalFieldValue",
    sub {
        my ($args) = @_;

        return {
            "$args->{foreign_alias}.record_id" => { -ident => "$args->{self_alias}.orderline_id" },

            "$args->{foreign_alias}.field_id" =>
                { -in => \'(SELECT id FROM additional_fields WHERE tablename LIKE "acq_orderlines")' },
        };
    },
    { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
    "extended_attributes",
    "Koha::Schema::Result::AdditionalFieldValue",
    sub {
        my ($args) = @_;

        return {
            "$args->{foreign_alias}.record_id" => { -ident => "$args->{self_alias}.orderline_id" },

            "$args->{foreign_alias}.field_id" =>
                { -in => \'(SELECT id FROM additional_fields WHERE tablename LIKE "acq_orderlines")' },
        };
    },
    { cascade_copy => 0, cascade_delete => 0 },
);


=head2 biblio

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
    "biblio",
    "Koha::Schema::Result::Biblio",
    { biblionumber => "biblionumber" },
    {
        is_deferrable => 1,
        join_type     => "LEFT",
        on_delete     => "RESTRICT",
        on_update     => "RESTRICT",
    },
);


=head2 managing_library

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
    "managing_library",
    "Koha::Schema::Result::Branch",
    { branchcode => "managing_branch" },
    {
        is_deferrable => 1,
        join_type     => "LEFT",
        on_delete     => "CASCADE",
        on_update     => "CASCADE",
    },
);


=head2 fund_distributions

Type: has_many

Related object: L<Koha::Schema::Result::AcqOrderlineFundDistribution>

=cut

__PACKAGE__->has_many(
    "fund_distributions",
    "Koha::Schema::Result::AcqOrderlineFundDistribution",
    { "foreign.orderline_id" => "self.orderline_id" },
    { cascade_copy           => 0, cascade_delete => 0 },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
