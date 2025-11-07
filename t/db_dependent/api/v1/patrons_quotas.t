#!/usr/bin/env perl

use Modern::Perl;

use Test::More tests => 8;
use Test::Mojo;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Patron::Quotas;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 14;

    $schema->storage->txn_begin;

    Koha::Patron::Quotas->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    my $patron_password = 'thePassword000';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $patron_id = $patron->id;

    $t->get_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas")->status_is(200)->json_is( [] );

    my $current_year_start = dt_from_string()->truncate( to => 'year' )->ymd;
    my $current_year_end   = dt_from_string()->truncate( to => 'year' )->add( years => 1 )->subtract( days => 1 )->ymd;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron_id,
                start_date => $current_year_start,
                end_date   => $current_year_end,
                allocation => 10,
                used       => 0
            }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas")->status_is(200)->json_is( [ $quota->to_api ] );

    my $another_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron_id,
                start_date => '2020-01-01',
                end_date   => '2020-12-31',
                allocation => 5,
                used       => 3
            }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas")
        ->status_is(200)
        ->json_is( [ $quota->to_api, $another_quota->to_api ] );

    $t->get_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas?only_active=true")
        ->status_is(200)
        ->json_is( [ $quota->to_api ] );

    $t->get_ok("//$unauth_userid:$patron_password@/api/v1/patrons/$patron_id/quotas")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    my $patron_password = 'thePassword000';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => { patron_id => $patron->id }
        }
    );

    $t->get_ok( "//$userid:$password@/api/v1/patrons/" . $quota->patron_id . "/quotas/" . $quota->id )
        ->status_is(200)
        ->json_is( $quota->to_api );

    $t->get_ok( "//$unauth_userid:$patron_password@/api/v1/patrons/" . $quota->patron_id . "/quotas/" . $quota->id )
        ->status_is(403);

    my $quota_to_delete = $builder->build_object( { class => 'Koha::Patron::Quotas' } );
    my $non_existent_id = $quota_to_delete->id;
    $quota_to_delete->delete;

    $t->get_ok( "//$userid:$password@/api/v1/patrons/" . $quota->patron_id . "/quotas/$non_existent_id" )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 18;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    my $patron_password = 'thePassword000';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $test_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_id   = $test_patron->id;

    my $current_year_start = dt_from_string()->truncate( to => 'year' )->ymd;
    my $current_year_end   = dt_from_string()->truncate( to => 'year' )->add( years => 1 )->subtract( days => 1 )->ymd;
    my $next_year_start    = dt_from_string()->truncate( to => 'year' )->add( years => 1 )->ymd;
    my $next_year_end      = dt_from_string()->truncate( to => 'year' )->add( years => 2 )->subtract( days => 1 )->ymd;

    my $quota_data = {
        description => 'Test quota',
        start_date  => $current_year_start,
        end_date    => $current_year_end,
        allocation  => 10,
        used        => 0
    };

    $t->post_ok( "//$unauth_userid:$patron_password@/api/v1/patrons/$patron_id/quotas" => json => $quota_data )
        ->status_is(403);

    $t->post_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas" => json => $quota_data )
        ->status_is( 201, 'SWAGGER3.2.1' )
        ->json_is( '/start_date' => $current_year_start )
        ->json_is( '/end_date'   => $current_year_end )
        ->json_is( '/allocation' => 10 )
        ->json_is( '/used'       => 0 )
        ->header_like( Location => qr|^/api/v1/patrons/$patron_id/quotas/\d+|, 'SWAGGER3.4.1' );

    my $quota_with_id = {
        id          => 2,
        description => 'Test quota with ID',
        start_date  => $next_year_start,
        end_date    => $next_year_end,
        allocation  => 5,
        used        => 0
    };

    $t->post_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas" => json => $quota_with_id )
        ->status_is(400)
        ->json_has('/errors');

    my $overlapping_start = dt_from_string()->truncate( to => 'year' )->add( months => 6 )->ymd;

    my $overlapping_quota = {
        description => 'Overlapping quota',
        start_date  => $overlapping_start,
        end_date    => $current_year_end,
        allocation  => 5,
        used        => 0
    };

    $t->post_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas" => json => $overlapping_quota )
        ->status_is(409)
        ->json_is( '/error' => 'Quota period overlaps with existing quota' );

    my $future_year_start = dt_from_string()->truncate( to => 'year' )->add( years => 2 )->ymd;
    my $future_year_end   = dt_from_string()->truncate( to => 'year' )->add( years => 3 )->subtract( days => 1 )->ymd;

    my $invalid_quota = {
        description  => 'Invalid quota',
        start_date   => $future_year_start,
        end_date     => $future_year_end,
        allocation   => 10,
        used         => 0,
        invalid_prop => 'Invalid'
    };

    $t->post_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas" => json => $invalid_quota )
        ->status_is(400)
        ->json_has('/errors');

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 16;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    my $patron_password = 'thePassword000';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $test_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_id   = $test_patron->id;

    my $current_year_start = dt_from_string()->truncate( to => 'year' )->ymd;
    my $current_year_end   = dt_from_string()->truncate( to => 'year' )->add( years  => 1 )->subtract( days => 1 )->ymd;
    my $overlapping_start  = dt_from_string()->truncate( to => 'year' )->add( months => 6 )->ymd;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron_id,
                start_date => $current_year_start,
                end_date   => $current_year_end,
                allocation => 10,
                used       => 0
            }
        }
    );

    $t->put_ok(
        "//$unauth_userid:$patron_password@/api/v1/patrons/$patron_id/quotas/" . $quota->id => json => {
            description => 'Updated quota',
            start_date  => $current_year_start,
            end_date    => $current_year_end,
            allocation  => 15,
            used        => 0
        }
    )->status_is(403);

    my $updated_quota = $quota->to_api;
    delete $updated_quota->{id};           # readOnly field
    delete $updated_quota->{patron_id};    # readOnly field
    $updated_quota->{allocation} = 15;

    $t->put_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id => json => $updated_quota )
        ->status_is(200)
        ->json_is( '/allocation' => 15 );

    my $partial_update = { allocation => 20 };

    $t->put_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id => json => $partial_update )
        ->status_is(400)
        ->json_has('/errors');

    my $another_quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => {
                patron_id  => $patron_id,
                start_date => '2020-01-01',
                end_date   => '2020-12-31',
                allocation => 5,
                used       => 0
            }
        }
    );

    my $overlapping_update = $quota->to_api;
    delete $overlapping_update->{id};                    # readOnly field
    delete $overlapping_update->{patron_id};             # readOnly field
    $overlapping_update->{start_date} = '2020-06-01';    # Overlaps with another_quota
    $overlapping_update->{end_date}   = '2020-12-31';

    $t->put_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id => json => $overlapping_update )
        ->status_is(409)
        ->json_is( '/error' => 'Quota period overlaps with existing quota' );

    my $invalid_update = $quota->to_api;
    delete $invalid_update->{id};                        # readOnly field
    delete $invalid_update->{patron_id};                 # readOnly field
    $invalid_update->{invalid_prop} = 'Invalid';

    $t->put_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id => json => $invalid_update )
        ->status_is(400)
        ->json_has('/errors');

    my $quota_to_delete = $builder->build_object( { class => 'Koha::Patron::Quotas' } );
    my $non_existent_id = $quota_to_delete->id;
    $quota_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/$non_existent_id" => json => $updated_quota )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    my $patron_password = 'thePassword000';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $test_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_id   = $test_patron->id;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => { patron_id => $patron_id }
        }
    );

    $t->delete_ok( "//$unauth_userid:$patron_password@/api/v1/patrons/$patron_id/quotas/" . $quota->id )
        ->status_is(403);

    $t->delete_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id )
        ->status_is( 204, 'SWAGGER3.2.4' )
        ->content_is( '', 'SWAGGER3.3.4' );

    my $quota_to_delete = $builder->build_object( { class => 'Koha::Patron::Quotas' } );
    my $non_existent_id = $quota_to_delete->id;
    $quota_to_delete->delete;

    $t->delete_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas/$non_existent_id")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'get_usage() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    my $patron_password = 'thePassword000';
    $patron->set_password( { password => $patron_password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $test_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_id   = $test_patron->id;

    my $quota = $builder->build_object(
        {
            class => 'Koha::Patron::Quotas',
            value => { patron_id => $patron_id }
        }
    );

    $t->get_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id . "/usages" )
        ->status_is(200)
        ->json_is( [] );

    my $usage = $builder->build_object(
        {
            class => 'Koha::Patron::Quota::Usages',
            value => {
                patron_quota_id => $quota->id,
                patron_id       => $patron_id,
                issue_id        => undef,
                type            => 'ISSUE'
            }
        }
    );

    $t->get_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id . "/usages" )
        ->status_is(200)
        ->json_is( [ $usage->to_api ] );

    my $another_usage = $builder->build_object(
        {
            class => 'Koha::Patron::Quota::Usages',
            value => {
                patron_quota_id => $quota->id,
                patron_id       => $patron_id,
                issue_id        => undef,
                type            => 'ISSUE'
            }
        }
    );

    $t->get_ok( "//$userid:$password@/api/v1/patrons/$patron_id/quotas/" . $quota->id . "/usages" )
        ->status_is(200)
        ->json_is( [ $usage->to_api, $another_usage->to_api ] );

    $t->get_ok( "//$unauth_userid:$patron_password@/api/v1/patrons/$patron_id/quotas/" . $quota->id . "/usages" )
        ->status_is(403);

    my $quota_to_delete = $builder->build_object( { class => 'Koha::Patron::Quotas' } );
    my $non_existent_id = $quota_to_delete->id;
    $quota_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas/$non_existent_id/usages")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'query parameter validation' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**4 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_id = $patron->id;

    $t->get_ok("//$userid:$password@/api/v1/patrons/$patron_id/quotas?quota_blah=blah")
        ->status_is(400)
        ->json_is( [ { path => '/query/quota_blah', message => 'Malformed query string' } ] );

    $schema->storage->txn_rollback;
};
