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
use Test::More tests => 5;
use Test::MockModule;

use Koha::Database;
use Koha::BackgroundJobs;
use Koha::BackgroundJob::BatchAddDisplayItems;
use Koha::Display::Items;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );

my $run = sub {
    my ($args) = @_;
    my $job_id = Koha::BackgroundJob::BatchAddDisplayItems->new->enqueue($args);
    my $job    = Koha::BackgroundJobs->find($job_id)->_derived_class;
    $job->process($args);
    return $job->get_from_storage;
};

my $make_display = sub {
    return $builder->build_object(
        {
            class => 'Koha::Displays',
            value => { enabled => 1, start_date => '2000-01-01', end_date => '2100-01-01', display_days => 7 },
        }
    );
};

subtest 'successful batch' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $display = $make_display->();
    my @items   = map { $builder->build_sample_item } 1 .. 2;

    my $job = $run->(
        {
            display_id => $display->display_id,
            barcodes   => [ map { $_->barcode } @items ],
            date_added => '2000-01-01',
        }
    );

    my $data = $job->decoded_data;
    is( $job->status,                               'finished', 'Job finished' );
    is( $job->progress,                             2,          'Progress counts every barcode' );
    is( $data->{report}->{total_success},           2,          'Both items added' );
    is( $data->{report}->{total_errors},            0,          'No errors' );
    is( scalar @{ $data->{report}->{added_items} }, 2,          'Both reported as added' );
    is( Koha::Display::Items->search( { display_id => $display->display_id } )->count, 2, 'Rows stored' );

    $schema->storage->txn_rollback;
};

subtest 'a bad barcode does not abort the batch' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $display  = $make_display->();
    my $good     = $builder->build_sample_item;
    my $existing = $builder->build_sample_item;
    $builder->build_object(
        {
            class => 'Koha::Display::Items',
            value => {
                display_id   => $display->display_id,
                itemnumber   => $existing->itemnumber,
                biblionumber => $existing->biblionumber,
                date_added   => '2000-01-01',
                date_remove  => '2100-01-01',
            }
        }
    );

    my $job = $run->(
        {
            display_id => $display->display_id,
            barcodes   => [ $good->barcode, 'NO-SUCH-BARCODE', $existing->barcode ],
            date_added => '2000-01-01',
        }
    );

    my $report = $job->decoded_data->{report};
    is( $job->status,                       'finished', 'Job finished' );
    is( $job->progress,                     3,          'Progress counts failures too' );
    is( $report->{total_success},           1,          'One item added' );
    is( $report->{total_errors},            2,          'Two errors' );
    is( scalar @{ $report->{added_items} }, 1,          'One reported as added' );
    my %errors = map { $_->{barcode} => $_->{error} } @{ $report->{failed_items} };
    is( $errors{'NO-SUCH-BARCODE'},    'Item with barcode not found', 'Unknown barcode reported' );
    is( $errors{ $existing->barcode }, 'Item already in display',     'Duplicate reported' );
    is(
        Koha::Display::Items->search( { display_id => $display->display_id, itemnumber => $good->itemnumber } )->count,
        1, 'The good item was stored'
    );

    $schema->storage->txn_rollback;
};

subtest 'items the model refuses are reported per barcode' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $display = $make_display->();
    my $item    = $builder->build_sample_item;

    my $job = $run->(
        {
            display_id  => $display->display_id,
            barcodes    => [ $item->barcode ],
            date_added  => '2000-02-01',
            date_remove => '2000-01-01',           # before date_added
        }
    );

    my $report = $job->decoded_data->{report};
    is( $job->status,             'finished', 'Job finished, it did not die' );
    is( $report->{total_success}, 0,          'Nothing added' );
    is( $report->{total_errors},  1,          'One error' );
    like( $report->{failed_items}->[0]->{error}, qr/date_remove/, 'The reason is reported' );
    is( Koha::Display::Items->search( { display_id => $display->display_id } )->count, 0, 'Nothing stored' );

    $schema->storage->txn_rollback;
};

subtest 'unexpected failure, cancellation and missing display' => sub {
    plan tests => 11;

    $schema->storage->txn_begin;

    my $display  = $make_display->();
    my @items    = map      { $builder->build_sample_item } 1 .. 2;
    my @barcodes = sort map { $_->barcode } @items;

    # An unexpected error on the second barcode rolls everything back
    my $calls = 0;
    my $mock  = Test::MockModule->new('Koha::Display::Item');
    my $orig  = \&Koha::Display::Item::store;
    $mock->mock(
        store => sub {
            die "Something unexpected\n" if ++$calls == 2;
            return $orig->(@_);
        }
    );

    my $job = $run->( { display_id => $display->display_id, barcodes => \@barcodes, date_added => '2000-01-01' } );
    $mock->unmock_all;

    my $report = $job->decoded_data->{report};
    is( $job->status,                       'failed', 'Job is marked as failed' );
    is( $report->{total_success},           0,        'Rolled-back work is not reported as success' );
    is( scalar @{ $report->{added_items} }, 0,        'Rolled-back work is not reported as added' );
    is( $report->{total_errors},            2,        'Every record is reported as an error' );
    is( Koha::Display::Items->search( { display_id => $display->display_id } )->count, 0, 'Nothing was stored' );

    # Cancelled before the first barcode
    my $job_id = Koha::BackgroundJob::BatchAddDisplayItems->new->enqueue(
        { display_id => $display->display_id, barcodes => \@barcodes, date_added => '2000-01-01' } );
    my $queued = Koha::BackgroundJobs->find($job_id)->_derived_class;
    $queued->start;
    $queued->status('cancelled')->store;
    my $cancelled_job = Koha::BackgroundJobs->find($job_id)->_derived_class;
    is( $cancelled_job->process( {} ), undef, 'A cancelled job does nothing' );

    # Cancelled part way through is reported
    my $job2_id = Koha::BackgroundJob::BatchAddDisplayItems->new->enqueue(
        { display_id => $display->display_id, barcodes => \@barcodes, date_added => '2000-01-01' } );
    my $job2     = Koha::BackgroundJobs->find($job2_id)->_derived_class;
    my $mock_job = Test::MockModule->new('Koha::BackgroundJob::BatchAddDisplayItems');
    $mock_job->mock( get_from_storage => sub { my $s = shift; $s->status('cancelled'); $s } );
    $job2->process( { display_id => $display->display_id, barcodes => \@barcodes, date_added => '2000-01-01' } );
    $mock_job->unmock_all;
    my $messages = Koha::BackgroundJobs->find($job2_id)->_derived_class->decoded_data->{messages};
    ok( ( grep { $_->{code} eq 'cancelled' } @{$messages} ), 'Cancellation is reported' );

    # Unknown display fails the job
    my $job3 = $run->( { display_id => 999999999, barcodes => \@barcodes } );
    is( $job3->status,                                'failed',            'A missing display fails the job' );
    is( $job3->decoded_data->{messages}->[0]->{code}, 'display_not_found', 'With the right code' );

    # barcodes are plain strings
    my $job4 = $run->( { display_id => $display->display_id, barcodes => ['ABC123'], date_added => '2000-01-01' } );
    is( $job4->decoded_data->{report}->{total_errors}, 1,          'Alphanumeric barcodes are handled as strings' );
    is( $job4->status,                                 'finished', 'and do not break the job' );

    $schema->storage->txn_rollback;
};
