#!/usr/bin/perl

# Copyright 2026 Koha Development Team
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

use Test::More tests => 8;
use Test::MockModule;
use Test::NoWarnings;

use JSON qw( encode_json );

use Koha::Auth::Client::SAML2;
use Koha::Database;
use Koha::Patron::Attribute;
use Koha::Patron::Attributes;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------

# Build a minimal enabled SAML2 provider with a linked hostname and one or
# more field mappings.  Returns ($provider, $hostname_obj).
#
# Options (hashref):
#   hostname   - hostname string (default: 'saml-test.library.com')
#   matchpoint - matchpoint field (default: 'userid')
#   config     - provider config hashref (default: {})
#   mappings   - arrayref of { koha_field, provider_field, sync_on_update, sync_on_creation }
#                (default: [ { koha_field => 'userid', provider_field => 'uid' } ])
sub _build_provider {
    my ($opts) = @_;
    $opts //= {};

    my $hostname   = $opts->{hostname}   // 'saml-test.library.com';
    my $matchpoint = $opts->{matchpoint} // 'userid';
    my $config     = $opts->{config}     // {};
    my $mappings   = $opts->{mappings}   // [ { koha_field => 'userid', provider_field => 'uid' } ];

    my $provider = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Providers',
            value => { protocol => 'SAML2', enabled => 1, config => encode_json($config) },
        }
    );

    my $hostname_obj =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => $hostname } } );

    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $provider->id,
                hostname_id          => $hostname_obj->id,
                is_enabled           => 1,
                matchpoint           => $matchpoint,
            },
        }
    );

    for my $m ( @{$mappings} ) {
        $builder->build_object(
            {
                class => 'Koha::Auth::Identity::Provider::Mappings',
                value => {
                    identity_provider_id => $provider->id,
                    koha_field           => $m->{koha_field},
                    provider_field       => $m->{provider_field},
                    sync_on_update       => $m->{sync_on_update}   // 0,
                    sync_on_creation     => $m->{sync_on_creation} // 0,
                },
            }
        );
    }

    return ( $provider, $hostname_obj );
}

# -----------------------------------------------------------------------
# _get_data_and_patron() - basic attribute mapping
# -----------------------------------------------------------------------

subtest '_get_data_and_patron() - maps SAML attributes and finds patron by regular field' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { userid => 'jdoe_saml' } } );

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'saml1.library.com',
            matchpoint => 'userid',
            mappings   => [
                { koha_field => 'userid',    provider_field => 'uid' },
                { koha_field => 'firstname', provider_field => 'givenName' },
                { koha_field => 'email',     provider_field => 'mail' },
            ],
        }
    );

    my $saml_attrs = {
        uid       => 'jdoe_saml',
        givenName => 'Jane',
        mail      => 'jane@example.com',
    };

    my ( $mapped_data, $found_patron ) = $client->_get_data_and_patron(
        {
            provider => $provider,
            data     => $saml_attrs,
            hostname => 'saml1.library.com',
        }
    );

    is( $mapped_data->{userid},    'jdoe_saml',        'userid mapped correctly' );
    is( $mapped_data->{firstname}, 'Jane',             'firstname mapped correctly' );
    is( $mapped_data->{email},     'jane@example.com', 'email mapped correctly' );
    is( $found_patron->id,         $patron->id,        'patron found by userid matchpoint' );

    # No patron found for unknown value
    my ( undef, $no_patron ) = $client->_get_data_and_patron(
        {
            provider => $provider,
            data     => { uid => 'nobody_saml', givenName => 'X', mail => 'x@x.com' },
            hostname => 'saml1.library.com',
        }
    );
    is( $no_patron, undef, 'returns undef patron when not found' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# _get_data_and_patron() - patron_attribute: matchpoint
# -----------------------------------------------------------------------

subtest '_get_data_and_patron() - finds patron by patron_attribute: matchpoint' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $attr_type =
        $builder->build_object( { class => 'Koha::Patron::Attribute::Types', value => { code => 'SAML_UID' } } );

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    Koha::Patron::Attribute->new(
        { borrowernumber => $patron->borrowernumber, code => 'SAML_UID', attribute => 'ext-42' } )->store;

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'saml2.library.com',
            matchpoint => 'patron_attribute:SAML_UID',
            mappings   => [
                { koha_field => 'patron_attribute:SAML_UID', provider_field => 'samAccountName' },
            ],
        }
    );

    my ( $mapped_data, $found_patron ) = $client->_get_data_and_patron(
        {
            provider => $provider,
            data     => { samAccountName => 'ext-42' },
            hostname => 'saml2.library.com',
        }
    );

    ok( defined $found_patron, 'patron found via patron_attribute matchpoint' );
    is( $found_patron->id, $patron->id, 'correct patron returned' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# _find_patron_by_matchpoint()
# -----------------------------------------------------------------------

subtest '_find_patron_by_matchpoint()' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { userid => 'mp_testuser' } } );

    # By regular field
    my $found = $client->_find_patron_by_matchpoint( 'userid', 'mp_testuser' );
    is( $found->id, $patron->id, 'finds patron by regular field' );

    # Returns undef when value is undef
    my $none = $client->_find_patron_by_matchpoint( 'userid', undef );
    is( $none, undef, 'returns undef when value is undef' );

    # Returns undef when no match
    my $miss = $client->_find_patron_by_matchpoint( 'userid', 'does_not_exist_xyz' );
    is( $miss, undef, 'returns undef when patron not found' );

    # By patron_attribute:CODE
    my $attr_type =
        $builder->build_object( { class => 'Koha::Patron::Attribute::Types', value => { code => 'EXT_ID' } } );
    Koha::Patron::Attribute->new(
        { borrowernumber => $patron->borrowernumber, code => 'EXT_ID', attribute => 'uid-99' } )->store;

    my $by_attr = $client->_find_patron_by_matchpoint( 'patron_attribute:EXT_ID', 'uid-99' );
    is( $by_attr->id, $patron->id, 'finds patron by patron_attribute:CODE' );

    my $attr_miss = $client->_find_patron_by_matchpoint( 'patron_attribute:EXT_ID', 'no-such-uid' );
    is( $attr_miss, undef, 'returns undef when patron_attribute value not found' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - failure cases
# -----------------------------------------------------------------------

subtest 'checkpw() - failure cases' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    # No provider found for hostname
    my $result = $client->checkpw( 'anyone', {}, 'no-provider.example.com' );
    is( $result, 0, 'returns 0 when no SAML2 provider found for hostname' );

    # Matchpoint not mapped (provider has matchpoint='userid' but no mapping for userid)
    my ( $provider_no_map, $hostname_no_map ) = _build_provider(
        {
            hostname   => 'saml-nomap.library.com',
            matchpoint => 'userid',
            mappings   => [ { koha_field => 'email', provider_field => 'mail' } ],    # userid NOT mapped
        }
    );
    my $r2;
    {
        local $SIG{__WARN__} = sub { };    # suppress expected carp from checkpw
        $r2 = $client->checkpw( 'anyone', {}, 'saml-nomap.library.com' );
    }
    is( $r2, 0, 'returns 0 when matchpoint field is not in mappings' );

    # Multiple patrons with same matchpoint value
    my ( $provider_dup, $hostname_dup ) = _build_provider(
        {
            hostname   => 'saml-dup.library.com',
            matchpoint => 'email',
            mappings   => [ { koha_field => 'email', provider_field => 'mail' } ],
        }
    );
    $builder->build_object( { class => 'Koha::Patrons', value => { email => 'dup@example.com' } } );
    $builder->build_object( { class => 'Koha::Patrons', value => { email => 'dup@example.com' } } );
    my $r3 = $client->checkpw( 'dup@example.com', { mail => 'dup@example.com' }, 'saml-dup.library.com' );
    is( $r3, 0, 'returns 0 when multiple patrons match' );

    # Patron not found, autocreate disabled
    my ( $provider_noac, $hostname_noac ) = _build_provider(
        {
            hostname   => 'saml-noac.library.com',
            matchpoint => 'userid',
            config     => { autocreate => 0 },
            mappings   => [ { koha_field => 'userid', provider_field => 'uid' } ],
        }
    );
    my $r4 = $client->checkpw( 'ghost_user', { uid => 'ghost_user' }, 'saml-noac.library.com' );
    is( $r4, 0, 'returns 0 when patron not found and autocreate disabled' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - patron found
# -----------------------------------------------------------------------

subtest 'checkpw() - patron found returns correct values' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { userid => 'saml_found_user' } } );

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'saml-found.library.com',
            matchpoint => 'userid',
            mappings   => [ { koha_field => 'userid', provider_field => 'uid' } ],
        }
    );

    my ( $ok, $cardnumber, $userid, $returned_patron ) =
        $client->checkpw( 'saml_found_user', { uid => 'saml_found_user' }, 'saml-found.library.com' );

    is( $ok,                  1,                   'returns 1 on success' );
    is( $cardnumber,          $patron->cardnumber, 'returns correct cardnumber' );
    is( $userid,              $patron->userid,     'returns correct userid' );
    is( $returned_patron->id, $patron->id,         'returns correct patron object' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - autocreate
# -----------------------------------------------------------------------

subtest 'checkpw() - autocreate' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    # Autocreate via provider config flag
    my ( $provider_ac, $hostname_ac ) = _build_provider(
        {
            hostname   => 'saml-ac.library.com',
            matchpoint => 'userid',
            config     => { autocreate => 1 },
            mappings   => [
                { koha_field => 'userid',    provider_field => 'uid' },
                { koha_field => 'firstname', provider_field => 'givenName' },
                { koha_field => 'surname',   provider_field => 'sn' },
            ],
        }
    );

    # Ensure patron doesn't pre-exist
    Koha::Patrons->search( { userid => 'new_saml_patron' } )->delete;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { category_type => 'A' } } );

    # Add domain with defaults so patron can be stored (needs categorycode + branchcode)
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => {
                identity_provider_id => $provider_ac->id,
                domain               => undef,
                allow_opac           => 1,
                allow_staff          => 0,
                auto_register_opac   => 0,
                auto_register_staff  => 0,
                default_library_id   => $library->branchcode,
                default_category_id  => $category->categorycode,
            },
        }
    );

    my ( $ok, $cardnumber, $userid, $new_patron ) = $client->checkpw(
        'new_saml_patron',
        { uid => 'new_saml_patron', givenName => 'Auto', sn => 'Created' },
        'saml-ac.library.com'
    );

    is( $ok,     1,                 'autocreate returns 1' );
    is( $userid, 'new_saml_patron', 'autocreated patron has correct userid' );

    my $stored = Koha::Patrons->search( { userid => 'new_saml_patron' } )->next;
    ok( defined $stored, 'patron was created in DB' );
    is( $stored->firstname, 'Auto',    'firstname populated from SAML attributes' );
    is( $stored->surname,   'Created', 'surname populated from SAML attributes' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - data sync on login
# -----------------------------------------------------------------------

subtest 'checkpw() - syncs patron data when sync config is enabled' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { userid => 'sync_user_saml', firstname => 'OldFirst', surname => 'OldSurname' }
        }
    );

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'saml-sync.library.com',
            matchpoint => 'userid',
            config     => { sync => 1 },
            mappings   => [
                { koha_field => 'userid',    provider_field => 'uid',       sync_on_update => 0 },
                { koha_field => 'firstname', provider_field => 'givenName', sync_on_update => 1 },
                { koha_field => 'surname',   provider_field => 'sn',        sync_on_update => 1 },
            ],
        }
    );

    $client->checkpw(
        'sync_user_saml',
        { uid => 'sync_user_saml', givenName => 'NewFirst', sn => 'NewSurname' },
        'saml-sync.library.com'
    );

    $patron->discard_changes;
    is( $patron->firstname, 'NewFirst',   'firstname synced on login' );
    is( $patron->surname,   'NewSurname', 'surname synced on login' );

    $schema->storage->txn_rollback;
};
