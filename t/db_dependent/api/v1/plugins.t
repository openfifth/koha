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

use Test::More tests => 8;
use Test::NoWarnings;
use Test::Mojo;
use Test::MockModule;
use Test::MockObject;
use Mojo::JSON;
use File::Temp;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'add()' => sub {

    plan tests => 17;

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

    is(
        $t->tx->res->json->{error}, 'RESTRICTED',
        'the harmonized error shape reports a single code, matching upload()'
    );

    $install_module->mock( install => sub { return ( 0, { SIGNATUREMISMATCH => 1, BELOWMINIMUMLEVEL => 1 } ) } );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://example.com/plugin.kpz' } )
        ->status_is(403);
    is(
        $t->tx->res->json->{error}, 'SIGNATUREMISMATCH',
        'when multiple errors are present, SIGNATUREMISMATCH is reported ahead of BELOWMINIMUMLEVEL'
    );

    $install_module->mock(
        install => sub {
            my ( $class, $params ) = @_;
            return ( 1, { digest                  => 'abc123' } ) if $params->{confirm_unsigned};
            return ( 0, { UNSIGNEDCONFIRMREQUIRED => 1 } );
        }
    );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://example.com/plugin.kpz' } )
        ->status_is(403)
        ->json_is( '/error' => 'UNSIGNEDCONFIRMREQUIRED' );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json =>
            { kpz_url => 'https://example.com/plugin.kpz', confirm_unsigned => \1 } )
        ->status_is( 201, 'confirm_unsigned is threaded through to install()' );

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

subtest 'list() with KohaTable-style query parameters' => sub {

    # KohaTable always issues its ajax requests with these parameters when
    # given a `url` (it runs DataTables in serverSide mode unconditionally).
    # Regression test for bug where the endpoint 400'd because these weren't
    # declared in the swagger spec.

    plan tests => 10;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    my $plugin_b = Test::MockObject->new;
    $plugin_b->{class} = 'Koha::Plugin::Test::BBB';
    $plugin_b->set_always(
        'get_metadata',
        { name => 'BBB Plugin', description => 'second', author => 'Koha', version => '1.0.0' }
    );
    $plugin_b->set_always( 'is_enabled', 1 );

    my $plugin_a = Test::MockObject->new;
    $plugin_a->{class} = 'Koha::Plugin::Test::AAA';
    $plugin_a->set_always(
        'get_metadata',
        { name => 'AAA Plugin', description => 'first', author => 'Koha', version => '1.0.0' }
    );
    $plugin_a->set_always( 'is_enabled', 1 );

    my $plugins_module = Test::MockModule->new('Koha::Plugins');
    $plugins_module->mock(
        'GetPlugins',
        sub { return ( [ $plugin_b, $plugin_a ], [] ); }
    );

    # exactly what _dt_default_ajax sends for the table's own initial draw
    $t->get_ok("//$userid:$password\@/api/v1/plugins?_page=1&_per_page=20&_match=contains&_order_by=%2Bme.name")
        ->status_is( 200, 'KohaTable-style params are accepted, not a 400' )
        ->header_is( 'X-Total-Count' => 2 )
        ->json_is( '/0/class' => 'Koha::Plugin::Test::AAA', '_order_by=+me.name sorts ascending by name' )
        ->json_is( '/1/class' => 'Koha::Plugin::Test::BBB' );

    # exactly what Home.vue's own getAll() sends (no pagination wanted)
    $t->get_ok("//$userid:$password\@/api/v1/plugins?_per_page=-1")
        ->status_is( 200, '_per_page=-1 (get everything) is accepted, not a 400' )
        ->json_hasnt( '/2', '_per_page=-1 returns every row, unpaginated' );

    $t->get_ok("//$userid:$password\@/api/v1/plugins?_page=1&_per_page=1&_order_by=%2Bme.name")
        ->json_is( '/0/class' => 'Koha::Plugin::Test::AAA', '_per_page=1 returns only the first page' );

    $schema->storage->txn_rollback;
};

subtest 'config()' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }    # plugins flag (full access)
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    $t->get_ok("//$userid:$password\@/api/v1/plugins/config")
        ->status_is(200)
        ->json_has('/permissions')
        ->json_is( '/permissions/CAN_user_plugins_manage' => Mojo::JSON->true );

    $schema->storage->txn_rollback;
};

subtest 'update()' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    my $handler_module = Test::MockModule->new('Koha::Plugins::Handler');
    my @run_calls;
    $handler_module->mock(
        'run',
        sub {
            my ( $class, $args ) = @_;
            push @run_calls, $args;
            return 1;
        }
    );

    $t->put_ok(
        "//$userid:$password\@/api/v1/plugins/Koha::Plugin::Test" => json => { is_enabled => Mojo::JSON->true } )
        ->status_is(200)
        ->json_is( '/success' => 'Plugin updated' );

    is( $run_calls[0]->{class},  'Koha::Plugin::Test', 'Handler->run called with the right class' );
    is( $run_calls[0]->{method}, 'enable',             'is_enabled true dispatches to enable' );

    $t->put_ok(
        "//$userid:$password\@/api/v1/plugins/Koha::Plugin::Test" => json => { is_enabled => Mojo::JSON->false } )
        ->status_is(200);
    is( $run_calls[1]->{method}, 'disable', 'is_enabled false dispatches to disable' );

    $t->put_ok( "//$userid:$password\@/api/v1/plugins/Koha::Plugin::Test" => json => {} )
        ->status_is(400)
        ->json_is( '/error' => 'Missing is_enabled' );

    $schema->storage->txn_rollback;
};

subtest 'delete()' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    my $handler_module = Test::MockModule->new('Koha::Plugins::Handler');
    my $deleted_class;
    $handler_module->mock(
        'delete',
        sub {
            my ( $class, $args ) = @_;
            $deleted_class = $args->{class};
            return 1;
        }
    );

    $t->delete_ok("//$userid:$password\@/api/v1/plugins/Koha::Plugin::Test")->status_is(204);

    is( $deleted_class, 'Koha::Plugin::Test', 'Handler->delete called with the right class' );

    $schema->storage->txn_rollback;
};

subtest 'upload()' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'enable_plugins',     1 );
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );

    my $install_module = Test::MockModule->new('Koha::Plugins::Install');
    $install_module->mock( 'install', sub { return ( 1, {} ) } );

    my $upload_dir = File::Temp::tempdir( CLEANUP => 1 );
    my $kpz_path   = "$upload_dir/test-plugin.kpz";
    open my $fh, '>', $kpz_path or die $!;
    print $fh 'not a real zip, just bytes for the upload test';
    close $fh;

    $t->post_ok( "//$userid:$password\@/api/v1/plugins/upload" => form => { file => { file => $kpz_path } } )
        ->status_is(201)
        ->json_is( '/success' => 'Plugin installed' );

    t::lib::Mocks::mock_config( 'plugins_restricted', 1 );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins/upload" => form => { file => { file => $kpz_path } } )
        ->status_is(403);

    is( $t->tx->res->json->{error}, 'RESTRICTED', 'plugins_restricted rejects manual upload with RESTRICTED' );

    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );
    $install_module->mock(
        'install',
        sub {
            my ( $class, $params ) = @_;
            return ( 1, {} ) if $params->{confirm_unsigned};
            return ( 0, { UNSIGNEDCONFIRMREQUIRED => 1 } );
        }
    );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins/upload" => form => { file => { file => $kpz_path } } )
        ->status_is(403)
        ->json_is( '/error' => 'UNSIGNEDCONFIRMREQUIRED' );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins/upload" => form =>
            { file => { file => $kpz_path }, confirm_unsigned => 1 } )
        ->status_is( 201, 'confirm_unsigned is threaded through upload() to install()' );

    $schema->storage->txn_rollback;
};
