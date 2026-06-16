use utf8;
package Koha::Schema::Result::AqvendorAllocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AqvendorAllocation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aqvendor_allocations>

=cut

__PACKAGE__->table("aqvendor_allocations");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 budget_period_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

budget period this allocation applies to (aqbudgetperiods.budget_period_id)

=head2 booksellerid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

vendor this allocation applies to (aqbooksellers.id)

=head2 allocation_amount

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 0
  size: [28,6]

maximum spend allowed for this vendor in this budget period

=head2 warn_at_percentage

  data_type: 'decimal'
  default_value: 0.0000
  is_nullable: 1
  size: [6,4]

warn when spend reaches this percentage of allocation_amount

=head2 warn_at_amount

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 1
  size: [28,6]

warn when spend reaches this fixed amount

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "budget_period_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "booksellerid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation_amount",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 0,
    size => [28, 6],
  },
  "warn_at_percentage",
  {
    data_type => "decimal",
    default_value => "0.0000",
    is_nullable => 1,
    size => [6, 4],
  },
  "warn_at_amount",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 1,
    size => [28, 6],
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uq_vendor_period>

=over 4

=item * L</budget_period_id>

=item * L</booksellerid>

=back

=cut

__PACKAGE__->add_unique_constraint("uq_vendor_period", ["budget_period_id", "booksellerid"]);

=head1 RELATIONS

=head2 booksellerid

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqbookseller>

=cut

__PACKAGE__->belongs_to(
  "booksellerid",
  "Koha::Schema::Result::Aqbookseller",
  { id => "booksellerid" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 budget_period

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqbudgetperiod>

=cut

__PACKAGE__->belongs_to(
  "budget_period",
  "Koha::Schema::Result::Aqbudgetperiod",
  { budget_period_id => "budget_period_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-06-16 10:45:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:alekPod9f0J0m5TD6I/ZhQ


sub koha_object_class  { 'Koha::Acquisition::VendorAllocation'; }
sub koha_objects_class { 'Koha::Acquisition::VendorAllocations'; }

1;
