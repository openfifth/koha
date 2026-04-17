#!/usr/bin/env perl

# Copyright 2026 Theke Solutions
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

use Test::More tests => 7;
use Test::NoWarnings;
use Test::Mojo;
use Test::Warn;

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::Library::Calendar::WeeklyClosures;
use Koha::Library::Calendar::RepeatingClosures;
use Koha::Library::Calendar::SingleClosures;
use Koha::Library::Calendar::Exceptions;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 4 } } );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid     = $patron->userid;
    my $library_id = $library->id;

    # Empty calendar
    $t->get_ok("//$userid:$password\@/api/v1/libraries/$library_id/calendar")
        ->status_is(200)
        ->json_is( '/weekly_closures'    => [] )
        ->json_is( '/repeating_closures' => [] )
        ->json_is( '/single_closures'    => [] )
        ->json_is( '/exceptions'         => [] );

    # Add one of each
    $builder->build_object(
        {
            class => 'Koha::Library::Calendar::WeeklyClosures',
            value => { library_id => $library_id, weekday => 0, title => 'Sun', description => '' }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Library::Calendar::RepeatingClosures',
            value => { library_id => $library_id, day => 25, month => 12, title => 'Xmas', description => '' }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Library::Calendar::SingleClosures',
            value => { library_id => $library_id, date => '2026-06-15', title => 'Staff', description => '' }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Library::Calendar::Exceptions',
            value => { library_id => $library_id, date => '2026-12-25', title => 'Open', description => '' }
        }
    );

    $t->get_ok("//$userid:$password\@/api/v1/libraries/$library_id/calendar")->status_is(200);

    my $result = $t->tx->res->json;
    is( scalar @{ $result->{weekly_closures} }, 1, 'One weekly closure' );
    is( scalar @{ $result->{single_closures} }, 1, 'One single closure' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 16;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**13 } } );    # tools
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid     = $patron->userid;
    my $library_id = $library->id;

    # Add weekly closure
    $t->post_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/weekly_closures" => json =>
            { weekday => 0, title => 'Sundays', description => 'Closed' } )->status_is(201)->json_has('/weekday');

    # Add repeating closure
    $t->post_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/repeating_closures" => json =>
            { day => 25, month => 12, title => 'Christmas', description => '' } )->status_is(201)->json_has('/day');

    # Add single closure
    $t->post_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/single_closures" => json =>
            { date => '2026-06-15', title => 'Staff day', description => '' } )->status_is(201)->json_has('/date');

    # Add exception
    $t->post_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/closure_exceptions" => json =>
            { date => '2026-12-25', title => 'Special opening', description => '' } )
        ->status_is(201)
        ->json_has('/date');

    # Duplicate
    warning_like {
        $t->post_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/weekly_closures" => json =>
                { weekday => 0, title => 'Sundays again', description => '' } )
            ->status_is(409)
            ->json_is( '/error_code' => 'duplicate' );
    }
    qr/Duplicate/, 'DBIC duplicate warning expected';

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 4 } } );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid     = $patron->userid;
    my $library_id = $library->id;

    my $closure = $builder->build_object(
        {
            class => 'Koha::Library::Calendar::WeeklyClosures',
            value => {
                library_id => $library_id, weekday => 6, title => 'Saturdays', description => '',
            }
        }
    );

    $t->get_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/weekly_closures/" . $closure->id )
        ->status_is(200)
        ->json_is( '/title' => 'Saturdays' );

    # Not found
    $t->get_ok("//$userid:$password\@/api/v1/libraries/$library_id/calendar/weekly_closures/99999")->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**13 } } );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid     = $patron->userid;
    my $library_id = $library->id;

    my $closure = $builder->build_object(
        {
            class => 'Koha::Library::Calendar::SingleClosures',
            value => {
                library_id => $library_id, date => '2026-06-15', title => 'Old title', description => '',
            }
        }
    );

    $t->put_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/single_closures/"
            . $closure->id => json => { title => 'New title', description => 'Updated' } )
        ->status_is(200)
        ->json_is( '/title'       => 'New title' )
        ->json_is( '/description' => 'Updated' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**13 } } );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid     = $patron->userid;
    my $library_id = $library->id;

    my $closure = $builder->build_object(
        {
            class => 'Koha::Library::Calendar::Exceptions',
            value => {
                library_id => $library_id, date => '2026-12-25', title => 'To delete', description => '',
            }
        }
    );

    $t->delete_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/closure_exceptions/" . $closure->id )
        ->status_is(204);

    # Already deleted
    $t->delete_ok( "//$userid:$password\@/api/v1/libraries/$library_id/calendar/closure_exceptions/" . $closure->id )
        ->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'copy() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $source   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $target   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron   = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 2**13 } } );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    # Add closures to source
    $builder->build_object(
        {
            class => 'Koha::Library::Calendar::WeeklyClosures',
            value => {
                library_id => $source->id, weekday => 0, title => 'Sun', description => '',
            }
        }
    );
    $builder->build_object(
        {
            class => 'Koha::Library::Calendar::SingleClosures',
            value => {
                library_id => $source->id, date => '2027-01-01', title => 'NY', description => '',
            }
        }
    );

    my $target_id = $target->id;
    $t->post_ok( "//$userid:$password\@/api/v1/libraries/"
            . $target_id
            . "/calendar/copy" => json => { from_library_id => $source->id } )
        ->status_is(201)
        ->header_like( Location => qr|\Q/libraries/$target_id/calendar\E$| );

    is( Koha::Library::Calendar::WeeklyClosures->search( { library_id => $target->id } )->count, 1, 'Weekly copied' );
    is( Koha::Library::Calendar::SingleClosures->search( { library_id => $target->id } )->count, 1, 'Single copied' );

    # Idempotent
    $t->post_ok( "//$userid:$password\@/api/v1/libraries/"
            . $target->id
            . "/calendar/copy" => json => { from_library_id => $source->id } )->status_is(201);

    is( Koha::Library::Calendar::WeeklyClosures->search( { library_id => $target->id } )->count, 1, 'No duplicates' );

    $schema->storage->txn_rollback;
};
