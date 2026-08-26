#!/usr/bin/perl

# Copyright 2026 Koha Development team
#
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

use Test::More tests => 16;
use Test::NoWarnings;

use Mojo::JSON qw( encode_json );
use YAML::XS   qw( LoadFile );

use C4::Context;
use Koha::Result::Availability;

subtest 'new() creates empty result' => sub {

    plan tests => 5;

    my $result = Koha::Result::Availability->new();

    isa_ok( $result, 'Koha::Result::Availability', 'new() returns Result object' );
    is( ref( $result->blockers ),      'HASH', 'blockers is a hashref' );
    is( ref( $result->confirmations ), 'HASH', 'confirmations is a hashref' );
    is( ref( $result->warnings ),      'HASH', 'warnings is a hashref' );
    is( ref( $result->context ),       'HASH', 'context is a hashref' );
};

subtest 'add_blocker()' => sub {

    plan tests => 3;

    my $result = Koha::Result::Availability->new();

    $result->add_blocker( test_blocker => 'value' );

    is( $result->blockers->{test_blocker}, 'value', 'blocker added' );
    is( keys %{ $result->blockers },       1,       'one blocker present' );
    isa_ok( $result->add_blocker( another => 1 ), 'Koha::Result::Availability', 'returns self for chaining' );
};

subtest 'add_confirmation()' => sub {

    plan tests => 3;

    my $result = Koha::Result::Availability->new();

    $result->add_confirmation( test_confirm => 'value' );

    is( $result->confirmations->{test_confirm}, 'value', 'confirmation added' );
    is( keys %{ $result->confirmations },       1,       'one confirmation present' );
    isa_ok( $result->add_confirmation( another => 1 ), 'Koha::Result::Availability', 'returns self for chaining' );
};

subtest 'add_warning()' => sub {

    plan tests => 3;

    my $result = Koha::Result::Availability->new();

    $result->add_warning( test_warning => 'value' );

    is( $result->warnings->{test_warning}, 'value', 'warning added' );
    is( keys %{ $result->warnings },       1,       'one warning present' );
    isa_ok( $result->add_warning( another => 1 ), 'Koha::Result::Availability', 'returns self for chaining' );
};

subtest 'set_context()' => sub {

    plan tests => 3;

    my $result = Koha::Result::Availability->new();

    $result->set_context( item => 'test_item' );

    is( $result->context->{item},   'test_item', 'context value set' );
    is( keys %{ $result->context }, 1,           'one context value present' );
    isa_ok(
        $result->set_context( patron => 'test_patron' ), 'Koha::Result::Availability',
        'returns self for chaining'
    );
};

subtest 'available()' => sub {

    plan tests => 2;

    my $result = Koha::Result::Availability->new();

    ok( $result->available, 'available when no blockers' );

    $result->add_blocker( test => 1 );

    ok( !$result->available, 'not available when blockers present' );
};

subtest 'needs_confirmation()' => sub {

    plan tests => 2;

    my $result = Koha::Result::Availability->new();

    ok( !$result->needs_confirmation, 'no confirmation needed when empty' );

    $result->add_confirmation( test => 1 );

    ok( $result->needs_confirmation, 'confirmation needed when confirmations present' );
};

subtest 'to_hashref()' => sub {

    plan tests => 6;

    my $result = Koha::Result::Availability->new();

    $result->add_blocker( blocker1 => 'b1' );
    $result->add_confirmation( confirm1 => 'c1' );
    $result->add_warning( warning1 => 'w1' );
    $result->set_context( item   => 'test_item' );
    $result->set_context( patron => 'test_patron' );

    my $hashref = $result->to_hashref();

    is( ref($hashref),                    'HASH',        'returns hashref' );
    is( $hashref->{blockers}->{blocker1}, 'b1',          'blockers included' );
    is( $hashref->{confirms}->{confirm1}, 'c1',          'confirmations included as confirms' );
    is( $hashref->{warnings}->{warning1}, 'w1',          'warnings included' );
    is( $hashref->{item},                 'test_item',   'context item included at top level' );
    is( $hashref->{patron},               'test_patron', 'context patron included at top level' );
};

subtest 'to_api() with an empty result' => sub {

    plan tests => 5;

    my $api = Koha::Result::Availability->new->to_api;

    ok( $api->{available},           'available is true when there is no blocker' );
    ok( !$api->{needs_confirmation}, 'needs_confirmation is false when there is no confirmation' );
    is_deeply( $api->{blockers},      [], 'blockers is an empty array' );
    is_deeply( $api->{confirmations}, [], 'confirmations is an empty array' );
    is_deeply( $api->{warnings},      [], 'warnings is an empty array' );
};

subtest 'to_api() with a value of 1' => sub {

    plan tests => 3;

    my $result = Koha::Result::Availability->new->add_blocker( damaged => 1 );
    my $api    = $result->to_api;

    ok( !$api->{available}, 'available is false when there is a blocker' );
    is_deeply(
        $api->{blockers},
        [ { code => 'damaged', overridable => Mojo::JSON->true } ],
        'A value of 1 carries no payload'
    );
    ok( !exists $api->{blockers}->[0]->{payload}, 'The payload key is absent rather than undefined' );
};

subtest 'to_api() with a hashref value' => sub {

    plan tests => 2;

    my $payload = { total_outstanding => 12.5, max_outstanding => 5 };
    my $result  = Koha::Result::Availability->new->add_blocker( debt_limit => $payload );

    is_deeply(
        $result->to_api->{blockers},
        [
            {
                code        => 'debt_limit',
                overridable => Mojo::JSON->true,
                payload     => { total_outstanding => 12.5, max_outstanding => 5 }
            }
        ],
        'A hashref value becomes the payload'
    );

    $result->to_api->{blockers}->[0]->{payload}->{max_outstanding} = 999;

    is(
        $payload->{max_outstanding}, 5,
        'A change to the response does not reach the result object'
    );
};

subtest 'to_api() with a count limit' => sub {

    plan tests => 4;

    my @cases = (
        { code => 'too_many_reserves',              limit => 3 },
        { code => 'too_many_reserves_today',        limit => 2 },
        { code => 'too_many_holds_for_this_record', limit => 1 },
    );

    for my $case (@cases) {

        my $result = Koha::Result::Availability->new->add_blocker( $case->{code} => $case->{limit} );

        is_deeply(
            $result->to_api->{blockers},
            [
                {
                    code        => $case->{code},
                    overridable => Mojo::JSON->false,
                    payload     => { limit => $case->{limit} }
                }
            ],
            sprintf( 'The %s code carries its limit, even a limit of 1', $case->{code} )
        );
    }

    # Circulation rule values arrive from the database as strings. The API must
    # render a limit as a number.
    my $result = Koha::Result::Availability->new->add_blocker( too_many_reserves => '4' );

    like(
        encode_json( $result->to_api->{blockers} ),
        qr/"limit":4/,
        'A limit encodes as a JSON number rather than a string'
    );
};

subtest 'to_api() sets overridable from OVERRIDABLE_CODES' => sub {

    plan tests => 2;

    my $result = Koha::Result::Availability->new;
    $result->add_blocker( damaged               => 1 );
    $result->add_blocker( cannot_be_transferred => 1 );

    my $blockers = { map { $_->{code} => $_->{overridable} } @{ $result->to_api->{blockers} } };

    is( $blockers->{damaged}, Mojo::JSON->true, 'An override-able code is flagged overridable' );
    is(
        $blockers->{cannot_be_transferred}, Mojo::JSON->false,
        'A code that is not in OVERRIDABLE_CODES is flagged not overridable'
    );
};

subtest 'to_api() with confirmations, warnings and a stable order' => sub {

    plan tests => 5;

    my $result = Koha::Result::Availability->new;
    $result->add_confirmation( recall => 1 );
    $result->add_warning( withdrawn => 1 );
    $result->add_blocker( restricted  => 1 );
    $result->add_blocker( damaged     => 1 );
    $result->add_blocker( bad_address => 1 );

    # The context holds live objects, so to_api must leave it out. The
    # availability definition sets additionalProperties to false, so a context
    # key in the response would fail API validation.
    $result->set_context( available_item => 'an object' );

    my $api = $result->to_api;

    ok( $api->{needs_confirmation}, 'needs_confirmation is true when there is a confirmation' );
    is_deeply(
        $api->{confirmations},
        [ { code => 'recall', overridable => Mojo::JSON->false } ],
        'Confirmations are rendered'
    );
    is_deeply(
        $api->{warnings},
        [ { code => 'withdrawn', overridable => Mojo::JSON->false } ],
        'Warnings are rendered'
    );

    is_deeply(
        [ map { $_->{code} } @{ $api->{blockers} } ],
        [ 'bad_address', 'damaged', 'restricted' ],
        'The codes are sorted, so the response is stable'
    );

    is_deeply(
        [ sort keys %{$api} ],
        [ 'available', 'blockers', 'confirmations', 'needs_confirmation', 'warnings' ],
        'The response holds no context data and no other key'
    );
};

subtest 'OVERRIDABLE_CODES stays in step with the addHold x-koha-override enum' => sub {

    plan tests => 1;

    # OVERRIDABLE_CODES is what Koha::Item::Availability::Hold and
    # Koha::Patron::Availability::Hold actually respect via
    # $overrides->{$code} (see the constant's own POD) - both are reachable
    # through POST /holds (addHold), via CanItemBeReserved/CanBookBeReserved.
    # addHold validates its x-koha-override header against this enum before
    # the controller ever runs, so a code missing here would advertise
    # overridable => true in a holdability response and then be rejected
    # outright the moment a caller actually tries to override it.
    my $paths_file = C4::Context->config('intranetdir') . '/api/v1/swagger/paths/holds.yaml';
    my $spec        = LoadFile($paths_file);
    my ($override_param) =
        grep { $_->{name} eq 'x-koha-override' } @{ $spec->{'/holds'}{post}{parameters} };

    my %enum = map { $_ => 1 } @{ $override_param->{items}{enum} };

    my @missing = sort grep { !$enum{$_} } keys %{ Koha::Result::Availability::OVERRIDABLE_CODES() };

    is_deeply(
        \@missing, [],
        "Every OVERRIDABLE_CODES key is offered by addHold's x-koha-override enum"
    );
};
