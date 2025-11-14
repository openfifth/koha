use utf8;
package Koha::Schema::Result::AcqOrderlineUser;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcqOrderlineUser

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<acq_orderline_users>

=cut

__PACKAGE__->table("acq_orderline_users");

=head1 ACCESSORS

=head2 orderline_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

orderline the user is for

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

the user

=cut

__PACKAGE__->add_columns(
  "orderline_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</orderline_id>

=item * L</borrowernumber>

=back

=cut

__PACKAGE__->set_primary_key("orderline_id", "borrowernumber");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-11-14 11:14:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sMwGs3qRYL3/ekJXyQi7sw


=head2 koha_object_class

=cut

sub koha_object_class {
    'Koha::Acquisition::OrderManagement::OrderlineUser';
}

=head2 koha_objects_class

=cut

sub koha_objects_class {
    'Koha::Acquisition::OrderManagement::OrderlineUsers';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
