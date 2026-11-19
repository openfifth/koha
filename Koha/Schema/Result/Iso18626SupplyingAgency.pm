use utf8;
package Koha::Schema::Result::Iso18626SupplyingAgency;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Iso18626SupplyingAgency

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<iso18626_supplying_agencies>

=cut

__PACKAGE__->table("iso18626_supplying_agencies");

=head1 ACCESSORS

=head2 iso18626_supplying_agency_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Internal supplying agency number

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

Supplying agency name

=head2 type

  data_type: 'enum'
  extra: {list => ["DNUCNI","ICOLC","ISIL"]}
  is_nullable: 0

ISO18626 agency ID type

=head2 agency_id

  data_type: 'varchar'
  is_nullable: 0
  size: 80

ISO18626 agency ID of the supplying agency

=head2 account_id

  data_type: 'varchar'
  is_nullable: 0
  size: 80

Authentication: account ID this Koha uses with the supplying agency

=head2 securityCode

  accessor: 'security_code'
  data_type: 'varchar'
  is_nullable: 0
  size: 80

Authentication: security code this Koha uses with the supplying agency

=head2 endpoint

  data_type: 'mediumtext'
  is_nullable: 0

ISO18626 endpoint of the supplying agency

=cut

__PACKAGE__->add_columns(
  "iso18626_supplying_agency_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["DNUCNI", "ICOLC", "ISIL"] },
    is_nullable => 0,
  },
  "agency_id",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "account_id",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "securityCode",
  {
    accessor => "security_code",
    data_type => "varchar",
    is_nullable => 0,
    size => 80,
  },
  "endpoint",
  { data_type => "mediumtext", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</iso18626_supplying_agency_id>

=back

=cut

__PACKAGE__->set_primary_key("iso18626_supplying_agency_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uniq_agency_id>

=over 4

=item * L</type>

=item * L</agency_id>

=back

=cut

__PACKAGE__->add_unique_constraint("uniq_agency_id", ["type", "agency_id"]);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-19 15:05:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BVhv8J8ucdaqPjQoFZMC8g


=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::ILL::ISO18626::SupplyingAgency';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ILL::ISO18626::SupplyingAgencies';
}

1;
