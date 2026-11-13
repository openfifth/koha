package Koha::BackgroundJob::BatchAddDisplayItems;

# Copyright 2025-2026 Open Fifth Ltd
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
use Scalar::Util qw( blessed );
use Try::Tiny    qw( catch try );
use C4::Context;

use Koha::Database;
use Koha::DateUtils qw(dt_from_string);
use Koha::Display::Item;
use Koha::Display::Items;
use Koha::Items;
use Koha::Logger;
use Koha::Displays;

use base 'Koha::BackgroundJob';

=head1 NAME

Koha::BackgroundJob::BatchAddDisplayItems - Background job to add multiple items to a display

=head1 API

=head2 Class methods

=head3 job_type

Return the job type 'batch_add_display_items'.

=cut

sub job_type {
    return 'batch_add_display_items';
}

=head3 process

Process the batch addition of items to a display

=cut

sub process {
    my ( $self, $args ) = @_;

    if ( $self->status eq 'cancelled' ) {
        return;
    }

    $self->start;

    my $display_id  = $args->{display_id};
    my @barcodes    = @{ $args->{barcodes} };
    my $date_added  = $args->{date_added};
    my $date_remove = $args->{date_remove};

    my $report = {
        total_records => scalar @barcodes,
        total_success => 0,
        total_errors  => 0,
    };

    my @messages;
    my @added_items;
    my @failed_items;
    my $cancelled = 0;
    my $failed    = 0;

    # Validate display exists
    my $display = Koha::Displays->find($display_id);
    unless ($display) {
        push @messages, {
            type       => 'error',
            code       => 'display_not_found',
            display_id => $display_id,
        };
        $self->status('failed');
        $self->finish( { messages => \@messages, report => $report } );
        return;
    }

    try {
        my $schema = Koha::Database->new->schema;
        $schema->txn_do(
            sub {
                for my $barcode ( sort { $a cmp $b } @barcodes ) {

                    if ( $self->get_from_storage->status eq 'cancelled' ) {
                        $cancelled = 1;
                        last;
                    }
                    $self->step;

                    my $item = Koha::Items->find( { barcode => $barcode } );
                    unless ($item) {
                        push @failed_items, {
                            barcode => $barcode,
                            error   => 'Item with barcode not found'
                        };
                        $report->{total_errors}++;
                        next;
                    }
                    my $itemnumber = $item->itemnumber;

                    # Check if item is already in this display
                    my $existing = Koha::Display::Items->search(
                        {
                            display_id => $display_id,
                            itemnumber => $itemnumber,
                        }
                    )->next;

                    if ($existing) {
                        push @failed_items, {
                            itemnumber => $itemnumber,
                            barcode    => $barcode,
                            error      => 'Item already in display'
                        };
                        $report->{total_errors}++;
                        next;
                    }

                    # Create display item. A display item the model refuses is a
                    # failure of that barcode, not of the whole batch
                    my $display_item = try {
                        Koha::Display::Item->new(
                            {
                                display_id   => $display_id,
                                itemnumber   => $itemnumber,
                                biblionumber => $item->biblionumber,
                                date_added   => $date_added,
                                date_remove  => $date_remove,
                            }
                        )->store;
                    } catch {
                        die $_ unless blessed($_) && $_->isa('Koha::Exceptions::BadParameter');
                        push @failed_items, {
                            itemnumber => $itemnumber,
                            barcode    => $barcode,
                            error      => $_->error,
                        };
                        $report->{total_errors}++;
                        undef;
                    };
                    next unless $display_item;

                    push @added_items, {
                        display_item_id => $display_item->display_item_id,
                        itemnumber      => $itemnumber,
                        barcode         => $barcode,
                        biblionumber    => $item->biblionumber,
                    };

                    $report->{total_success}++;
                }
            }
        );
    } catch {
        Koha::Logger->get->error( "Job " . $self->id . " (" . $self->job_type . ") failed and was rolled back: $_" );

        # The transaction was rolled back, so nothing the loop counted was kept
        $failed                  = 1;
        @added_items             = ();
        $report->{total_success} = 0;
        $report->{total_errors}  = $report->{total_records};
        @messages                = (
            {
                type  => 'error',
                code  => 'unknown',
                error => "$_",
            }
        );
        die "Something terrible has happened!" if ( $_ =~ /Rollback failed/ );
    };

    push @messages, { type => 'warning', code => 'cancelled' } if $cancelled;

    $report->{display_id}   = $display_id;
    $report->{display_name} = $display->display_name || q{};
    $report->{added_items}  = \@added_items;
    $report->{failed_items} = \@failed_items;

    my $data = $self->decoded_data;
    $data->{messages} = \@messages;
    $data->{report}   = $report;

    $self->status('failed') if $failed;
    $self->finish($data);
}

=head3 enqueue

Enqueue the job.

=cut

sub enqueue {
    my ( $self, $args ) = @_;

    return unless exists $args->{barcodes} && exists $args->{display_id};

    my @barcodes    = @{ $args->{barcodes} };
    my $display_id  = $args->{display_id};
    my $date_added  = $args->{date_added};
    my $date_remove = $args->{date_remove};

    $self->SUPER::enqueue(
        {
            job_size => scalar @barcodes,
            job_args => {
                display_id  => $display_id,
                barcodes    => \@barcodes,
                date_added  => $date_added,
                date_remove => $date_remove,
            },
            job_queue => 'long_tasks',
        }
    );
}

1;
