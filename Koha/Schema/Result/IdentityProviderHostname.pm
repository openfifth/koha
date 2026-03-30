use utf8;
package Koha::Schema::Result::IdentityProviderHostname;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IdentityProviderHostname

=head1 DESCRIPTION

Maps server hostnames to identity providers (many-to-many). A hostname may be linked to multiple providers.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<identity_provider_hostnames>

=cut

__PACKAGE__->table("identity_provider_hostnames");

=head1 ACCESSORS

=head2 identity_provider_hostname_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique key, used to identify the hostname entry

=head2 hostname_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

FK to hostnames table

=head2 identity_provider_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Identity provider associated with this hostname

=head2 is_enabled

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

Whether this hostname is active for this provider

=head2 is_exclusive

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Exclusive provider for this hostname; suppress all other auth methods

=head2 matchpoint

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Koha field used to match incoming users against existing patrons

=cut

__PACKAGE__->add_columns(
  "identity_provider_hostname_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "hostname_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "identity_provider_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_enabled",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "is_exclusive",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "matchpoint",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</identity_provider_hostname_id>

=back

=cut

__PACKAGE__->set_primary_key("identity_provider_hostname_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<hostname_id_provider>

=over 4

=item * L</hostname_id>

=item * L</identity_provider_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "hostname_id_provider",
  ["hostname_id", "identity_provider_id"],
);

=head1 RELATIONS

=head2 hostname

Type: belongs_to

Related object: L<Koha::Schema::Result::Hostname>

=cut

__PACKAGE__->belongs_to(
  "hostname",
  "Koha::Schema::Result::Hostname",
  { hostname_id => "hostname_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ECreELIyUuT+mfPkkaxt/g

__PACKAGE__->meta->make_immutable;

1;
