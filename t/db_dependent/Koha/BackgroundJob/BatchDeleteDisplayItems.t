#!/usr/bin/perl

# This file is part of Koha
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

use Test::NoWarnings;
use Test::More tests => 3;
use Test::MockModule;

use Koha::Database;
use Koha::BackgroundJobs;
use Koha::BackgroundJob::BatchDeleteDisplayItems;
use Koha::Display::Items;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );

my $run = sub {
    my ($args) = @_;
    my $job_id = Koha::BackgroundJob::BatchDeleteDisplayItems->new->enqueue($args);
    my $job    = Koha::BackgroundJobs->find($job_id)->_derived_class;
    $job->process($args);
    return $job->get_from_storage;
};

my $put_on_display = sub {
    my ( $display, $item ) = @_;
    return $builder->build_object(
        {
            class => 'Koha::Display::Items',
            value => {
                display_id   => $display->display_id,
                itemnumber   => $item->itemnumber,
                biblionumber => $item->biblionumber,
                date_added   => '2000-01-01',
                date_remove  => '2100-01-01',
            }
        }
    );
};

subtest 'partial failures do not abort the batch' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    my $display = $builder->build_object( { class => 'Koha::Displays', value => { enabled => 1 } } );
    my $on      = $builder->build_sample_item;
    my $off     = $builder->build_sample_item;
    $put_on_display->( $display, $on );

    my $job = $run->( { display_id => $display->display_id, barcodes => [ $on->barcode, $off->barcode, 'NOPE' ] } );

    my $report = $job->decoded_data->{report};
    is( $job->status,             'finished', 'Job finished' );
    is( $job->progress,           3,          'Progress counts every barcode' );
    is( $report->{total_success}, 1,          'One removed' );
    is( $report->{total_errors},  2,          'Two errors' );
    my %errors = map { $_->{barcode} => $_->{error} } @{ $report->{failed_items} };
    is( $errors{NOPE},            'Item with barcode not found',         'Unknown barcode reported' );
    is( $errors{ $off->barcode }, 'Item not found in specified display', 'Item not on the display reported' );
    is( Koha::Display::Items->search( { display_id => $display->display_id } )->count, 0, 'Row removed' );

    $schema->storage->txn_rollback;
};

subtest 'unexpected failure rolls back and is reported as failed' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $display = $builder->build_object( { class => 'Koha::Displays', value => { enabled => 1 } } );
    my @items   = map { $builder->build_sample_item } 1 .. 2;
    $put_on_display->( $display, $_ ) for @items;

    my $calls = 0;
    my $mock  = Test::MockModule->new('Koha::Display::Item');
    my $orig  = \&Koha::Display::Item::delete;
    $mock->mock(
        delete => sub {
            die "Something unexpected\n" if ++$calls == 2;
            return $orig->(@_);
        }
    );

    my $job = $run->( { display_id => $display->display_id, barcodes => [ map { $_->barcode } @items ] } );
    $mock->unmock_all;

    my $report = $job->decoded_data->{report};
    is( $job->status,                         'failed', 'Job is marked as failed' );
    is( $report->{total_success},             0,        'Rolled-back work is not reported as success' );
    is( scalar @{ $report->{deleted_items} }, 0,        'Rolled-back work is not reported as deleted' );
    is( $report->{total_errors},              2,        'Every record is reported as an error' );
    is( Koha::Display::Items->search( { display_id => $display->display_id } )->count, 2, 'Nothing was deleted' );

    my $failed = $run->( { display_id => 999999999, barcodes => ['X'] } );
    is( $failed->status, 'failed', 'A missing display fails the job' );

    $schema->storage->txn_rollback;
};
