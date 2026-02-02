#!/usr/bin/perl

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
use Test::More tests => 6;

use Koha::ShibbolethConfig;
use Koha::ShibbolethConfigs;
use Koha::Database;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

subtest 'get_configuration' => sub {
    plan tests => 3;

    $schema->resultset('ShibbolethConfig')->delete;

    my $config = Koha::ShibbolethConfigs->new->get_configuration;

    is( $config->shibboleth_config_id, 1, 'Configuration always has ID 1' );
    is( $config->force_opac_sso,       0, 'Default force_opac_sso is 0' );
    is( $config->autocreate,           0, 'Default autocreate is 0' );
};

subtest 'store always updates singleton' => sub {
    plan tests => 3;

    $schema->resultset('ShibbolethConfig')->delete;

    my $config1 = Koha::ShibbolethConfig->new(
        {
            force_opac_sso  => 1,
            force_staff_sso => 0,
            autocreate      => 1,
            sync            => 1,
            welcome         => 0
        }
    )->store;

    is( $config1->shibboleth_config_id, 1, 'First config has ID 1' );

    my $config2 = Koha::ShibbolethConfig->new(
        {
            force_opac_sso  => 0,
            force_staff_sso => 1,
            autocreate      => 0,
            sync            => 0,
            welcome         => 1
        }
    )->store;

    is( $config2->shibboleth_config_id,         1, 'Second store still has ID 1' );
    is( Koha::ShibbolethConfigs->search->count, 1, 'Only one config exists' );
};

subtest 'get_value' => sub {
    plan tests => 3;

    $schema->resultset('ShibbolethConfig')->delete;

    my $config = Koha::ShibbolethConfigs->new->get_configuration;
    $config->force_opac_sso(1)->store;

    is( $config->get_value('force_opac_sso'),  1,     'get_value returns correct value' );
    is( $config->get_value('force_staff_sso'), 0,     'get_value returns correct default' );
    is( $config->get_value('nonexistent'),     undef, 'get_value returns undef for nonexistent column' );
};

subtest 'mappings' => sub {
    plan tests => 1;

    $schema->resultset('ShibbolethConfig')->delete;

    my $config   = Koha::ShibbolethConfigs->new->get_configuration;
    my $mappings = $config->mappings;

    isa_ok( $mappings, 'Koha::ShibbolethFieldMappings', 'mappings returns correct type' );
};

subtest 'get_combined_config' => sub {
    plan tests => 4;

    $schema->resultset('ShibbolethConfig')->delete;
    $schema->resultset('ShibbolethFieldMapping')->delete;

    my $config = Koha::ShibbolethConfigs->new->get_configuration;
    $config->force_opac_sso(1)->store;

    $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => {
                idp_field     => 'eppn',
                koha_field    => 'userid',
                is_matchpoint => 1
            }
        }
    );

    $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => {
                idp_field     => 'mail',
                koha_field    => 'email',
                is_matchpoint => 0
            }
        }
    );

    my $combined = $config->get_combined_config;

    is( $combined->{force_opac_sso}, 1,        'Combined config includes base settings' );
    is( $combined->{matchpoint},     'userid', 'Combined config includes matchpoint' );
    ok( exists $combined->{mapping}->{userid}, 'Combined config includes userid mapping' );
    ok( exists $combined->{mapping}->{email},  'Combined config includes email mapping' );
};

$schema->storage->txn_rollback;
