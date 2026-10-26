use utf8;
package Koha::Schema::Result::IllDocument;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IllDocument

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ill_documents>

=cut

__PACKAGE__->table("ill_documents");

=head1 ACCESSORS

=head2 ill_document_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Internal document number

=head2 iso18626_request_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Associated ISO18626 request, for documents supplied to other libraries

=head2 illrequest_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

Associated ILL request, for documents delivered to patrons

=head2 file_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

File name

=head2 file_type

  data_type: 'varchar'
  is_nullable: 0
  size: 255

MIME type of the file

=head2 file_content

  data_type: 'longblob'
  is_nullable: 0

File content

=head2 token

  data_type: 'varchar'
  is_nullable: 0
  size: 36

Unique token used to download the document without authentication

=head2 uploaded_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

Date and time the document was uploaded

=head2 downloaded_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

Date and time the document was first downloaded by the patron

=head2 download_count

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Number of times the document was downloaded by the patron

=cut

__PACKAGE__->add_columns(
  "ill_document_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "iso18626_request_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "illrequest_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "file_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "file_type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "file_content",
  { data_type => "longblob", is_nullable => 0 },
  "token",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "uploaded_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "downloaded_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "download_count",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</ill_document_id>

=back

=cut

__PACKAGE__->set_primary_key("ill_document_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<token>

=over 4

=item * L</token>

=back

=cut

__PACKAGE__->add_unique_constraint("token", ["token"]);

=head1 RELATIONS

=head2 illrequest

Type: belongs_to

Related object: L<Koha::Schema::Result::Illrequest>

=cut

__PACKAGE__->belongs_to(
  "illrequest",
  "Koha::Schema::Result::Illrequest",
  { illrequest_id => "illrequest_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 iso18626_request

Type: belongs_to

Related object: L<Koha::Schema::Result::Iso18626Request>

=cut

__PACKAGE__->belongs_to(
  "iso18626_request",
  "Koha::Schema::Result::Iso18626Request",
  { iso18626_request_id => "iso18626_request_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-10-26 16:42:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7yNmSdUZw3ye3h2A1NzaWA


=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::ILL::Document';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ILL::Documents';
}

1;
