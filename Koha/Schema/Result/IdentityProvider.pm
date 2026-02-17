use utf8;
package Koha::Schema::Result::IdentityProvider;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IdentityProvider

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<identity_providers>

=cut

__PACKAGE__->table("identity_providers");

=head1 ACCESSORS

=head2 identity_provider_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique key, used to identify the provider

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 20

Provider code

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 255

Description for the provider

=head2 protocol

  data_type: 'enum'
  extra: {list => ["OAuth","OIDC","LDAP","CAS","SAML2"]}
  is_nullable: 0

Protocol provider speaks

=head2 config

  data_type: 'longtext'
  is_nullable: 0

Configuration of the provider in JSON format

=head2 icon_url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

Provider icon URL

=head2 force_sso_opac

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Force SSO redirect for OPAC users

=head2 force_sso_staff

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Force SSO redirect for staff interface users

=head2 enabled

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

Whether this provider is active

=cut

__PACKAGE__->add_columns(
  "identity_provider_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "protocol",
  {
    data_type => "enum",
    extra => { list => ["OAuth", "OIDC", "LDAP", "CAS", "SAML2"] },
    is_nullable => 0,
  },
  "config",
  { data_type => "longtext", is_nullable => 0 },
  "icon_url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "force_sso_opac",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "force_sso_staff",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "enabled",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</identity_provider_id>

=back

=cut

__PACKAGE__->set_primary_key("identity_provider_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<code>

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->add_unique_constraint("code", ["code"]);

=head1 RELATIONS

=head2 identity_provider_domains

Type: has_many

Related object: L<Koha::Schema::Result::IdentityProviderDomain>

=cut

__PACKAGE__->has_many(
  "identity_provider_domains",
  "Koha::Schema::Result::IdentityProviderDomain",
  { "foreign.identity_provider_id" => "self.identity_provider_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-11-10 13:01:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xSD/bRC3hJCF+nP/EYwn3Q

__PACKAGE__->has_many(
  "domains",
  "Koha::Schema::Result::IdentityProviderDomain",
  { "foreign.identity_provider_id" => "self.identity_provider_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "identity_provider_mappings",
  "Koha::Schema::Result::IdentityProviderMapping",
  { "foreign.identity_provider_id" => "self.identity_provider_id" },
  { cascade_copy => 0, cascade_delete => 1 },
);

__PACKAGE__->has_many(
  "identity_provider_hostnames",
  "Koha::Schema::Result::IdentityProviderHostname",
  { "foreign.identity_provider_id" => "self.identity_provider_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "hostnames",
  "Koha::Schema::Result::IdentityProviderHostname",
  { "foreign.identity_provider_id" => "self.identity_provider_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->add_columns(
    '+force_sso_opac'  => { is_boolean => 1 },
    '+force_sso_staff' => { is_boolean => 1 },
    '+enabled'         => { is_boolean => 1 },
);

=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::Auth::Identity::Provider';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::Auth::Identity::Providers';
}

1;
