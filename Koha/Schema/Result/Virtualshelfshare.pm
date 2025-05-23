use utf8;
package Koha::Schema::Result::Virtualshelfshare;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Virtualshelfshare

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<virtualshelfshares>

=cut

__PACKAGE__->table("virtualshelfshares");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique key

=head2 shelfnumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key for virtualshelves

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

borrower that accepted access to this list

=head2 invitekey

  data_type: 'varchar'
  is_nullable: 1
  size: 10

temporary string used in accepting the invitation to access this list; not-empty means that the invitation has not been accepted yet

=head2 sharedate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date of invitation or acceptance of invitation

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "shelfnumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "invitekey",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "sharedate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);

=head2 shelfnumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Virtualshelve>

=cut

__PACKAGE__->belongs_to(
  "shelfnumber",
  "Koha::Schema::Result::Virtualshelve",
  { shelfnumber => "shelfnumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-04-28 16:41:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YWvVuOeor2WoBERfGGL45A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
