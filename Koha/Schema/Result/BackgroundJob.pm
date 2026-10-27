use utf8;
package Koha::Schema::Result::BackgroundJob;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::BackgroundJob

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<background_jobs>

=cut

__PACKAGE__->table("background_jobs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 progress

  data_type: 'integer'
  is_nullable: 1

=head2 size

  data_type: 'integer'
  is_nullable: 1

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 queue

  data_type: 'varchar'
  default_value: 'default'
  is_nullable: 0
  size: 191

Name of the queue the job is sent to

=head2 data

  data_type: 'longtext'
  is_nullable: 1

=head2 context

  data_type: 'longtext'
  is_nullable: 1

JSON-serialized context information for the job

=head2 enqueued_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 started_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 ended_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "progress",
  { data_type => "integer", is_nullable => 1 },
  "size",
  { data_type => "integer", is_nullable => 1 },
  "borrowernumber",
  { data_type => "integer", is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "queue",
  {
    data_type => "varchar",
    default_value => "default",
    is_nullable => 0,
    size => 191,
  },
  "data",
  { data_type => "longtext", is_nullable => 1 },
  "context",
  { data_type => "longtext", is_nullable => 1 },
  "enqueued_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "started_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "ended_on",
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

=head2 erm_counter_logs

Type: has_many

Related object: L<Koha::Schema::Result::ErmCounterLog>

=cut

__PACKAGE__->has_many(
  "erm_counter_logs",
  "Koha::Schema::Result::ErmCounterLog",
  { "foreign.background_job_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-10-20 13:59:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vMYfq8Gram44XnVPbeCauw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
