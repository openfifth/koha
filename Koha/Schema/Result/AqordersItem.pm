use utf8;
package Koha::Schema::Result::AqordersItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AqordersItem

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aqorders_items>

=cut

__PACKAGE__->table("aqorders_items");

=head1 ACCESSORS

=head2 ordernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

the order this item is attached to (aqorders.ordernumber)

=head2 itemnumber

  data_type: 'integer'
  is_nullable: 0

the item number for this item (items.itemnumber)

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

the date and time this order item was last touched

=head2 received

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

Datetime the item was first physically received via circulation check-in

=cut

__PACKAGE__->add_columns(
  "ordernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "itemnumber",
  { data_type => "integer", is_nullable => 0 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "received",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</itemnumber>

=back

=cut

__PACKAGE__->set_primary_key("itemnumber");

=head1 RELATIONS

=head2 ordernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqorder>

=cut

__PACKAGE__->belongs_to(
  "ordernumber",
  "Koha::Schema::Result::Aqorder",
  { ordernumber => "ordernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-03 08:17:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5qahHUjyROwLiMKhacnyqw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
