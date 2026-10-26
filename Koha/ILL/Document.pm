package Koha::ILL::Document;

# Copyright Open Fifth 2026
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use MIME::Types;
use UUID;

use C4::Context;

use Koha::DateUtils qw( dt_from_string );
use Koha::Exceptions;
use Koha::ILL::Documents;

use base qw(Koha::Object);

=head1 NAME

Koha::ILL::Document - Koha ILL document Object class

=cut

=head2 Class methods

=head3 store

    my $document = Koha::ILL::Document->new( { ... } )->store;

Overloaded I<store> method. On creation, derives file_type from file_name when
not given and generates the download token.
Throws I<Koha::Exceptions::PayloadTooLarge> if the file exceeds the database's
max_allowed_packet.

=cut

sub store {
    my ($self) = @_;

    unless ( $self->in_storage ) {
        my $max_allowed_packet = C4::Context->dbh->selectrow_array(q{SELECT @@max_allowed_packet});
        Koha::Exceptions::PayloadTooLarge->throw("File size exceeds limit defined by server")
            if length( $self->file_content ) > $max_allowed_packet;

        unless ( $self->file_type ) {
            my $file_type = MIME::Types->new->mimeTypeOf( $self->file_name );
            $self->file_type( $file_type ? $file_type->type : 'application/octet-stream' );
        }

        $self->token( $self->_generate_unused_token );
    }

    return $self->SUPER::store;
}

=head3 record_download

    $document->record_download;

Record that the patron downloaded this document: sets downloaded_on on the first
download and increments download_count.

=cut

sub record_download {
    my ($self) = @_;

    $self->downloaded_on( dt_from_string() ) unless $self->downloaded_on;
    $self->download_count( $self->download_count + 1 );

    return $self->store;
}

=head3 to_api_mapping

=cut

sub to_api_mapping {
    return {
        file_content  => undef,
        illrequest_id => 'ill_request_id',
        token         => undef,
    };
}

=head2 Internal methods

=head3 _generate_unused_token

    my $token = $self->_generate_unused_token;

=cut

sub _generate_unused_token {
    my ($self) = @_;

    my ( $uuid, $uuidstring );

    UUID::generate($uuid);
    UUID::unparse( $uuid, $uuidstring );

    while ( Koha::ILL::Documents->search( { token => $uuidstring } )->count > 0 ) {
        UUID::generate($uuid);
        UUID::unparse( $uuid, $uuidstring );
    }

    return $uuidstring;
}

=head3 _type

=cut

sub _type {
    return 'IllDocument';
}

1;
