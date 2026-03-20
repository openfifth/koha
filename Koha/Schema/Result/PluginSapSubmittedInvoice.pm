use utf8;
package Koha::Schema::Result::PluginSapSubmittedInvoice;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::PluginSapSubmittedInvoice

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<plugin_sap_submitted_invoices>

=cut

__PACKAGE__->table("plugin_sap_submitted_invoices");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 invoicenumber

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 submitted_at

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 submitted_by

  data_type: 'varchar'
  default_value: 'cron'
  is_nullable: 0
  size: 255

=head2 filename

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "invoicenumber",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "submitted_at",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "submitted_by",
  {
    data_type => "varchar",
    default_value => "cron",
    is_nullable => 0,
    size => 255,
  },
  "filename",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_invoicenumber>

=over 4

=item * L</invoicenumber>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_invoicenumber", ["invoicenumber"]);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2026-03-05 11:19:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cZJJs5KDNmsHgxEi2UQQNw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
