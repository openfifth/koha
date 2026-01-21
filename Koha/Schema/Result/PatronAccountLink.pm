use utf8;
package Koha::Schema::Result::PatronAccountLink;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::PatronAccountLink

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<patron_account_links>

=cut

__PACKAGE__->table("patron_account_links");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 link_group_id

  data_type: 'integer'
  is_nullable: 0

groups linked accounts together

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key to borrowers table

=head2 created_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

when the link was created

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "link_group_id",
  { data_type => "integer", is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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

=head2 C<borrowernumber>

=over 4

=item * L</borrowernumber>

=back

=cut

__PACKAGE__->add_unique_constraint("borrowernumber", ["borrowernumber"]);

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-01-19 13:41:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iWUPjrtWP7qqlIJZJ7kOuA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
