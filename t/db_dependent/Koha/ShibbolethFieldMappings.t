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
use Test::Exception;

use Koha::ShibbolethFieldMapping;
use Koha::ShibbolethFieldMappings;
use Koha::Database;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

subtest 'basic CRUD operations' => sub {
    plan tests => 4;

    $schema->resultset('ShibbolethFieldMapping')->delete;

    my $nb_of_mappings = Koha::ShibbolethFieldMappings->search->count;
    my $new_mapping_1  = Koha::ShibbolethFieldMapping->new(
        {
            idp_field     => 'eppn',
            koha_field    => 'userid',
            is_matchpoint => 1,
        }
    )->store;

    like( $new_mapping_1->mapping_id, qr|^\d+$|, 'Adding a new mapping should set the mapping_id' );
    is( Koha::ShibbolethFieldMappings->search->count, $nb_of_mappings + 1, 'The mapping should have been added' );

    my $retrieved_mapping_1 = Koha::ShibbolethFieldMappings->find( $new_mapping_1->mapping_id );
    is(
        $retrieved_mapping_1->koha_field, $new_mapping_1->koha_field,
        'Find a mapping by id should return the correct mapping'
    );

    $retrieved_mapping_1->delete;
    is( Koha::ShibbolethFieldMappings->search->count, $nb_of_mappings, 'Delete should have deleted the mapping' );
};

subtest 'store validation' => sub {
    plan tests => 2;

    $schema->resultset('ShibbolethFieldMapping')->delete;

    throws_ok {
        Koha::ShibbolethFieldMapping->new(
            {
                idp_field => 'eppn',
            }
        )->store;
    }
    'Koha::Exceptions::MissingParameter', 'Store without koha_field throws exception';

    throws_ok {
        Koha::ShibbolethFieldMapping->new(
            {
                koha_field => 'userid',
            }
        )->store;
    }
    'Koha::Exceptions::MissingParameter', 'Store without idp_field throws exception';
};

subtest 'ensure_single_matchpoint' => sub {
    plan tests => 3;

    $schema->resultset('ShibbolethFieldMapping')->delete;

    my $mapping1 = Koha::ShibbolethFieldMapping->new(
        {
            idp_field     => 'eppn',
            koha_field    => 'userid',
            is_matchpoint => 1
        }
    )->store;

    my $mapping2 = Koha::ShibbolethFieldMapping->new(
        {
            idp_field     => 'mail',
            koha_field    => 'email',
            is_matchpoint => 1
        }
    )->store;

    $mapping1->discard_changes;
    is( $mapping1->is_matchpoint, 0, 'First matchpoint was cleared' );
    is( $mapping2->is_matchpoint, 1, 'Second matchpoint remains set' );

    my $matchpoint_count = Koha::ShibbolethFieldMappings->search( { is_matchpoint => 1 } )->count;
    is( $matchpoint_count, 1, 'Only one matchpoint exists' );
};

subtest 'get_matchpoint' => sub {
    plan tests => 2;

    $schema->resultset('ShibbolethFieldMapping')->delete;

    my $mapping = $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => {
                idp_field     => 'eppn',
                koha_field    => 'userid',
                is_matchpoint => 1
            }
        }
    );

    my $matchpoint = Koha::ShibbolethFieldMappings->new->get_matchpoint;
    is( $matchpoint->mapping_id, $mapping->mapping_id, 'get_matchpoint returns correct mapping' );

    $mapping->is_matchpoint(0)->store;
    $matchpoint = Koha::ShibbolethFieldMappings->new->get_matchpoint;
    is( $matchpoint, undef, 'get_matchpoint returns undef when no matchpoint exists' );
};

subtest 'get_mapping_config' => sub {
    plan tests => 6;

    $schema->resultset('ShibbolethFieldMapping')->delete;

    my ( $success, $config ) = Koha::ShibbolethFieldMappings->new->get_mapping_config;
    is( $success, 0,     'get_mapping_config returns failure when no matchpoint' );
    is( $config,  undef, 'get_mapping_config returns undef config when no matchpoint' );

    $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => {
                idp_field       => 'eppn',
                koha_field      => 'userid',
                is_matchpoint   => 1,
                default_content => undef
            }
        }
    );

    $builder->build_object(
        {
            class => 'Koha::ShibbolethFieldMappings',
            value => {
                idp_field       => 'mail',
                koha_field      => 'email',
                is_matchpoint   => 0,
                default_content => undef
            }
        }
    );

    ( $success, $config ) = Koha::ShibbolethFieldMappings->new->get_mapping_config;
    is( $success,                           1,        'get_mapping_config returns success with valid mappings' );
    is( $config->{matchpoint},              'userid', 'Matchpoint field is correct' );
    is( $config->{mapping}->{userid}->{is}, 'eppn',   'userid mapping is correct' );
    is( $config->{mapping}->{email}->{is},  'mail',   'email mapping is correct' );
};

$schema->storage->txn_rollback;
