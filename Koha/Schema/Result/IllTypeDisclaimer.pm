use utf8;
package Koha::Schema::Result::IllTypeDisclaimer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IllTypeDisclaimer

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ill_type_disclaimers>

=cut

__PACKAGE__->table("ill_type_disclaimers");

=head1 ACCESSORS

=head2 illrequest_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

ILL request this disclaimer prompt is for

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 200

unique code identifying this disclaimer question

=head2 text

  data_type: 'mediumtext'
  is_nullable: 1

question text for this disclaimer

=head2 value

  data_type: 'mediumtext'
  is_nullable: 0

response text for this disclaimer

=head2 date

  data_type: 'mediumtext'
  is_nullable: 0

date this disclaimer was filled out

=cut

__PACKAGE__->add_columns(
  "illrequest_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 200 },
  "text",
  { data_type => "mediumtext", is_nullable => 1 },
  "value",
  { data_type => "mediumtext", is_nullable => 0 },
  "date",
  { data_type => "mediumtext", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</illrequest_id>

=item * L</code>

=back

=cut

__PACKAGE__->set_primary_key("illrequest_id", "code");

=head1 RELATIONS

=head2 illrequest

Type: belongs_to

Related object: L<Koha::Schema::Result::Illrequest>

=cut

__PACKAGE__->belongs_to(
  "illrequest",
  "Koha::Schema::Result::Illrequest",
  { illrequest_id => "illrequest_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-05 14:16:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NXl3yeYxU7+sSLA72bKNxQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
