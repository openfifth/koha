use utf8;
package Koha::Schema::Result::ItemBiblioLink;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ItemBiblioLink

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<item_biblio_links>

=cut

__PACKAGE__->table("item_biblio_links");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

id for the item/biblio link

=head2 itemnumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

link to the item

=head2 biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

link to the bibliographic record

=head2 link_type

  data_type: 'varchar'
  is_nullable: 0
  size: 80

type of link, from authorised value category ITEM_BIBLIO_LINK_TYPE (e.g. binding, analytic)

=head2 display_order

  data_type: 'integer'
  is_nullable: 1

optional explicit ordering among links, NULL means no explicit order

=head2 created_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time and date the link was created

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "itemnumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "link_type",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "display_order",
  { data_type => "integer", is_nullable => 1 },
  "created_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<item_biblio_links_uniq_1>

=over 4

=item * L</itemnumber>

=item * L</biblionumber>

=back

=cut

__PACKAGE__->add_unique_constraint("item_biblio_links_uniq_1", ["itemnumber", "biblionumber"]);

=head1 RELATIONS

=head2 biblionumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
  "biblionumber",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblionumber" },
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-07-27 09:55:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4LIyGwfXkHtUqSEpBDez8Q

sub koha_object_class {
    'Koha::Item::BiblioLink';
}

sub koha_objects_class {
    'Koha::Item::BiblioLinks';
}

1;
