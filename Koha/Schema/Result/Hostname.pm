use utf8;
package Koha::Schema::Result::Hostname;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Hostname - Canonical hostname registry for identity provider selection

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<hostnames>

=cut

__PACKAGE__->table("hostnames");

=head1 ACCESSORS

=head2 hostname_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Unique identifier for this hostname

=head2 hostname

  data_type: 'varchar'
  is_nullable: 0
  size: 255

Server hostname string; use * as a wildcard matching any hostname

=cut

__PACKAGE__->add_columns(
  "hostname_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "hostname",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</hostname_id>

=back

=cut

__PACKAGE__->set_primary_key("hostname_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<hostname>

=over 4

=item * L</hostname>

=back

=cut

__PACKAGE__->add_unique_constraint("hostname", ["hostname"]);

=head1 RELATIONS

=head2 identity_provider_hostnames

Type: has_many

Related object: L<Koha::Schema::Result::IdentityProviderHostname>

=cut

__PACKAGE__->has_many(
  "identity_provider_hostnames",
  "Koha::Schema::Result::IdentityProviderHostname",
  { "foreign.hostname_id" => "self.hostname_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-27 13:06:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:e5JUPRXeKJcN4w/fJujVZg

__PACKAGE__->meta->make_immutable;

1;
