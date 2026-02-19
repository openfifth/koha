package Koha::REST::V1::Patrons::SelfRenewal;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Patrons;
use Koha::Patron::Attribute::Types;

use Try::Tiny qw( catch try );
use JSON      qw( to_json );

=head1 NAME

Koha::REST::V1::Patrons::SelfRenewal

=head1 API

=head2 Methods

=head3 start

Controller function that retrieves the metadata required to begin a patron self renewal

=cut

sub start {
    my $c = shift->openapi->valid_input or return;

    my $patron = Koha::Patrons->find( $c->param('patron_id') );

    return $c->render( status => 403, openapi => { error => "You are not eligible for self-renewal" } )
        if !$patron->is_eligible_for_self_renewal() || !$patron;

    return try {
        my $category              = $patron->category;
        my $self_renewal_settings = {
            self_renewal_failure_message     => $category->self_renewal_failure_message,
            self_renewal_information_message => $category->self_renewal_information_message,
            opac_patron_details              => C4::Context->preference('OPACPatronDetails')
        };

        return $c->render(
            status  => 200,
            openapi => { self_renewal_settings => $self_renewal_settings }
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 submit

Controller function that receives the renewal request and process the renewal

=cut

sub submit {
    my $c = shift->openapi->valid_input or return;

    my $patron = Koha::Patrons->find( $c->param('patron_id') );

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                my $body = $c->req->json;

                return $c->render( status => 403, openapi => { error => "You are not eligible for self-renewal" } )
                    if !$patron->is_eligible_for_self_renewal() || !$patron;

                my $OPACPatronDetails = C4::Context->preference("OPACPatronDetails");
                if ($OPACPatronDetails) {
                    my $patron_details      = $body->{patron};
                    my $extended_attributes = delete $patron_details->{extended_attributes};
                    my $changed_fields      = {};
                    my $changes_detected;
                    foreach my $key ( keys %$patron_details ) {
                        my $submitted_value = $patron_details->{$key};
                        my $original_value  = $patron->$key;

                        if ( $submitted_value ne $original_value ) {
                            $changed_fields->{$key} = $submitted_value;
                            $changes_detected++;
                        }
                    }
                    if ($changes_detected) {
                        $changed_fields->{changed_fields}      = join ',', keys %$changed_fields;
                        $changed_fields->{extended_attributes} = to_json($extended_attributes) if $extended_attributes;
                        $patron->request_modification($changed_fields);
                    }
                }

                my $new_expiry_date = $patron->renew_account;
                my $response        = { expiry_date => $new_expiry_date };

                if ($new_expiry_date) {
                    my $is_notice_mandatory = $patron->category->enforce_expiry_notice;
                    my $letter_params       = $patron->create_expiry_notice_parameters(
                        {
                            letter_code => "MEMBERSHIP_RENEWED", is_notice_mandatory => $is_notice_mandatory,
                            forceprint  => 1
                        }
                    );

                    my $result = $patron->queue_notice($letter_params);
                    $response->{confirmation_sent} = 1 if $result->{sent};
                }

                return $c->render(
                    status  => 201,
                    openapi => $response
                );
            }
        );

    } catch {
        $c->unhandled_exception($_);
    };

}

1;
