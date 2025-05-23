use utf8;
package Koha::Schema::Result::AuthSubfieldStructure;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AuthSubfieldStructure

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<auth_subfield_structure>

=cut

__PACKAGE__->table("auth_subfield_structure");

=head1 ACCESSORS

=head2 authtypecode

  data_type: 'varchar'
  default_value: (empty string)
  is_foreign_key: 1
  is_nullable: 0
  size: 10

=head2 tagfield

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 3

=head2 tagsubfield

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 1

=head2 liblibrarian

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 libopac

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 repeatable

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 mandatory

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 tab

  data_type: 'tinyint'
  is_nullable: 1

=head2 authorised_value

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 value_builder

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 seealso

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 isurl

  data_type: 'tinyint'
  is_nullable: 1

=head2 hidden

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 linkid

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 kohafield

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 1
  size: 45

=head2 frameworkcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 defaultvalue

  data_type: 'mediumtext'
  is_nullable: 1

=head2 display_order

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "authtypecode",
  {
    data_type => "varchar",
    default_value => "",
    is_foreign_key => 1,
    is_nullable => 0,
    size => 10,
  },
  "tagfield",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 3 },
  "tagsubfield",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 1 },
  "liblibrarian",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "libopac",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "repeatable",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "mandatory",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "tab",
  { data_type => "tinyint", is_nullable => 1 },
  "authorised_value",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "value_builder",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "seealso",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "isurl",
  { data_type => "tinyint", is_nullable => 1 },
  "hidden",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "linkid",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "kohafield",
  { data_type => "varchar", default_value => "", is_nullable => 1, size => 45 },
  "frameworkcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "defaultvalue",
  { data_type => "mediumtext", is_nullable => 1 },
  "display_order",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</authtypecode>

=item * L</tagfield>

=item * L</tagsubfield>

=back

=cut

__PACKAGE__->set_primary_key("authtypecode", "tagfield", "tagsubfield");

=head1 RELATIONS

=head2 authtypecode

Type: belongs_to

Related object: L<Koha::Schema::Result::AuthType>

=cut

__PACKAGE__->belongs_to(
  "authtypecode",
  "Koha::Schema::Result::AuthType",
  { authtypecode => "authtypecode" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-01-19 06:49:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:c6rPINoF/ZP4YzXU1VR+UQ

__PACKAGE__->add_columns(
    '+isurl'  => { is_boolean => 1 },
    '+linkid' => { is_boolean => 0 },
    '+tab'    => { is_boolean => 0 },
);

=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::Authority::Subfield';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::Authority::Subfields';
}

1;
