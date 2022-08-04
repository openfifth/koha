use utf8;
package Koha::Schema::Result::HoldGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::HoldGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<hold_groups>

=cut

__PACKAGE__->table("hold_groups");

=head1 ACCESSORS

=head2 hold_group_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "hold_group_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</hold_group_id>

=back

=cut

__PACKAGE__->set_primary_key("hold_group_id");

=head1 RELATIONS

=head2 old_reserves

Type: has_many

Related object: L<Koha::Schema::Result::OldReserve>

=cut

__PACKAGE__->has_many(
  "old_reserves",
  "Koha::Schema::Result::OldReserve",
  { "foreign.hold_group_id" => "self.hold_group_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 reserves

Type: has_many

Related object: L<Koha::Schema::Result::Reserve>

=cut

__PACKAGE__->has_many(
  "reserves",
  "Koha::Schema::Result::Reserve",
  { "foreign.hold_group_id" => "self.hold_group_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2022-08-04 14:43:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5Xzfn2C7H+Z8R9PUBPFkYw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
