use utf8;
package Koha::Schema::Result::Display;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Display

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<displays>

=cut

__PACKAGE__->table("displays");

=head1 ACCESSORS

=head2 display_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique id for the display

=head2 display_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

the name of the display

=head2 start_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the start date of the display (optional)

=head2 end_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the end date of the display (optional)

=head2 enabled

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

determines whether the display is active

=head2 display_location

  data_type: 'varchar'
  is_nullable: 1
  size: 80

the shelving location for the display (optional)

=head2 display_code

  data_type: 'varchar'
  is_nullable: 1
  size: 80

the collection code for the display (optional)

=head2 display_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

the branch code for the display (optional)

=head2 display_home_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

a new home branch for the item to have while on display (optional)

=head2 display_holding_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

a new holding branch for the item to have while on display (optional)

=head2 display_itype

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

a new itype for the item to have while on display (optional)

=head2 staff_note

  data_type: 'mediumtext'
  is_nullable: 1

staff note for the display

=head2 public_note

  data_type: 'mediumtext'
  is_nullable: 1

public note for the display

=head2 display_days

  data_type: 'integer'
  is_nullable: 1

default number of days items will remain on display

=head2 display_return_over

  data_type: 'enum'
  default_value: 'no'
  extra: {list => ["any","any_except_homebranch","no"]}
  is_nullable: 0

should the item be removed from the display when it is returned

=cut

__PACKAGE__->add_columns(
  "display_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "display_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "start_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "end_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "enabled",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "display_location",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "display_code",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "display_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "display_home_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "display_holding_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "display_itype",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "staff_note",
  { data_type => "mediumtext", is_nullable => 1 },
  "public_note",
  { data_type => "mediumtext", is_nullable => 1 },
  "display_days",
  { data_type => "integer", is_nullable => 1 },
  "display_return_over",
  {
    data_type => "enum",
    default_value => "no",
    extra => { list => ["any", "any_except_homebranch", "no"] },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</display_id>

=back

=cut

__PACKAGE__->set_primary_key("display_id");

=head1 RELATIONS

=head2 display_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "display_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "display_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 display_holding_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "display_holding_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "display_holding_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 display_home_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "display_home_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "display_home_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 display_items

Type: has_many

Related object: L<Koha::Schema::Result::DisplayItem>

=cut

__PACKAGE__->has_many(
  "display_items",
  "Koha::Schema::Result::DisplayItem",
  { "foreign.display_id" => "self.display_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 display_itype

Type: belongs_to

Related object: L<Koha::Schema::Result::Itemtype>

=cut

__PACKAGE__->belongs_to(
  "display_itype",
  "Koha::Schema::Result::Itemtype",
  { itemtype => "display_itype" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-04-29 08:54:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k+YchpMsLsA1zB7h1ntJsw

__PACKAGE__->add_columns(
  '+enabled' => { is_boolean => 1 },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
