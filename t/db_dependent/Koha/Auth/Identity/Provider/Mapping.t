#!/usr/bin/perl

# Copyright Koha Community 2026
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
use Test::More tests => 3;
use Test::Exception;

use Koha::Auth::Hostnames;
use Koha::Auth::Identity::Provider::Hostname;
use Koha::Auth::Identity::Provider::Mapping;
use Koha::Auth::Identity::Provider::Mappings;
use Koha::Auth::Identity::Providers;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Mapping::store() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );

    # Must throw if neither provider_field nor default_content is set
    throws_ok {
        Koha::Auth::Identity::Provider::Mapping->new(
            {
                identity_provider_id => $provider->id,
                koha_field           => 'userid',
            }
        )->store;
    }
    'Koha::Exceptions::MissingParameter',
        'Exception thrown when neither provider_field nor default_content is provided';

    like( $@->parameter, qr/provider_field or default_content/, 'Exception parameter message is correct' );

    # Succeeds with provider_field only
    my $m1 = Koha::Auth::Identity::Provider::Mapping->new(
        {
            identity_provider_id => $provider->id,
            koha_field           => 'userid',
            provider_field       => 'uid',
        }
    )->store;
    ok( $m1, 'store() succeeds when only provider_field is supplied' );

    # Succeeds with default_content only
    my $m2 = Koha::Auth::Identity::Provider::Mapping->new(
        {
            identity_provider_id => $provider->id,
            koha_field           => 'categorycode',
            default_content      => 'PT',
        }
    )->store;
    ok( $m2, 'store() succeeds when only default_content is supplied' );

    $schema->storage->txn_rollback;
};

subtest 'Mappings::as_auth_mapping() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );

    my $mapping = $provider->mappings->as_auth_mapping;
    is_deeply( $mapping, {}, 'Returns empty hashref when provider has no mappings' );

    # Create mappings: one with provider_field, one with default_content only
    $builder->build(
        {
            source => 'IdentityProviderMapping',
            value  => {
                identity_provider_id => $provider->id,
                koha_field           => 'userid',
                provider_field       => 'uid',
                default_content      => undef,
                sync_on_creation     => 1,
                sync_on_update       => 1,
            }
        }
    );
    $builder->build(
        {
            source => 'IdentityProviderMapping',
            value  => {
                identity_provider_id => $provider->id,
                koha_field           => 'categorycode',
                provider_field       => undef,
                default_content      => 'PT',
                sync_on_creation     => 1,
                sync_on_update       => 1,
            }
        }
    );

    $mapping = $provider->mappings->as_auth_mapping;
    is_deeply(
        $mapping,
        {
            userid => {
                is               => 'uid',
                content          => undef,
                sync_on_creation => 1,
                sync_on_update   => 1,
            },
            categorycode => {
                is               => undef,
                content          => 'PT',
                sync_on_creation => 1,
                sync_on_update   => 1,
            },
        },
        'Returns correct mapping hashref with is/content/sync keys for each koha_field'
    );

    # Matchpoint is stored on the hostname association, not the provider
    my $hostname_obj = $builder->build_object(
        { class => 'Koha::Auth::Hostnames', value => { hostname => 'matchpoint.example.com' } } );
    my $hostname_assoc = Koha::Auth::Identity::Provider::Hostname->new(
        {
            identity_provider_id => $provider->id,
            hostname_id          => $hostname_obj->hostname_id,
            matchpoint           => 'userid',
        }
    )->store;
    is( $hostname_assoc->matchpoint, 'userid', 'Hostname matchpoint is stored and retrieved correctly' );

    $schema->storage->txn_rollback;
};
