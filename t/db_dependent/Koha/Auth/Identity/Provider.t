#!/usr/bin/perl

# Copyright 2022 Theke Solutions
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

use Test::NoWarnings;
use Test::More tests => 8;

use Test::MockModule;
use Test::Exception;

use JSON qw(encode_json);

use Koha::Auth::Hostnames;
use Koha::Auth::Identity::Provider;
use Koha::Auth::Identity::Provider::Hostnames;
use Koha::Auth::Identity::Provider::Mappings;
use Koha::Auth::Identity::Providers;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'domains() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $domains  = $provider->domains;

    is( ref($domains),   'Koha::Auth::Identity::Provider::Domains', 'Type is correct' );
    is( $domains->count, 0,                                         'No domains defined' );

    $builder->build_object(
        { class => 'Koha::Auth::Identity::Provider::Domains', value => { identity_provider_id => $provider->id } } );
    $builder->build_object(
        { class => 'Koha::Auth::Identity::Provider::Domains', value => { identity_provider_id => $provider->id } } );

    is( $provider->domains->count, 2, 'The provider has 2 domains defined' );

    $schema->storage->txn_rollback;
};

subtest 'get_config() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers', value => { config => '{' } } );

    throws_ok { $provider->get_config() }
    'Koha::Exceptions::Object::BadValue', 'Expected exception thrown on bad JSON';

    my $config = { some => 'value', and => 'another' };
    $provider->config( encode_json($config) )->store;

    is_deeply( $provider->get_config, $config, 'Config correctly retrieved' );

    $schema->storage->txn_rollback;
};

subtest 'set_config() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    subtest 'OIDC protocol tests' => sub {

        plan tests => 4;

        my $provider =
            $builder->build_object( { class => 'Koha::Auth::Identity::Providers', value => { protocol => 'OIDC' } } );

        my $config = {
            key    => 'key',
            secret => 'secret',
        };

        throws_ok { $provider->set_config($config) }
        'Koha::Exceptions::MissingParameter', 'Exception thrown on missing parameter';

        is( $@->parameter, 'well_known_url', 'Message is correct' );

        $config->{well_known_url} = 'https://koha-community.org/auth';

        my $return = $provider->set_config($config);
        is( ref($return), 'Koha::Auth::Identity::Provider::OIDC', 'Return type is correct' );

        is_deeply( $provider->get_config, $config, 'Configuration stored correctly' );
    };

    subtest 'OAuth protocol tests' => sub {

        plan tests => 4;

        my $provider =
            $builder->build_object( { class => 'Koha::Auth::Identity::Providers', value => { protocol => 'OAuth' } } );

        my $config = {
            key       => 'key',
            secret    => 'secret',
            token_url => 'https://koha-community.org/auth/token',
        };

        throws_ok { $provider->set_config($config) }
        'Koha::Exceptions::MissingParameter', 'Exception thrown on missing parameter';

        is( $@->parameter, 'authorize_url', 'Message is correct' );

        $config->{authorize_url} = 'https://koha-community.org/auth/authorize';

        my $return = $provider->set_config($config);
        is( ref($return), 'Koha::Auth::Identity::Provider::OAuth', 'Return type is correct' );

        is_deeply( $provider->get_config, $config, 'Configuration stored correctly' );
    };

    subtest 'Base class (unsupported protocol) tests' => sub {

        plan tests => 2;

        # Cannot build in DB with invalid protocol; instantiate base class directly
        my $provider = Koha::Auth::Identity::Provider->new( { protocol => 'OAuth' } );

        throws_ok { $provider->set_config( {} ) }
        'Koha::Exception', 'Exception thrown when calling set_config on base class';

        like( "$@", qr/This method needs to be subclassed/, 'Message is correct' );
    };

    $schema->storage->txn_rollback;
};

subtest 'mappings() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $mappings = $provider->mappings;

    is( ref($mappings),   'Koha::Auth::Identity::Provider::Mappings', 'Type is correct' );
    is( $mappings->count, 0,                                          'No mappings defined' );

    $builder->build(
        {
            source => 'IdentityProviderMapping',
            value  => { identity_provider_id => $provider->id, koha_field => 'userid', provider_field => 'uid' }
        }
    );
    $builder->build(
        {
            source => 'IdentityProviderMapping',
            value  => { identity_provider_id => $provider->id, koha_field => 'email', provider_field => 'mail' }
        }
    );

    is( $provider->mappings->count, 2, 'The provider has 2 mappings defined' );

    $schema->storage->txn_rollback;
};

subtest 'hostnames() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $provider  = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $hostnames = $provider->hostnames;

    is( ref($hostnames),   'Koha::Auth::Identity::Provider::Hostnames', 'Type is correct' );
    is( $hostnames->count, 0,                                           'No hostnames defined' );

    $builder->build_object(
        { class => 'Koha::Auth::Identity::Provider::Hostnames', value => { identity_provider_id => $provider->id } } );
    $builder->build_object(
        { class => 'Koha::Auth::Identity::Provider::Hostnames', value => { identity_provider_id => $provider->id } } );

    is( $provider->hostnames->count, 2, 'The provider has 2 hostnames defined' );

    $schema->storage->txn_rollback;
};

subtest 'polymorphic_retrieval() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $providers = Koha::Auth::Identity::Providers->new;
    my $mapping   = $providers->_polymorphic_map;
    my @protocols = keys %{$mapping};

    foreach my $protocol (@protocols) {

        my $provider = $builder->build_object(
            {
                class => 'Koha::Auth::Identity::Providers',
                value => { protocol => $protocol },
            }
        );

        is( ref($provider), $mapping->{$protocol}, "build_object returns correct subclass for $protocol" );

        my $found = Koha::Auth::Identity::Providers->find( $provider->id );
        is( ref($found), $mapping->{$protocol}, "Providers->find returns correct subclass for $protocol" );
    }

    my $provider = Koha::Auth::Identity::Provider->new( { protocol => 'Invalid' } );
    throws_ok { $provider->set_config( {} ) } 'Koha::Exception', 'Exception thrown calling set_config on base class';

    $schema->storage->txn_rollback;
};

subtest 'find_exclusive_provider() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    # No hostname argument returns undef
    is(
        Koha::Auth::Identity::Providers->find_exclusive_provider(undef), undef,
        'Returns undef when hostname is undef'
    );
    is(
        Koha::Auth::Identity::Providers->find_exclusive_provider(''), undef,
        'Returns undef when hostname is empty string'
    );

    my $provider = $builder->build_object(
        { class => 'Koha::Auth::Identity::Providers', value => { protocol => 'OIDC', enabled => 1 } } );

    my $hostname_record =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'sso.example.com' } } );

    # Hostname linked but is_exclusive=0 (default)
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $provider->id,
                hostname_id          => $hostname_record->hostname_id,
                is_enabled           => 1,
                is_exclusive         => 0,
            }
        }
    );
    is(
        Koha::Auth::Identity::Providers->find_exclusive_provider('sso.example.com'),
        undef, 'Returns undef when hostname is linked but is_exclusive is 0'
    );

    # Update to is_exclusive=1 but is_enabled=0 on the hostname link
    Koha::Auth::Identity::Provider::Hostnames->search(
        { identity_provider_id => $provider->id, hostname_id => $hostname_record->hostname_id } )
        ->update( { is_exclusive => 1, is_enabled => 0 } );
    is(
        Koha::Auth::Identity::Providers->find_exclusive_provider('sso.example.com'),
        undef, 'Returns undef when hostname link has is_enabled=0'
    );

    # Enable the hostname link but disable the provider itself
    Koha::Auth::Identity::Provider::Hostnames->search(
        { identity_provider_id => $provider->id, hostname_id => $hostname_record->hostname_id } )
        ->update( { is_enabled => 1 } );
    $provider->update( { enabled => 0 } );
    is(
        Koha::Auth::Identity::Providers->find_exclusive_provider('sso.example.com'),
        undef, 'Returns undef when provider itself is disabled'
    );

    # Re-enable the provider - now all conditions met
    $provider->update( { enabled => 1 } );
    my $exclusive = Koha::Auth::Identity::Providers->find_exclusive_provider('sso.example.com');
    ok( $exclusive, 'Returns provider when hostname linked with is_exclusive=1, is_enabled=1, and provider enabled=1' );
    is(
        ref($exclusive), 'Koha::Auth::Identity::Provider::OIDC',
        'Returned object is the correct Identity Provider subclass'
    );
    is( $exclusive->id, $provider->id, 'Returns the correct provider' );

    $schema->storage->txn_rollback;
};
