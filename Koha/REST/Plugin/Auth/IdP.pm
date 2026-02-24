package Koha::REST::Plugin::Auth::IdP;

# Copyright Theke Solutions 2022
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

use Mojo::Base 'Mojolicious::Plugin';

use Koha::Exceptions;
use Koha::Exceptions::Auth;
use Koha::Patron::Attribute;
use Koha::Patrons;

use C4::Auth    qw(create_basic_session);
use C4::Letters qw(GetPreparedLetter EnqueueLetter SendQueuedMessages);

use CGI;
use List::MoreUtils qw(any);

=head1 NAME

Koha::REST::Plugin::Auth::IdP

=head1 API

=head2 Helper methods

=cut

=head2 register

Missing POD for register.

=cut

sub register {
    my ( $self, $app ) = @_;

=head3 auth.register

    my $patron = $c->auth->register(
        {
            data      => $patron_data,
            domain    => $domain,
            interface => $interface
        }
    );

This helper creates a new I<Koha::Patron> using the (already) mapped data
provided in the I<data> attribute.

A check is done on the passed I<interface> and I<domain> to validate
the provider is configured to allow auto registration.

Valid values for B<interface> are I<opac> and I<staff>. An exception will be thrown
if other values or none are passed.

=cut

    $app->helper(
        'auth.register' => sub {
            my ( $c, $params ) = @_;
            my $data      = $params->{data};
            my $domain    = $params->{domain};
            my $interface = $params->{interface};

            Koha::Exceptions::MissingParameter->throw( parameter => 'interface' )
                unless $interface;

            Koha::Exceptions::BadParameter->throw( parameter => 'interface' )
                unless any { $interface eq $_ } qw{ opac staff };

            if (   $interface eq 'opac' && !$domain->auto_register_opac
                || $interface eq 'staff' && !$domain->auto_register_staff )
            {
                Koha::Exceptions::Auth::Unauthorized->throw( code => 401 );
            }

            my $provider = $domain->identity_provider;
            my $mapping  = $provider->mappings->as_auth_mapping;

            my ( %patron_attrs, %borrower_data );
            for my $key ( keys %$mapping ) {
                next unless $mapping->{$key}->{sync_on_creation};
                my $value = $data->{$key};
                $value //= $mapping->{$key}->{content};
                next unless defined $value;

                if ( $key =~ /^patron_attribute:(.+)$/ ) {
                    $patron_attrs{$1} = $value;
                } else {
                    $borrower_data{$key} = $value;
                }
            }
            my $patron = Koha::Patron->new( \%borrower_data )->store;
            for my $code ( keys %patron_attrs ) {
                Koha::Patron::Attribute->new(
                    { borrowernumber => $patron->borrowernumber, code => $code, attribute => $patron_attrs{$code} } )
                    ->store;
            }

            # Send welcome email if enabled
            if ( $domain->send_welcome_email ) {
                my $emailaddr = $patron->notice_email_address;

                # if we manage to find a valid email address, send notice
                if ($emailaddr) {
                    my $letter = C4::Letters::GetPreparedLetter(
                        module      => 'members',
                        letter_code => 'WELCOME',
                        branchcode  => $patron->branchcode,

                        lang   => $patron->lang || 'default',
                        tables => {
                            'branches'  => $patron->branchcode,
                            'borrowers' => $patron->borrowernumber,
                        },
                        want_librarian => 1,
                    );

                    # A missing or broken WELCOME letter must not hide the
                    # newly created patron from the caller
                    if ($letter) {
                        my $message_id = C4::Letters::EnqueueLetter(
                            {
                                letter                 => $letter,
                                borrowernumber         => $patron->id,
                                to_address             => $emailaddr,
                                message_transport_type => 'email'
                            }
                        );
                        C4::Letters::SendQueuedMessages( { message_id => $message_id } ) if $message_id;
                    }
                }
            }
            return $patron;
        }
    );

=head3 auth.session

    my ( $status, $cookie, $session_id ) = $c->auth->session( $patron );

Generates a new session.

=cut

    $app->helper(
        'auth.session' => sub {
            my ( $c, $params ) = @_;
            my $patron    = $params->{patron};
            my $interface = $params->{interface};
            my $provider  = $params->{provider};

            my $session = C4::Auth::create_basic_session( { patron => $patron, interface => $interface } );
            $session->param( 'idp_code', $provider );

            return $session->id;
        }
    );
}

1;
