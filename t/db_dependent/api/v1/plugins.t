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

use Test::More tests => 3;
use Test::NoWarnings;
use Test::Mojo;
use Test::MockModule;
use Test::MockObject;
use Mojo::JSON;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'add()' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }    # plugins flag
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins',     1 );
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );

    my $store_module   = Test::MockModule->new('Koha::Plugins::Store');
    my $install_module = Test::MockModule->new('Koha::Plugins::Install');
    my $fetch_module   = Test::MockModule->new('File::Fetch');

    $fetch_module->mock( fetch => sub { return '/tmp/does-not-matter.kpz' } );

    $store_module->mock(
        lookup_by_kpz_url => sub {
            return {
                repo_url           => 'https://github.com/openfifth/koha-plugin-coverflow',
                certification_tier => 'CERTIFIED'
            };
        }
    );

    $install_module->mock( install => sub { return ( 1, { digest => 'abc123' } ) } );

    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://example.com/plugin.kpz' } )
        ->status_is( 201, 'A successful install returns 201' );

    $install_module->mock( install => sub { return ( 0, { RESTRICTED => 1 } ) } );

    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://example.com/plugin.kpz' } )
        ->status_is( 403, 'A rejected install (per Koha::Plugins::Install) returns 403, not a silent install' );

    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => {} )
        ->status_is( 400, 'Missing kpz_url is a 400, not a crash' );

    # Test the case where Store doesn't have the plugin on record (lookup returns undef)
    # This is a legitimate real-world case where a kpz_url is from an unknown source
    $store_module->mock( lookup_by_kpz_url => sub { return undef } );

    $install_module->mock( install => sub { return ( 0, { RESTRICTED => 1 } ) } );

    $t->post_ok(
        "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://unknown-repo.example.com/plugin.kpz' } )
        ->status_is(
        403,
        'When Store lookup returns undef, delegation to Install with undef repo_url works correctly'
        );

    $schema->storage->txn_rollback;
};

subtest 'list()' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }    # plugins flag
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    my $enabled_plugin = Test::MockObject->new;
    $enabled_plugin->{class} = 'Koha::Plugin::Test::Enabled';
    $enabled_plugin->set_always(
        'get_metadata',
        {
            name            => 'Enabled Test Plugin',
            description     => 'A plugin for testing',
            author          => 'Koha',
            version         => '1.0.0',
            minimum_version => '24.05',
            maximum_version => undef,
            date_updated    => '2026-01-01',
        }
    );
    $enabled_plugin->set_always( 'is_enabled', 1 );
    $enabled_plugin->mock( 'configure', sub { return 1 } );

    my $disabled_plugin = Test::MockObject->new;
    $disabled_plugin->{class} = 'Koha::Plugin::Test::Disabled';
    $disabled_plugin->set_always(
        'get_metadata',
        {
            name        => 'Disabled Test Plugin',
            description => 'Another plugin for testing',
            author      => 'Koha',
            version     => '2.0.0',
        }
    );
    $disabled_plugin->set_always( 'is_enabled', 0 );

    my $plugins_module = Test::MockModule->new('Koha::Plugins');
    $plugins_module->mock(
        'GetPlugins',
        sub { return ( [ $enabled_plugin, $disabled_plugin ], [] ); }
    );

    $t->get_ok("//$userid:$password\@/api/v1/plugins")
        ->status_is(200)
        ->json_is( '/0/class'         => 'Koha::Plugin::Test::Enabled' )
        ->json_is( '/0/is_enabled'    => Mojo::JSON->true )
        ->json_is( '/0/can_configure' => Mojo::JSON->true )
        ->json_is( '/1/is_enabled'    => Mojo::JSON->false );

    $t->get_ok("//$userid:$password\@/api/v1/plugins?capability=configure")
        ->status_is(200)
        ->json_is( '/0/class' => 'Koha::Plugin::Test::Enabled' )
        ->json_hasnt('/1');

    $schema->storage->txn_rollback;
};
