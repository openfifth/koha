use utf8;
package Koha::Schema::Result::Iso18626RequestingAgency;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Iso18626RequestingAgency

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<iso18626_requesting_agencies>

=cut

__PACKAGE__->table("iso18626_requesting_agencies");

=head1 ACCESSORS

=head2 iso18626_requesting_agency_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Internal requesting agency number

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

Requesting agency name

=head2 type

  data_type: 'enum'
  extra: {list => ["DNUCNI","ICOLC","ISIL"]}
  is_nullable: 0

ISO18626 agency type

=head2 account_id

  data_type: 'varchar'
  is_nullable: 0
  size: 80

Authentication: Requesting agency account ID

=head2 securityCode

  accessor: 'security_code'
  data_type: 'varchar'
  is_nullable: 0
  size: 80

Authentication: Requesting agency security code

=head2 callback_endpoint

  data_type: 'mediumtext'
  is_nullable: 0

Callback endpoint to send messages back to

=cut

__PACKAGE__->add_columns(
  "iso18626_requesting_agency_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["DNUCNI", "ICOLC", "ISIL"] },
    is_nullable => 0,
  },
  "account_id",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "securityCode",
  {
    accessor => "security_code",
    data_type => "varchar",
    is_nullable => 0,
    size => 80,
  },
  "callback_endpoint",
  { data_type => "mediumtext", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</iso18626_requesting_agency_id>

=back

=cut

__PACKAGE__->set_primary_key("iso18626_requesting_agency_id");


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-09-29 13:49:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OnDp91ihqsZ19zL04yzWVw

=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::ILL::ISO18626::RequestingAgency';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ILL::ISO18626::RequestingAgencies';
}

1;
