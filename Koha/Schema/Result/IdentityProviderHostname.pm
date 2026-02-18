use utf8;
package Koha::Schema::Result::IdentityProviderHostname;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IdentityProviderHostname

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

=head2 hostname

  data_type: 'varchar'
  is_nullable: 0
  size: 255

Server hostname (matches SERVER_NAME) used for automatic provider selection

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

=head2 force_sso_opac

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Force SSO redirect for OPAC users on this hostname

=head2 force_sso_staff

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Force SSO redirect for staff interface users on this hostname

=cut

__PACKAGE__->add_columns(
  "identity_provider_hostname_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "hostname",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "identity_provider_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_enabled",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "force_sso_opac",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "force_sso_staff",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</identity_provider_hostname_id>

=back

=cut

__PACKAGE__->set_primary_key("identity_provider_hostname_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<hostname_provider>

=over 4

=item * L</hostname>

=item * L</identity_provider_id>

=back

=cut

__PACKAGE__->add_unique_constraint("hostname_provider", ["hostname", "identity_provider_id"]);

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2026-02-17 00:00:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:placeholder

__PACKAGE__->add_columns(
    '+is_enabled'      => { is_boolean => 1 },
    '+force_sso_opac'  => { is_boolean => 1 },
    '+force_sso_staff' => { is_boolean => 1 },
);

sub koha_object_class  { 'Koha::Auth::Identity::Provider::Hostname' }
sub koha_objects_class { 'Koha::Auth::Identity::Provider::Hostnames' }

1;
