use utf8;
package Koha::Schema::Result::AcqFiscalPeriod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqFiscalPeriod

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_fiscal_period>

=cut

__PACKAGE__->table("acq_fiscal_period");

=head1 ACCESSORS

=head2 fiscal_period_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

name for the fiscal period

=head2 description

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

description for the fiscal period

=head2 start_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

start date of the event

=head2 end_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

end date of the event

=head2 status

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the fiscal period currently active

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the fiscal period

=head2 managing_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch responsible

=head2 created_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the creation to the fiscal period

=head2 modified_date

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the last update to the fiscal period

=cut

__PACKAGE__->add_columns(
  "fiscal_period_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "description",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "start_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "end_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "status",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "owner_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "managing_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
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

=item * L</fiscal_period_id>

=back

=cut

__PACKAGE__->set_primary_key("fiscal_period_id");

=head1 RELATIONS

=head2 acq_funds

Type: has_many

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->has_many(
  "acq_funds",
  "Koha::Schema::Result::AcqFund",
  { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 acq_ledgers

Type: has_many

Related object: L<Koha::Schema::Result::AcqLedger>

=cut

__PACKAGE__->has_many(
  "acq_ledgers",
  "Koha::Schema::Result::AcqLedger",
  { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
  { cascade_copy => 0, cascade_delete => 0 },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U658BX26MIEwsamsK7VB6Q

__PACKAGE__->add_columns(
    '+status' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::FiscalPeriod';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::FiscalPeriods';
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


=head2 ledgers

Type: has_many

Related object: L<Koha::Schema::Result::AcqLedger>

=cut

__PACKAGE__->has_many(
    "ledgers",
    "Koha::Schema::Result::AcqLedger",
    { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
    { cascade_copy               => 0, cascade_delete => 0 },
);


=head2 funds

Type: has_many

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->has_many(
    "funds",
    "Koha::Schema::Result::AcqFund",
    { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
    { cascade_copy               => 0, cascade_delete => 0 },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
