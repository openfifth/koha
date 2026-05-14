package Koha::REST::V1::Acquisitions::Finances::Allocations;

# Copyright 2026 Open Fifth

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json);
use Try::Tiny;

use Koha::Acquisition::Finances::Funds;
use Koha::Acquisition::Finances::Ledgers;
use Koha::Acquisition::Finances::Allocation;
use Koha::Acquisition::Finances::Allocations;
use Koha::Exceptions::Acquisition::Finances::LimitExceeded;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $allocations_set = Koha::Acquisition::Finances::Allocations->new;
        my $allocations     = $c->objects->search($allocations_set);

        return $c->render( status => 200, openapi => $allocations );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $allocations_set = Koha::Acquisition::Finances::Allocations->new;
        my $allocation      = $c->objects->find( $allocations_set, $c->param('allocation_id') );

        unless ($allocation) {
            return $c->render(
                status  => 404,
                openapi => { error => "Allocation not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $allocation
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                my $body = $c->req->json;
                my $is_parent_amount_breached;

                my $allocation = Koha::Acquisition::Finances::Allocation->new_from_api($body);

                my $entities = {
                    funds => {
                        entity    => Koha::Acquisition::Finances::Funds->find( $body->{fund_id} ),
                        id_param  => 'fund_id',
                        recipient => Koha::Acquisition::Finances::Funds->find( $body->{is_transferred_to} )
                    },
                    ledgers => {
                        entity    => Koha::Acquisition::Finances::Ledgers->find( $body->{ledger_id} ),
                        id_param  => 'ledger_id',
                        recipient => Koha::Acquisition::Finances::Ledgers->find( $body->{is_transferred_to} )
                    },
                };
                my $module = $body->{fund_id} ? $entities->{funds} : $entities->{ledgers};

                my $entity      = $module->{entity};
                my $change_type = $body->{type} eq 'TRANSFER' ? 'DECREASE' : $body->{type};
                $is_parent_amount_breached =
                    $entity->update_amount( { type => $change_type, value => $body->{allocation_amount} } );
                if ($is_parent_amount_breached) {
                    return $c->render(
                        status  => 400,
                        openapi => {
                            error          => 'Amount has been breached', result => $is_parent_amount_breached,
                            dialog_confirm => 1
                        }
                    ) unless $is_parent_amount_breached->{within_limit};
                }
                $allocation->store->discard_changes;

                if ( $body->{type} eq 'TRANSFER' && $body->{is_transferred_to} ) {
                    my $recipient = $module->{recipient};
                    $is_parent_amount_breached =
                        $recipient->update_amount( { type => 'INCREASE', value => $body->{allocation_amount} } );
                    my $transfer = {%$body};
                    $transfer->{ $module->{id_param} } = $body->{is_transferred_to};
                    $transfer->{is_transferred_from}   = $body->{ $module->{id_param} };
                    $transfer->{is_transferred_to}     = undef;

                    my $transfer_allocation = Koha::Acquisition::Finances::Allocation->new_from_api($transfer);
                    if ($is_parent_amount_breached) {
                        return $c->render(
                            status  => 400,
                            openapi => {
                                error          => 'Amount has been breached', result => $is_parent_amount_breached,
                                dialog_confirm => 1
                            }
                        ) unless $is_parent_amount_breached->{within_limit};
                    }
                    $transfer_allocation->store->discard_changes;
                }

                $c->res->headers->location( $c->req->url->to_string . '/' . $allocation->allocation_id );
                return $c->render(
                    status  => 201,
                    openapi => $allocation->to_api
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::Finances::Allocation->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Acquisition::Finances::LimitExceeded') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                              error => "This allocation will exceed the spending limit on this "
                            . $_->data_type . " by "
                            . $_->amount
                            . ". Please amend the allocation amount or the spending limit"
                    }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

1;
