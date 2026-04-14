use utf8;
package Koha::Schema::Result::AcqOrderlineItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqOrderlineItem

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_orderline_items>

=cut

__PACKAGE__->table("acq_orderline_items");

=head1 ACCESSORS

=head2 orderline_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

orderline the item is linked to

=head2 itemnumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

the linked item

=cut

__PACKAGE__->add_columns(
  "orderline_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "itemnumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</orderline_id>

=item * L</itemnumber>

=back

=cut

__PACKAGE__->set_primary_key("orderline_id", "itemnumber");

=head1 RELATIONS

=head2 itemnumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "itemnumber",
  "Koha::Schema::Result::Item",
  { itemnumber => "itemnumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 orderline

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqOrderline>

=cut

__PACKAGE__->belongs_to(
  "orderline",
  "Koha::Schema::Result::AcqOrderline",
  { orderline_id => "orderline_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-04-14 11:16:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zJnFiFA+eQk19b0O4rMblg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
