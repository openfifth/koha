package Koha::REST::V1::Acquisitions::Finances::Ledgers;

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

use Koha::Acquisition::Finances::Allocation;
use Koha::Acquisition::Finances::Ledger;
use Koha::Acquisition::Finances::Ledgers;
use Koha::Acquisition::Finances::FiscalPeriods;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $ledgers = $c->objects->search( Koha::Acquisition::Finances::Ledgers->new );
        return $c->render( status => 200, openapi => $ledgers );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $ledger = Koha::Acquisition::Finances::Ledgers->find( $c->param('ledger_id') );
        return $c->render_resource_not_found("Ledger")
            unless $ledger;

        return $c->render( status => 200, openapi => $c->objects->to_api($ledger), );
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

                my $ledger = Koha::Acquisition::Finances::Ledger->new_from_api($body)->store->discard_changes;

                Koha::Acquisition::Finances::Allocation->new(
                    {
                        ledger_id         => $ledger->ledger_id,
                        allocation_amount => $ledger->ledger_amount,
                        type              => 'INITIAL',
                    }
                )->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $ledger->ledger_id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($ledger)
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Acquisition::Finances::Ledger object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $ledger = Koha::Acquisition::Finances::Ledgers->find( $c->param('ledger_id') );

    unless ($ledger) {
        return $c->render(
            status  => 404,
            openapi => { error => "Ledger not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                delete $body->{fiscal_period} if $body->{fiscal_period};

                $ledger->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $ledger->ledger_id );
                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($ledger)
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::Finances::Ledger->new->to_api_mapping;

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
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $ledger = Koha::Acquisition::Finances::Ledgers->find( $c->param('ledger_id') );
    return $c->render_resource_not_found("Ledger")
        unless $ledger;

    return try {
        $ledger->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 rollover

=cut

sub rollover {
    my $c = shift->openapi->valid_input or return;

    my $ledger = Koha::Acquisition::Finances::Ledgers->find( $c->param('ledger_id') );
    return $c->render_resource_not_found("Ledger") unless $ledger;

    my $dry_run = $c->param('dry_run') ? 1 : 0;
    my ( $new_ledger, $dry_run_data );

    return try {
        my $schema = Koha::Database->new->schema;
        $schema->txn_begin;

        my $body = $c->req->json;

        my $adjust_by_percent = delete $body->{adjust_by_percent};
        my $round_to_multiple = delete $body->{round_to_multiple};
        my $set_funds_to_zero = delete $body->{set_funds_to_zero};

        if ($adjust_by_percent) {
            $body->{ledger_amount} += $body->{ledger_amount} * $adjust_by_percent / 100;
            if ($round_to_multiple) {
                $body->{ledger_amount} =
                    int( $body->{ledger_amount} / $round_to_multiple ) * $round_to_multiple;
            }
        }

        $body->{currency} = $ledger->currency;

        $new_ledger = Koha::Acquisition::Finances::Ledger->new_from_api($body)->store->discard_changes;

        Koha::Acquisition::Finances::Allocation->new(
            {
                ledger_id         => $new_ledger->ledger_id,
                allocation_amount => $new_ledger->ledger_amount,
                type              => 'ROLLOVER_TRANSFER',
            }
        )->store;

        $ledger->status(0)->store;

        my @top_level_funds =
            Koha::Acquisition::Finances::Funds->search( { ledger_id => $ledger->ledger_id, parent_fund_id => undef } )
            ->as_list;

        for my $fund (@top_level_funds) {
            _copy_fund(
                $fund,
                $new_ledger,
                undef,
                {
                    set_funds_to_zero => $set_funds_to_zero,
                    adjust_by_percent => $adjust_by_percent,
                    round_to_multiple => $round_to_multiple,
                }
            );
        }

        if ($dry_run) {
            my @preview_funds =
                Koha::Acquisition::Finances::Funds->search( { ledger_id => $new_ledger->ledger_id } )->as_list;

            $dry_run_data = $new_ledger->to_api;
            $dry_run_data->{funds} = [ map { $_->to_api } @preview_funds ];

            $schema->txn_rollback;
            return $c->render( status => 200, openapi => $dry_run_data );
        }

        $schema->txn_commit;

        $c->res->headers->location( $c->req->url->to_string . '/' . $new_ledger->ledger_id );
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($new_ledger)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

sub _copy_fund {
    my ( $original_fund, $new_ledger, $new_parent_fund_id, $options ) = @_;

    my $fund_amount;
    if ( $options->{set_funds_to_zero} ) {
        $fund_amount = 0;
    } elsif ( $options->{adjust_by_percent} ) {
        $fund_amount = $original_fund->fund_amount + $original_fund->fund_amount * $options->{adjust_by_percent} / 100;
        if ( $options->{round_to_multiple} ) {
            $fund_amount = int( $fund_amount / $options->{round_to_multiple} ) * $options->{round_to_multiple};
        }
    } else {
        $fund_amount = $original_fund->fund_amount;
    }

    my $new_fund = Koha::Acquisition::Finances::Fund->new(
        {
            ledger_id          => $new_ledger->ledger_id,
            parent_fund_id     => $new_parent_fund_id,
            name               => $original_fund->name,
            code               => $original_fund->code,
            description        => $original_fund->description,
            external_id        => $original_fund->external_id,
            status             => $new_ledger->status,
            fund_amount        => $fund_amount,
            managing_branch    => $original_fund->managing_branch,
            owner_id           => $original_fund->owner_id,
            fund_permission    => $original_fund->fund_permission,
            oe_warning_percent => $original_fund->oe_warning_percent,
            oe_warning_amount  => $original_fund->oe_warning_amount,
            fund_type          => $original_fund->fund_type,
        }
    )->store( { no_cascade => 1 } );

    for my $sub_fund ( $original_fund->sub_funds->as_list ) {
        _copy_fund( $sub_fund, $new_ledger, $new_fund->fund_id, $options );
    }

    return $new_fund;
}

1;
