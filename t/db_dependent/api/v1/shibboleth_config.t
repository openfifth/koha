#!/usr/bin/env perl

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
use Test::More tests => 3;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ShibbolethConfigs;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'get() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    $schema->resultset('ShibbolethConfig')->delete;

    my $config = Koha::ShibbolethConfigs->new->get_configuration;

    $t->get_ok("//$userid:$password@/api/v1/shibboleth/config")->status_is(200)->json_is( $config->to_api );

    $t->get_ok("//$unauth_userid:$password@/api/v1/shibboleth/config")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**3 }
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

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    $schema->resultset('ShibbolethConfig')->delete;

    my $config = Koha::ShibbolethConfigs->new->get_configuration;

    my $updated_config = {
        force_opac_sso  => 1,
        force_staff_sso => 1,
        autocreate      => 1,
        sync            => 1,
        welcome         => 0
    };

    $t->put_ok( "//$unauth_userid:$password@/api/v1/shibboleth/config" => json => $updated_config )->status_is(403);

    $t->put_ok( "//$userid:$password@/api/v1/shibboleth/config" => json => $updated_config )->status_is(200)
        ->json_is( '/force_opac_sso' => 1 )->json_is( '/force_staff_sso' => 1 )->json_is( '/autocreate' => 1 )
        ->json_is( '/sync'           => 1 )->json_is( '/welcome'         => 0 );

    my $updated = Koha::ShibbolethConfigs->find(1);
    is( $updated->force_opac_sso, 1, 'force_opac_sso updated in database' );

    $schema->storage->txn_rollback;
};
