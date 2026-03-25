use utf8;
package Koha::Schema::Result::AcqFundGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqFundGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_fund_group>

=cut

__PACKAGE__->table("acq_fund_group");

=head1 ACCESSORS

=head2 fund_group_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

name for the fund group

=head2 currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency of the fund allocation

=head2 managing_branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

branch responsible

=cut

__PACKAGE__->add_columns(
  "fund_group_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "currency",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "managing_branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</fund_group_id>

=back

=cut

__PACKAGE__->set_primary_key("fund_group_id");

=head1 RELATIONS

=head2 acq_funds

Type: has_many

Related object: L<Koha::Schema::Result::AcqFund>

=cut

__PACKAGE__->has_many(
  "acq_funds",
  "Koha::Schema::Result::AcqFund",
  { "foreign.fund_group_id" => "self.fund_group_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-25 15:23:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GKmzsTfG4CWoPQ3rzmQMAQ

sub koha_object_class {
    'Koha::Acquisition::FundManagement::FundGroup';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::FundGroups';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
