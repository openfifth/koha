use utf8;
package Koha::Schema::Result::AcqFund;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqFund

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_funds>

=cut

__PACKAGE__->table("acq_funds");

=head1 ACCESSORS

=head2 fund_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 fund_parent_id

  data_type: 'integer'
  is_nullable: 1

if this fund is a child of another the parent fund id will be stored here

=head2 ledger_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

ledger the fund applies to

=head2 fiscal_period_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

fiscal period the fund applies to

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

name for the fund

=head2 code

  data_type: 'varchar'
  is_nullable: 1
  size: 30

code for the fund

=head2 description

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

description for the fund

=head2 external_id

  data_type: 'varchar'
  is_nullable: 1
  size: 255

external id for the fund for use with external accounting systems

=head2 status

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the fund currently active

=head2 fund_type

  data_type: 'varchar'
  is_nullable: 1
  size: 255

type for the fund

=head2 fund_amount

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

spend limit for the fund

=head2 managing_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch responsible

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the fund

=head2 fund_permission

  data_type: 'integer'
  is_nullable: 1

level of permission for this fund

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

limit for overencumbrance

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the creation of the fund

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the last update to the fund

=cut

__PACKAGE__->add_columns(
  "fund_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "fund_parent_id",
  { data_type => "integer", is_nullable => 1 },
  "ledger_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "fiscal_period_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "code",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "description",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "external_id",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "status",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "fund_type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fund_amount",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "managing_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "owner_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fund_permission",
  { data_type => "integer", is_nullable => 1 },
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

=item * L</fund_id>

=back

=cut

__PACKAGE__->set_primary_key("fund_id");

=head1 RELATIONS

=head2 acq_allocations

Type: has_many

Related object: L<Koha::Schema::Result::AcqAllocation>

=cut

__PACKAGE__->has_many(
  "acq_allocations",
  "Koha::Schema::Result::AcqAllocation",
  { "foreign.fund_id" => "self.fund_id" },
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 ledger

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqLedger>

=cut

__PACKAGE__->belongs_to(
  "ledger",
  "Koha::Schema::Result::AcqLedger",
  { ledger_id => "ledger_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-04-13 15:39:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SGDmuQJFOnTTU7dqut9iww

__PACKAGE__->add_columns(
    '+status'             => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::Fund';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::Funds';
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

=head2 parent_fund

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->belongs_to(
    "parent_fund",
    "Koha::Schema::Result::AcqFund",
    { fund_id => "fund_parent_id" },
    {
        is_deferrable => 1,
        join_type     => "LEFT",
        on_delete     => "CASCADE",
        on_update     => "CASCADE",
    },
);


=head2 allocations

Type: has_many

Related object: L<Koha::Schema::Result::AcqAllocation>

=cut

__PACKAGE__->has_many(
    "allocations",
    "Koha::Schema::Result::AcqAllocation",
    { "foreign.fund_id" => "self.fund_id" },
    { cascade_copy      => 0, cascade_delete => 0 },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
