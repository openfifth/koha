#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 10;
use Test::Exception;
use Test::NoWarnings;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Patron::Quotas;
use Koha::DateUtils qw( dt_from_string );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'basic CRUD operations' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $quota = Koha::Patron::Quota->new(
        {
            patron_id   => $patron->id,
            description => 'Test quota',
            start_date  => '2025-01-01',
            end_date    => '2025-12-31',
            allocation  => 10,
            used        => 0
        }
    )->store;

    ok( $quota->id, 'Quota created with auto-increment ID' );
    is( $quota->allocation, 10, 'Allocation set correctly' );
    is( $quota->used,       0,  'Used initialized to 0' );

    my $retrieved = Koha::Patron::Quotas->find( $quota->id );
    is( $retrieved->id, $quota->id, 'Quota retrieved successfully' );

    $quota->delete;
    is( Koha::Patron::Quotas->search( { id => $quota->id } )->count, 0, 'Quota deleted successfully' );

    $schema->storage->txn_rollback;
};

subtest 'filter_by_active() method' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $past_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => '2020-01-01',
                end_date   => '2020-12-31'
            }
        }
    );

    my $current_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => dt_from_string()->ymd,
                end_date   => dt_from_string()->add( days => 30 )->ymd
            }
        }
    );

    my $future_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => dt_from_string()->add( days => 365 )->ymd,
                end_date   => dt_from_string()->add( days => 730 )->ymd
            }
        }
    );

    my $all_quotas = Koha::Patron::Quotas->search( { patron_id => $patron->id } );
    is( $all_quotas->count, 3, 'All quotas present' );

    my $active_quotas = $all_quotas->filter_by_active;
    is( $active_quotas->count,    1,                  'Only one active quota' );
    is( $active_quotas->next->id, $current_quota->id, 'Correct quota is active' );

    $schema->storage->txn_rollback;
};

subtest 'has_available_quota() method' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $quota_with_available = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                allocation => 10,
                used       => 5
            }
        }
    );

    ok( $quota_with_available->has_available_quota, 'Quota has available allocation' );

    my $quota_fully_used = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                allocation => 10,
                used       => 10
            }
        }
    );

    ok( !$quota_fully_used->has_available_quota, 'Fully used quota has no available allocation' );

    my $quota_exceeded = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                allocation => 10,
                used       => 15
            }
        }
    );

    ok( !$quota_exceeded->has_available_quota, 'Exceeded quota has no available allocation' );

    $schema->storage->txn_rollback;
};

subtest 'available_quota() method' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                allocation => 10,
                used       => 3
            }
        }
    );

    is( $quota->available_quota, 7, 'Available quota calculated correctly' );

    $quota->used(10)->store;
    is( $quota->available_quota, 0, 'No available quota when fully used' );

    $quota->used(12)->store;
    is( $quota->available_quota, -2, 'Negative available quota when exceeded' );

    $schema->storage->txn_rollback;
};

subtest 'is_active() method' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $past_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => '2020-01-01',
                end_date   => '2020-12-31'
            }
        }
    );

    ok( !$past_quota->is_active, 'Past quota is not active' );

    my $current_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => dt_from_string()->ymd,
                end_date   => dt_from_string()->add( days => 30 )->ymd
            }
        }
    );

    ok( $current_quota->is_active, 'Current quota is active' );

    my $future_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => dt_from_string()->add( days => 365 )->ymd,
                end_date   => dt_from_string()->add( days => 730 )->ymd
            }
        }
    );

    ok( !$future_quota->is_active, 'Future quota is not active' );

    $schema->storage->txn_rollback;
};

subtest 'add_to_quota() method' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                allocation => 10,
                used       => 3
            }
        }
    );

    is( $quota->used, 3, 'Initial used value is 3' );

    $quota->add_to_quota(2);
    is( $quota->used, 5, 'Used incremented by 2' );

    $quota->add_to_quota(7);
    is( $quota->used, 12, 'Used can exceed allocation' );

    $schema->storage->txn_rollback;
};

subtest 'add_usage() method' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item   = $builder->build_sample_item;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                allocation => 10,
                used       => 0
            }
        }
    );

    my $checkout = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->id,
                itemnumber     => $item->id
            }
        }
    );

    my $usage = $quota->add_usage( { issue_id => $checkout->issue_id, type => 'ISSUE', amount => 1 } );

    ok( defined $usage, 'Usage created' );
    is( $usage->patron_quota_id, $quota->id,          'Usage linked to quota' );
    is( $usage->issue_id,        $checkout->issue_id, 'Usage linked to checkout' );

    $quota->discard_changes;
    is( $quota->used, 1, 'Quota used incremented' );

    $schema->storage->txn_rollback;
};

subtest 'period clash validation' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $existing_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron->id,
                start_date => '2025-01-01',
                end_date   => '2025-12-31'
            }
        }
    );

    throws_ok {
        Koha::Patron::Quota->new(
            {
                patron_id   => $patron->id,
                description => 'Overlapping quota',
                start_date  => '2025-06-01',
                end_date    => '2025-12-31',
                allocation  => 5,
                used        => 0
            }
        )->store;
    }
    'Koha::Exceptions::Quota::Clash', 'Overlapping period throws clash exception';

    throws_ok {
        Koha::Patron::Quota->new(
            {
                patron_id   => $patron->id,
                description => 'Same start date quota',
                start_date  => '2025-01-01',
                end_date    => '2025-06-30',
                allocation  => 5,
                used        => 0
            }
        )->store;
    }
    'Koha::Exceptions::Quota::Clash', 'Period starting same day throws clash exception';

    my $non_overlapping_past = Koha::Patron::Quota->new(
        {
            patron_id   => $patron->id,
            description => 'Past quota',
            start_date  => '2024-01-01',
            end_date    => '2024-12-31',
            allocation  => 5,
            used        => 0
        }
    )->store;

    ok( $non_overlapping_past->id, 'Non-overlapping past quota created successfully' );

    my $non_overlapping_future = Koha::Patron::Quota->new(
        {
            patron_id   => $patron->id,
            description => 'Future quota',
            start_date  => '2026-01-01',
            end_date    => '2026-12-31',
            allocation  => 5,
            used        => 0
        }
    )->store;

    ok( $non_overlapping_future->id, 'Non-overlapping future quota created successfully' );

    $schema->storage->txn_rollback;
};

subtest 'relations' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item   = $builder->build_sample_item;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => { patron_id => $patron->id }
        }
    );

    isa_ok( $quota->patron, 'Koha::Patron', 'Patron relation works' );
    is( $quota->patron->id, $patron->id, 'Correct patron returned' );

    my $checkout = $builder->build_object(
        {
            class => 'Koha::Checkouts',
            value => {
                borrowernumber => $patron->id,
                itemnumber     => $item->id
            }
        }
    );

    my $usage = $builder->build_object(
        {
            class => 'Koha::Patron::Quota::Usages',
            value => {
                patron_quota_id => $quota->id,
                patron_id       => $patron->id,
                issue_id        => $checkout->issue_id,
                type            => 'ISSUE'
            }
        }
    );

    my $usages = $quota->usages;
    isa_ok( $usages, 'Koha::Patron::Quota::Usages', 'Usages relation works' );
    is( $usages->count, 1, 'Correct number of usages returned' );

    $schema->storage->txn_rollback;
};
