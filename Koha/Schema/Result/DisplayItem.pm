use utf8;
package Koha::Schema::Result::DisplayItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::DisplayItem

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<display_items>

=cut

__PACKAGE__->table("display_items");

=head1 ACCESSORS

=head2 display_item_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 display_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key to link to displays.display_id

=head2 itemnumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

items.itemnumber for the item on display

=head2 biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

biblio.biblionumber for the bibliographic record on display

=head2 date_added

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the item was added to the display

=head2 date_remove

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the item should be removed from the display

=cut

__PACKAGE__->add_columns(
  "display_item_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "display_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "itemnumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "date_added",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "date_remove",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</display_item_id>

=back

=cut

__PACKAGE__->set_primary_key("display_item_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<display_items_uniq>

=over 4

=item * L</display_id>

=item * L</itemnumber>

=back

=cut

__PACKAGE__->add_unique_constraint("display_items_uniq", ["display_id", "itemnumber"]);

=head1 RELATIONS

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
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 display

Type: belongs_to

Related object: L<Koha::Schema::Result::Display>

=cut

__PACKAGE__->belongs_to(
  "display",
  "Koha::Schema::Result::Display",
  { display_id => "display_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 itemnumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "itemnumber",
  "Koha::Schema::Result::Item",
  { itemnumber => "itemnumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-04-29 08:54:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kIoTPESKKxAvv5/szbu0Xw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
