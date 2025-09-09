use utf8;
package Koha::Schema::Result::Iso18626Request;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Iso18626Request

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<iso18626_requests>

=cut

__PACKAGE__->table("iso18626_requests");

=head1 ACCESSORS

=head2 iso18626_request_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

Internal request number

=head2 supplyingAgencyId

  accessor: 'supplying_agency_id'
  data_type: 'varchar'
  is_nullable: 1
  size: 80

Supplying agency ID

=head2 requestingAgencyId

  accessor: 'requesting_agency_id'
  data_type: 'varchar'
  is_nullable: 1
  size: 80

Requesting agency ID

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

Date and time when the request was made

=head2 requestingAgencyRequestId

  accessor: 'requesting_agency_request_id'
  data_type: 'varchar'
  is_nullable: 1
  size: 80

Requesting agency request ID or number

=head2 status

  data_type: 'enum'
  default_value: 'RequestReceived'
  extra: {list => ["RequestReceived","ExpectToSupply","WillSupply","Loaned","Overdue","Recalled","RetryPossible","Unfilled","HoldReturn","ReleaseHoldReturn","CopyCompleted","LoanCompleted","CompletedWithoutReturn","Cancelled"]}
  is_nullable: 1

Current ISO18626 status of request

=head2 service_type

  data_type: 'enum'
  extra: {list => ["Copy","Loan","CopyOrLoan"]}
  is_nullable: 0

ISO18626 service type

=head2 pending_requesting_agency_action

  data_type: 'enum'
  extra: {list => ["Cancel","Renew"]}
  is_nullable: 1

ISO18626 Requesting Agency action that requires a manual response (yes or no)

=cut

__PACKAGE__->add_columns(
  "iso18626_request_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "supplyingAgencyId",
  {
    accessor => "supplying_agency_id",
    data_type => "varchar",
    is_nullable => 1,
    size => 80,
  },
  "requestingAgencyId",
  {
    accessor => "requesting_agency_id",
    data_type => "varchar",
    is_nullable => 1,
    size => 80,
  },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "requestingAgencyRequestId",
  {
    accessor => "requesting_agency_request_id",
    data_type => "varchar",
    is_nullable => 1,
    size => 80,
  },
  "status",
  {
    data_type => "enum",
    default_value => "RequestReceived",
    extra => {
      list => [
        "RequestReceived",
        "ExpectToSupply",
        "WillSupply",
        "Loaned",
        "Overdue",
        "Recalled",
        "RetryPossible",
        "Unfilled",
        "HoldReturn",
        "ReleaseHoldReturn",
        "CopyCompleted",
        "LoanCompleted",
        "CompletedWithoutReturn",
        "Cancelled",
      ],
    },
    is_nullable => 1,
  },
  "service_type",
  {
    data_type => "enum",
    extra => { list => ["Copy", "Loan", "CopyOrLoan"] },
    is_nullable => 0,
  },
  "pending_requesting_agency_action",
  {
    data_type => "enum",
    extra => { list => ["Cancel", "Renew"] },
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</iso18626_request_id>

=back

=cut

__PACKAGE__->set_primary_key("iso18626_request_id");

=head1 RELATIONS

=head2 iso18626_messages

Type: has_many

Related object: L<Koha::Schema::Result::Iso18626Message>

=cut

__PACKAGE__->has_many(
  "iso18626_messages",
  "Koha::Schema::Result::Iso18626Message",
  { "foreign.iso18626_request_id" => "self.iso18626_request_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-09-29 14:10:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zWLywEK6ZHpEzSE14b3Apg

=head2 koha_object_class

Missing POD for koha_object_class.

=cut

sub koha_object_class {
    'Koha::ILL::ISO18626::Request';
}

=head2 koha_objects_class

Missing POD for koha_objects_class.

=cut

sub koha_objects_class {
    'Koha::ILL::ISO18626::Requests';
}

1;
