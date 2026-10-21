use utf8;
package Koha::Schema::Result::Ticket;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Ticket

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tickets>

=cut

__PACKAGE__->table("tickets");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 source

  data_type: 'enum'
  default_value: 'catalog'
  extra: {list => ["catalog"]}
  is_nullable: 0

source of ticket

=head2 reporter_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

id of the patron who reported the ticket

=head2 reporter_email

  data_type: 'longtext'
  is_nullable: 1

the reporter's email address for anonymous tickets

=head2 reported_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

date and time this ticket was reported

=head2 title

  data_type: 'text'
  is_nullable: 0

ticket title

=head2 body

  data_type: 'text'
  is_nullable: 0

ticket details

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 80

current status of the ticket

=head2 assignee_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

id of the user who this ticket is assigned to

=head2 resolver_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

id of the user who resolved the ticket

=head2 resolved_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date and time this ticket was resolved

=head2 biblio_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

id of biblio linked

=head2 verify_uuid

  data_type: 'varchar'
  is_nullable: 1
  size: 128

a unique string for verifying an anonymous ticket

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "source",
  {
    data_type => "enum",
    default_value => "catalog",
    extra => { list => ["catalog"] },
    is_nullable => 0,
  },
  "reporter_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "reporter_email",
  { data_type => "longtext", is_nullable => 1 },
  "reported_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "title",
  { data_type => "text", is_nullable => 0 },
  "body",
  { data_type => "text", is_nullable => 0 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "assignee_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "resolver_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "resolved_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "biblio_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "verify_uuid",
  { data_type => "varchar", is_nullable => 1, size => 128 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<ticket_uuid_uniq>

=over 4

=item * L</verify_uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("ticket_uuid_uniq", ["verify_uuid"]);

=head1 RELATIONS

=head2 assignee

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "assignee",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "assignee_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 biblio

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
  "biblio",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblio_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 reporter

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "reporter",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "reporter_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 resolver

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "resolver",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "resolver_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 ticket_updates

Type: has_many

Related object: L<Koha::Schema::Result::TicketUpdate>

=cut

__PACKAGE__->has_many(
  "ticket_updates",
  "Koha::Schema::Result::TicketUpdate",
  { "foreign.ticket_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-10-15 13:33:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BJkIX8C/vppGV40wen9ILQ


__PACKAGE__->has_many(
  "updates",
  "Koha::Schema::Result::TicketUpdate",
  { "foreign.ticket_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

1;
