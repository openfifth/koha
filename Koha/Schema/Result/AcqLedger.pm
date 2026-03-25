use utf8;
package Koha::Schema::Result::AcqLedger;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqLedger

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_ledgers>

=cut

__PACKAGE__->table("acq_ledgers");

=head1 ACCESSORS

=head2 ledger_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 fiscal_period_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

fiscal period the ledger applies to

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 80

name for the ledger

=head2 description

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

description for the ledger

=head2 external_id

  data_type: 'varchar'
  is_nullable: 1
  size: 255

external id for the ledger for use with external accounting systems

=head2 status

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the ledger currently active

=head2 locked

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the ledger currently locked

=head2 currency

  data_type: 'varchar'
  is_nullable: 0
  size: 10

currency of the ledger

=head2 ledger_amount

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 0
  size: [28,2]

spend limit for the ledger

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the ledger

=head2 managing_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch responsible

=head2 oe_warning_percent

  data_type: 'decimal'
  default_value: 0.0000
  is_nullable: 1
  size: [5,4]

percentage limit for overencumbrance

=head2 oe_warning_amount

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

warning limit for overencumbrance

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the creation of the ledger

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the last update to the ledger

=cut

__PACKAGE__->add_columns(
  "ledger_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "fiscal_period_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 80 },
  "description",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "external_id",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "status",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "locked",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "currency",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "ledger_amount",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 0,
    size => [28, 2],
  },
  "owner_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "managing_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "oe_warning_percent",
  {
    data_type => "decimal",
    default_value => "0.0000",
    is_nullable => 1,
    size => [5, 4],
  },
  "oe_warning_amount",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "created_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "modified_date",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</ledger_id>

=back

=cut

__PACKAGE__->set_primary_key("ledger_id");

=head1 RELATIONS

=head2 acq_allocations

Type: has_many

Related object: L<Koha::Schema::Result::AcqAllocation>

=cut

__PACKAGE__->has_many(
  "acq_allocations",
  "Koha::Schema::Result::AcqAllocation",
  { "foreign.ledger_id" => "self.ledger_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_funds

Type: has_many

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->has_many(
  "acq_funds",
  "Koha::Schema::Result::AcqFund",
  { "foreign.ledger_id" => "self.ledger_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 fiscal_period

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqFiscalPeriod>

=cut

__PACKAGE__->belongs_to(
  "fiscal_period",
  "Koha::Schema::Result::AcqFiscalPeriod",
  { fiscal_period_id => "fiscal_period_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 managing_branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "managing_branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "managing_branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 owner

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "owner",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "owner_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-25 15:23:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NPW0TnK8e9lyZeWbX1OrKA

__PACKAGE__->add_columns(
    '+status'             => { is_boolean => 1 },
    '+locked'             => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::Ledger';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::Ledgers';
}

=head2 managing_library

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
    "managing_library",
    "Koha::Schema::Result::Branch",
    { branchcode => "managing_branch" },
    {
        is_deferrable => 1,
        join_type     => "LEFT",
        on_delete     => "CASCADE",
        on_update     => "CASCADE",
    },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
