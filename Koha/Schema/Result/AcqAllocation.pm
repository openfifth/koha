use utf8;
package Koha::Schema::Result::AcqAllocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqAllocation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_allocations>

=cut

__PACKAGE__->table("acq_allocations");

=head1 ACCESSORS

=head2 allocation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 fund_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

fund the allocation applies to

=head2 ledger_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

ledger the allocation applies to

=head2 allocation_amount

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

amount for the allocation

=head2 is_transferred_to

  data_type: 'integer'
  is_nullable: 1

entity making the allocation

=head2 is_transferred_from

  data_type: 'integer'
  is_nullable: 1

entity receiving the allocation

=head2 type

  data_type: 'enum'
  extra: {list => ["increase","decrease","transfer"]}
  is_nullable: 0

type of the allocation

=head2 reference

  data_type: 'varchar'
  is_nullable: 1
  size: 255

allocation reference

=head2 note

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

any notes associated to the allocation

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

when the allocation was made

=cut

__PACKAGE__->add_columns(
  "allocation_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ledger_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "allocation_amount",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "is_transferred_to",
  { data_type => "integer", is_nullable => 1 },
  "is_transferred_from",
  { data_type => "integer", is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["increase", "decrease", "transfer"] },
    is_nullable => 0,
  },
  "reference",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "note",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "created_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</allocation_id>

=back

=cut

__PACKAGE__->set_primary_key("allocation_id");

=head1 RELATIONS

=head2 fund

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->belongs_to(
  "fund",
  "Koha::Schema::Result::AcqFund",
  { fund_id => "fund_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 ledger

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqLedger>

=cut

__PACKAGE__->belongs_to(
  "ledger",
  "Koha::Schema::Result::AcqLedger",
  { ledger_id => "ledger_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-25 15:23:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xT/Mkk+eFCga4WE1OO1UIQ

sub koha_object_class {
    'Koha::Acquisition::FundManagement::Allocation';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::Allocations';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
