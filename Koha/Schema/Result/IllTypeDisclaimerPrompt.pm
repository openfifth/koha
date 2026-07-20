use utf8;
package Koha::Schema::Result::IllTypeDisclaimerPrompt;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IllTypeDisclaimerPrompt

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ill_type_disclaimer_prompts>

=cut

__PACKAGE__->table("ill_type_disclaimer_prompts");

=head1 ACCESSORS

=head2 uuid

  data_type: 'varchar'
  is_nullable: 0
  size: 128

a unique token for this prompt

=head2 patron_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Patron this disclaimer prompt is for

=head2 illrequest_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

ILL request this disclaimer prompt is for

=head2 date_prompted

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

when this prompt was created

=head2 date_replied

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

if non-null, when this prompt was replied to

=head2 valid_until

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 0

when this prompt expires

=cut

__PACKAGE__->add_columns(
  "uuid",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "patron_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "illrequest_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "date_prompted",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "date_replied",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "valid_until",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->set_primary_key("uuid");

=head1 UNIQUE CONSTRAINTS

=head2 C<ill_type_disclaimer_uniq>

=over 4

=item * L</patron_id>

=item * L</illrequest_id>

=back

=cut

__PACKAGE__->add_unique_constraint("ill_type_disclaimer_uniq", ["patron_id", "illrequest_id"]);

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

=head2 patron

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "patron",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "patron_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-07-20 09:28:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:P47sC+esHzgZbg4DThMddQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
