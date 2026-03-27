package Koha::REST::V1::Acquisitions::FundManagement::Allocations;

# Copyright 2024 PTFS Europe

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

use Koha::Acquisition::FundManagement::Funds;
use Koha::Acquisition::FundManagement::Ledgers;
use Koha::Acquisition::FundManagement::Allocation;
use Koha::Acquisition::FundManagement::Allocations;
use Koha::Exceptions::Acquisition::FundManagement::LimitExceeded;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $allocations_set = Koha::Acquisition::FundManagement::Allocations->new;
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
        my $allocations_set = Koha::Acquisition::FundManagement::Allocations->new;
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

                my $allocation =
                    Koha::Acquisition::FundManagement::Allocation->new_from_api($body)->store->discard_changes;

                my $entities = {
                    funds => {
                        entity    => Koha::Acquisition::FundManagement::Funds->find( $body->{fund_id} ),
                        id_param  => 'fund_id',
                        recipient => Koha::Acquisition::FundManagement::Funds->find( $body->{is_transferred_to} )
                    },
                    ledgers => {
                        entity    => Koha::Acquisition::FundManagement::Ledgers->find( $body->{ledger_id} ),
                        id_param  => 'ledger_id',
                        recipient => Koha::Acquisition::FundManagement::Ledgers->find( $body->{is_transferred_to} )
                    },
                };
                my $module = $body->{fund_id} ? $entities->{funds} : $entities->{ledgers};

                my $entity      = $module->{entity};
                my $change_type = $body->{type} eq 'transfer' ? 'decrease' : $body->{type};
                $entity->update_amount( { type => $change_type, value => $body->{allocation_amount} } );

                if ( $body->{type} eq 'transfer' && $body->{is_transferred_to} ) {
                    my $recipient = $module->{recipient};
                    $recipient->update_amount( { type => 'increase', value => $body->{allocation_amount} } );
                    my $transfer = {%$body};
                    $transfer->{ $module->{id_param} } = $body->{is_transferred_to};
                    $transfer->{is_transferred_from}   = $body->{ $module->{id_param} };
                    $transfer->{is_transferred_to}     = undef;

                    my $transfer_allocation =
                        Koha::Acquisition::FundManagement::Allocation->new_from_api($transfer)->store->discard_changes;
                }

                $c->res->headers->location( $c->req->url->to_string . '/' . $allocation->allocation_id );
                return $c->render(
                    status  => 201,
                    openapi => $allocation->to_api
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::FundManagement::Allocation->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Acquisition::FundManagement::LimitExceeded') ) {
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

=head3 update

Controller function that handles updating a Koha::Acquisition::FundManagement::Allocation object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $allocation = Koha::Acquisition::FundManagement::Allocations->find( $c->param('allocation_id') );

    unless ($allocation) {
        return $c->render(
            status  => 404,
            openapi => { error => "Allocation not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                $allocation->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $allocation->allocation_id );
                return $c->render(
                    status  => 200,
                    openapi => $allocation->to_api
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::FundManagement::Allocation->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->broken_fk } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->parameter } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            } elsif ( $_->isa('Koha::Exceptions::Acquisition::FundManagement::LimitExceeded') ) {
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

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $allocation = Koha::Acquisition::FundManagement::Allocations->find( $c->param('allocation_id') );
    unless ($allocation) {
        return $c->render(
            status  => 404,
            openapi => { error => "Allocation not found" }
        );
    }

    return try {
        my $fund_id = $allocation->fund_id;
        $allocation->delete;

        return $c->render(
            status  => 204,
            openapi => q{}
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 transfer

=cut

sub transfer {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                # Currency needs reviewing - fx calculation may be required
                my $body = $c->req->json;

                my $fund_transferring_from =
                    Koha::Acquisition::FundManagement::Funds->find( { fund_id => $body->{fund_id_from} } );
                my $fund_transferring_to =
                    Koha::Acquisition::FundManagement::Funds->find( { fund_id => $body->{fund_id_to} } );

                my $note_from = "Transfer to " . $fund_transferring_to->name;
                $note_from = $note_from . ": " . $body->{note} if $body->{note};
                my $note_to = "Transfer from " . $fund_transferring_from->name;
                $note_to = $note_to . ": " . $body->{note} if $body->{note};

                my $fund_id_from = $body->{sub_fund_id_from} ? undef : $body->{fund_id_from};
                my $fund_id_to   = $body->{sub_fund_id_to}   ? undef : $body->{fund_id_to};

                my $allocation_from = Koha::Acquisition::FundManagement::Allocation->new(
                    {
                        fund_id           => $fund_id_from,
                        sub_fund_id       => $body->{sub_fund_id_from},
                        ledger_id         => $fund_transferring_from->ledger_id,
                        fiscal_period_id  => $fund_transferring_from->fiscal_period_id,
                        allocation_amount => -$body->{transfer_amount},
                        reference         => $body->{reference},
                        note              => $note_from,
                        currency          => $fund_transferring_from->currency,
                        owner_id          => $fund_transferring_from->owner_id,
                        managing_branch   => $fund_transferring_from->managing_branch,
                        is_transfer       => 1
                    }
                )->store();
                my $allocation_to = Koha::Acquisition::FundManagement::Allocation->new(
                    {
                        fund_id           => $fund_id_to,
                        sub_fund_id       => $body->{sub_fund_id_to},
                        ledger_id         => $fund_transferring_to->ledger_id,
                        fiscal_period_id  => $fund_transferring_to->fiscal_period_id,
                        allocation_amount => $body->{transfer_amount},
                        reference         => $body->{reference},
                        note              => $note_to,
                        currency          => $fund_transferring_to->currency,
                        owner_id          => $fund_transferring_to->owner_id,
                        managing_branch   => $fund_transferring_to->managing_branch,
                        is_transfer       => 1
                    }
                )->store();

                return $c->render(
                    status  => 201,
                    openapi => { msg => 'Success' }
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };

}

1;
