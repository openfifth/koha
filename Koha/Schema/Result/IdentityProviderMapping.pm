use utf8;
package Koha::Schema::Result::IdentityProviderMapping;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IdentityProviderMapping

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<identity_provider_mappings>

=cut

__PACKAGE__->table("identity_provider_mappings");

=head1 ACCESSORS

=head2 mapping_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 identity_provider_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Reference to identity provider

=head2 provider_field

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Attribute name from the identity provider

=head2 koha_field

  data_type: 'varchar'
  is_nullable: 0
  size: 255

Corresponding field in Koha borrowers table

=head2 default_content

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Default value if provider does not supply this field

=cut

__PACKAGE__->add_columns(
  "mapping_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "identity_provider_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "provider_field",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "koha_field",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "default_content",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</mapping_id>

=back

=cut

__PACKAGE__->set_primary_key("mapping_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<provider_koha_field>

=over 4

=item * L</identity_provider_id>

=item * L</koha_field>

=back

=cut

__PACKAGE__->add_unique_constraint("provider_koha_field", ["identity_provider_id", "koha_field"]);

=head1 RELATIONS

=head2 identity_provider

Type: belongs_to

Related object: L<Koha::Schema::Result::IdentityProvider>

=cut

__PACKAGE__->belongs_to(
  "identity_provider",
  "Koha::Schema::Result::IdentityProvider",
  { identity_provider_id => "identity_provider_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-27 13:06:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ive23RE9M+0WTjXJPjm5Cw

=head2 koha_object_class

Missing POD for koha_object_class.

=cut


sub koha_object_class  { 'Koha::Auth::Identity::Provider::Mapping' }

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class { 'Koha::Auth::Identity::Provider::Mappings' }

1;
