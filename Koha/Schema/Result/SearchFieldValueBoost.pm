use utf8;
package Koha::Schema::Result::SearchFieldValueBoost;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::SearchFieldValueBoost

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<search_field_value_boost>

=cut

__PACKAGE__->table("search_field_value_boost");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 search_field_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

FK to search_field

=head2 value

  data_type: 'varchar'
  is_nullable: 0
  size: 255

the field value to boost

=head2 weight

  data_type: 'decimal'
  default_value: 1.00
  is_nullable: 0
  size: [5,2]

relevance multiplier applied when a document matches this value

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "search_field_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "weight",
  {
    data_type => "decimal",
    default_value => "1.00",
    is_nullable => 0,
    size => [5, 2],
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<search_field_value>

=over 4

=item * L</search_field_id>

=item * L</value>

=back

=cut

__PACKAGE__->add_unique_constraint("search_field_value", ["search_field_id", "value"]);

=head1 RELATIONS

=head2 search_field

Type: belongs_to

Related object: L<Koha::Schema::Result::SearchField>

=cut

__PACKAGE__->belongs_to(
  "search_field",
  "Koha::Schema::Result::SearchField",
  { id => "search_field_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-06-18 11:16:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M0ooRTzidatnmCL+KagXUA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
