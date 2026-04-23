use utf8;
package Koha::Schema::Result::AcqOrderlineFundDistribution;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqOrderlineFundDistribution

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_orderline_fund_distributions>

=cut

__PACKAGE__->table("acq_orderline_fund_distributions");

=head1 ACCESSORS

=head2 orderline_fund_distribution_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 orderline_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

orderline the distribution was made by

=head2 fund_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

fund the distribution was made against

=head2 percentage

  data_type: 'decimal'
  is_nullable: 1
  size: [5,2]

distribution percentage

=head2 distributed_amount_oc

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distribution amount in the original currency

=head2 exchange_rate

  data_type: 'decimal'
  is_nullable: 0
  size: [20,10]

exchange rate for the distribution

=head2 distributed_amount

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distribution amount in the active currency

=head2 tax_rate

  data_type: 'decimal'
  is_nullable: 0
  size: [6,4]

tax rate on ordering

=head2 tax_value

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

tax value on ordering

=head2 distributed_amount_tax_excluded

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distributed amount minus tax

=head2 distributed_amount_tax_included

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

distributed amount including tax

=cut

__PACKAGE__->add_columns(
  "orderline_fund_distribution_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "orderline_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "percentage",
  { data_type => "decimal", is_nullable => 1, size => [5, 2] },
  "distributed_amount_oc",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "exchange_rate",
  { data_type => "decimal", is_nullable => 0, size => [20, 10] },
  "distributed_amount",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "tax_rate",
  { data_type => "decimal", is_nullable => 0, size => [6, 4] },
  "tax_value",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distributed_amount_tax_excluded",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "distributed_amount_tax_included",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
);

=head1 PRIMARY KEY

=over 4

=item * L</orderline_fund_distribution_id>

=back

=cut

__PACKAGE__->set_primary_key("orderline_fund_distribution_id");

=head1 RELATIONS

=head2 orderline

Type: belongs_to

Related object: L<Koha::Schema::Result::AcqOrderline>

=cut

__PACKAGE__->belongs_to(
  "orderline",
  "Koha::Schema::Result::AcqOrderline",
  { orderline_id => "orderline_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-04-23 09:49:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jRr2c3AZ0qJ6NCmgI0YAWQ


=head2 koha_object_class

=cut

sub koha_object_class {
    'Koha::Acquisition::OrderManagement::OrderlineFundDistribution';
}

=head2 koha_objects_class

=cut

sub koha_objects_class {
    'Koha::Acquisition::OrderManagement::OrderlineFundDistributions';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
