#!/usr/bin/perl

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

use Test::NoWarnings;
use Test::More tests => 5;
use Test::Mojo;
use YAML::XS qw( LoadFile );

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Context;
use Koha::Database;
use Koha::RecordMatchers;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';

sub patron_with_tools_permission {
    my ($code) = @_;
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 4096 } } );
    if ($code) {
        $dbh->prepare(
            "INSERT INTO user_permissions (borrowernumber, module_bit, code) SELECT ?, bit, ? FROM userflags WHERE flag = ?"
        )->execute( $patron->borrowernumber, $code, 'tools' );
    }
    $patron->set_password( { password => $password, skip_validation => 1 } );
    return $patron;
}

subtest 'unauthorised access' => sub {
    plan tests => 4;
    $schema->storage->txn_begin;

    my $nopermission = patron_with_tools_permission();
    my $uid          = $nopermission->userid;

    $t->get_ok("//$uid:$password@/api/v1/record_matchers")->status_is(403);

    my $matcher = $builder->build_object( { class => 'Koha::RecordMatchers' } );
    $t->get_ok( "//$uid:$password@/api/v1/record_matchers/" . $matcher->matcher_id )->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'list() tests' => sub {
    plan tests => 12;
    $schema->storage->txn_begin;

    Koha::RecordMatchers->search->delete;
    my $m1 = $builder->build_object( { class => 'Koha::RecordMatchers', value => { code => 'A_RM' } } );
    my $m2 = $builder->build_object( { class => 'Koha::RecordMatchers', value => { code => 'B_RM' } } );

    # Either permission is enough
    for my $code (qw(stage_marc_import manage_staged_marc)) {
        my $patron = patron_with_tools_permission($code);
        my $uid    = $patron->userid;
        $t->get_ok("//$uid:$password@/api/v1/record_matchers?_order_by=+code")
            ->status_is( 200, "list allowed with $code" )
            ->json_is( '/0/code' => 'A_RM' )
            ->json_is( '/1/code' => 'B_RM' );
    }

    my $patron = patron_with_tools_permission('stage_marc_import');
    my $uid    = $patron->userid;
    $t->get_ok("//$uid:$password@/api/v1/record_matchers?code=B_RM")
        ->status_is(200)
        ->json_is( '/0/record_matcher_id' => $m2->matcher_id )
        ->json_hasnt('/1');

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {
    plan tests => 8;
    $schema->storage->txn_begin;

    my $matcher = $builder->build_object( { class => 'Koha::RecordMatchers' } );
    my $patron  = patron_with_tools_permission('stage_marc_import');
    my $uid     = $patron->userid;
    my $id      = $matcher->matcher_id;

    $t->get_ok("//$uid:$password@/api/v1/record_matchers/$id")
        ->status_is(200)
        ->json_is( '' => $matcher->to_api, 'Matcher returned as API representation' );

    my $missing = $id + 100000;
    $t->get_ok("//$uid:$password@/api/v1/record_matchers/$missing")
        ->status_is(404)
        ->json_is( '/error' => 'Record matcher not found' );

    $t->get_ok("//$uid:$password@/api/v1/record_matchers/notanumber")->status_is(400);

    $schema->storage->txn_rollback;
};

subtest 'definition' => sub {
    plan tests => 1;

    my $definition = LoadFile('api/v1/swagger/definitions/record_matcher.yaml');

    # Every column is NOT NULL, so every exposed field is always present
    is_deeply(
        [ sort @{ $definition->{required} } ],
        [ sort keys %{ $definition->{properties} } ],
        'All properties are listed as required'
    );
};

1;
