use utf8;
package Koha::Schema::Result::Iso18626Message;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Iso18626Message

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<iso18626_messages>

=cut

__PACKAGE__->table("iso18626_messages");

=head1 ACCESSORS

=head2 iso18626_message_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Internal message number

=head2 iso18626_request_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Associated ISO18626 request (when this Koha is the supplying agency)

=head2 illrequest_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

Associated ILL request (when this Koha is the requesting agency)

=head2 content

  data_type: 'mediumtext'
  is_nullable: 0

Message content (XML)

=head2 type

  data_type: 'enum'
  extra: {list => ["request","requestConfirmation","supplyingAgencyMessage","supplyingAgencyMessageConfirmation","requestingAgencyMessage","requestingAgencyMessageConfirmation"]}
  is_nullable: 0

ISO18626 message type

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "iso18626_message_id",
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
  "content",
  { data_type => "mediumtext", is_nullable => 0 },
  "type",
  {
    data_type => "enum",
    extra => {
      list => [
        "request",
        "requestConfirmation",
        "supplyingAgencyMessage",
        "supplyingAgencyMessageConfirmation",
        "requestingAgencyMessage",
        "requestingAgencyMessageConfirmation",
      ],
    },
    is_nullable => 0,
  },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</iso18626_message_id>

=back

=cut

__PACKAGE__->set_primary_key("iso18626_message_id");

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


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-11-19 15:05:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F5PwRW3kLPAgvf6WYs9cDQ

=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::ILL::ISO18626::Message';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ILL::ISO18626::Messages';
}

1;
