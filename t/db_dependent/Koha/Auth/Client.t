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

use Test::More tests => 10;

use Test::MockModule;
use Test::MockObject;
use Test::NoWarnings;
use Test::Exception;

use JSON         qw(encode_json);
use MIME::Base64 qw{ encode_base64url };

use Koha::Auth::Client;
use Koha::Auth::Client::OAuth;
use Koha::Patron::Attribute;
use Koha::Patron::Attribute::Types;
use Koha::Patron::Attributes;
use Koha::Patrons;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'for_protocol() tests' => sub {

    plan tests => 5;

    is(
        ref( Koha::Auth::Client->for_protocol('OAuth') ), 'Koha::Auth::Client::OAuth',
        'OAuth protocol resolves to the OAuth client'
    );
    is(
        ref( Koha::Auth::Client->for_protocol('OIDC') ), 'Koha::Auth::Client::OAuth',
        'OIDC protocol is handled by the OAuth client'
    );
    is(
        ref( Koha::Auth::Client->for_protocol('SAML2') ), 'Koha::Auth::Client::SAML2',
        'SAML2 protocol resolves to the SAML2 client'
    );

    throws_ok { Koha::Auth::Client->for_protocol() }
    'Koha::Exceptions::MissingParameter', 'Exception thrown when protocol is missing';

    throws_ok { Koha::Auth::Client->for_protocol('CAS') }
    'Koha::Exceptions::Auth::UnsupportedProtocol', 'Exception thrown for unknown protocol';
};

subtest 'get_user() tests' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $client   = Koha::Auth::Client::OAuth->new;
    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $domain   = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => {
                identity_provider_id => $provider->id, domain => '', update_on_auth => 0, allow_opac => 1,
                allow_staff          => 0
            }
        }
    );
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { email => 'patron@test.com' } } );
    t::lib::Mocks::mock_userenv( { patron => $patron } );

    my $hostname_obj =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => 'oauth.library.com' } } );
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $provider->id,
                hostname_id          => $hostname_obj->id,
                is_enabled           => 1,
                matchpoint           => 'email',
            }
        }
    );

    for my $m (
        { koha_field => 'email',     provider_field => 'electronic_mail' },
        { koha_field => 'firstname', provider_field => 'given_name' },
        { koha_field => 'surname',   provider_field => 'family_name' },
        )
    {
        $builder->build_object(
            {
                class => 'Koha::Auth::Identity::Provider::Mappings',
                value => {
                    identity_provider_id => $provider->id,
                    koha_field           => $m->{koha_field},
                    provider_field       => $m->{provider_field},
                    default_content      => undef,
                }
            }
        );
    }

    my $id_token = 'header.' . encode_base64url(
        encode_json(
            {
                electronic_mail => 'patron@test.com',
                given_name      => 'test name'
            }
        )
    ) . '.footer';

    my $data = { id_token => $id_token };

    my ( $resolved_patron, $mapped_data, $resolved_domain ) = $client->get_user(
        {
            provider  => $provider->code,
            data      => $data,
            interface => 'opac',
            hostname  => 'oauth.library.com',
        }
    );
    is_deeply(
        $resolved_patron->to_api( { user => $patron } ), $patron->to_api( { user => $patron } ),
        'Patron correctly retrieved'
    );
    is( $mapped_data->{firstname},            'test name',                                   'Data mapped correctly' );
    is( $mapped_data->{surname},              undef,                                         'No surname mapped' );
    is( $domain->identity_provider_domain_id, $resolved_domain->identity_provider_domain_id, 'Is the same domain' );

    $schema->storage->txn_rollback;
};

subtest 'get_valid_domain_config() tests' => sub {
    plan tests => 10;

    $schema->storage->txn_begin;

    my $client   = Koha::Auth::Client->new;
    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $domain1  = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => { identity_provider_id => $provider->id, domain => '', allow_opac => 0, allow_staff => 0 }
        }
    );
    my $domain2 = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value =>
                { identity_provider_id => $provider->id, domain => '*library.com', allow_opac => 1, allow_staff => 0 }
        }
    );
    my $domain3 = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value =>
                { identity_provider_id => $provider->id, domain => '*.library.com', allow_opac => 1, allow_staff => 0 }
        }
    );
    my $domain4 = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => {
                identity_provider_id => $provider->id, domain => 'student.library.com', allow_opac => 1,
                allow_staff          => 0
            }
        }
    );
    my $domain5 = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => {
                identity_provider_id => $provider->id, domain => 'staff.library.com', allow_opac => 1, allow_staff => 1
            }
        }
    );

    my $retrieved_domain;

    # Test @gmail.com
    $retrieved_domain =
        $client->get_valid_domain_config( { provider => $provider, email => 'user@gmail.com', interface => 'opac' } );
    is( $retrieved_domain, undef, 'gmail user cannot enter opac' );
    $retrieved_domain =
        $client->get_valid_domain_config( { provider => $provider, email => 'user@gmail.com', interface => 'staff' } );
    is( $retrieved_domain, undef, 'gmail user cannot enter staff' );

    # Test @otherlibrary.com
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@otherlibrary.com', interface => 'opac' } );
    is(
        $retrieved_domain->identity_provider_domain_id, $domain2->identity_provider_domain_id,
        'otherlibaray user can enter opac with domain2'
    );
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@otherlibrary.com', interface => 'staff' } );
    is( $retrieved_domain, undef, 'otherlibrary user cannot enter staff' );

    # Test @provider.library.com
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@provider.library.com', interface => 'opac' } );
    is(
        $retrieved_domain->identity_provider_domain_id, $domain3->identity_provider_domain_id,
        'provider.library user can enter opac with domain3'
    );
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@provider.library.com', interface => 'staff' } );
    is( $retrieved_domain, undef, 'provider.library user cannot enter staff' );

    # Test @student.library.com
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@student.library.com', interface => 'opac' } );
    is(
        $retrieved_domain->identity_provider_domain_id, $domain4->identity_provider_domain_id,
        'student.library user can enter opac with domain4'
    );
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@student.library.com', interface => 'staff' } );
    is( $retrieved_domain, undef, 'student.library user cannot enter staff' );

    # Test @staff.library.com
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@staff.library.com', interface => 'opac' } );
    is(
        $retrieved_domain->identity_provider_domain_id, $domain5->identity_provider_domain_id,
        'staff.library user can enter opac with domain5'
    );
    $retrieved_domain = $client->get_valid_domain_config(
        { provider => $provider, email => 'user@staff.library.com', interface => 'staff' } );
    is(
        $retrieved_domain->identity_provider_domain_id, $domain5->identity_provider_domain_id,
        'staff.library user can enter staff with domain5'
    );

    $schema->storage->txn_rollback;
};

subtest 'has_valid_domain_config() tests' => sub {
    plan tests => 2;
    $schema->storage->txn_begin;

    my $client   = Koha::Auth::Client->new;
    my $provider = $builder->build_object( { class => 'Koha::Auth::Identity::Providers' } );
    my $domain1  = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => { identity_provider_id => $provider->id, domain => '', allow_opac => 1, allow_staff => 0 }
        }
    );

    # Test @gmail.com
    my $retrieved_domain =
        $client->has_valid_domain_config( { provider => $provider, email => 'user@gmail.com', interface => 'opac' } );
    is(
        $retrieved_domain->identity_provider_domain_id, $domain1->identity_provider_domain_id,
        'gmail user can enter opac with domain1'
    );
    throws_ok {
        $client->has_valid_domain_config( { provider => $provider, email => 'user@gmail.com', interface => 'staff' } )
    }
    'Koha::Exceptions::Auth::NoValidDomain',
        'gmail user cannot enter staff';

    $schema->storage->txn_rollback;
};

subtest '_traverse_hash() tests' => sub {
    plan tests => 3;

    my $client = Koha::Auth::Client->new;

    my $hash = {
        a  => { hash  => { with => 'complicated structure' } },
        an => { array => [ { inside => 'a hash' }, { inside => 'second element' } ] }
    };

    my $first_result = $client->_traverse_hash(
        {
            base => $hash,
            keys => 'a.hash.with'
        }
    );
    is( $first_result, 'complicated structure', 'get the value within a hash structure' );

    my $second_result = $client->_traverse_hash(
        {
            base => $hash,
            keys => 'an.array.0.inside'
        }
    );
    is( $second_result, 'a hash', 'get the value of the first element of an array within a hash structure' );

    my $third_result = $client->_traverse_hash(
        {
            base => $hash,
            keys => 'an.array.1.inside'
        }
    );
    is( $third_result, 'second element', 'get the value of the second element of an array within a hash structure' );
};

subtest '_find_patron_by_matchpoint() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client->new;
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { email => 'matchtest@example.com' } } );

    # Standard borrower field matchpoint
    my $found = $client->_find_patron_by_matchpoint( 'email', 'matchtest@example.com' );
    is( $found->borrowernumber, $patron->borrowernumber, 'Finds patron by standard borrower field' );

    # No match returns undef
    my $not_found = $client->_find_patron_by_matchpoint( 'email', 'nonexistent@example.com' );
    is( $not_found, undef, 'Returns undef when no patron matches standard field' );

    # Empty/undef value returns undef
    is( $client->_find_patron_by_matchpoint( 'email', '' ),    undef, 'Returns undef for empty string value' );
    is( $client->_find_patron_by_matchpoint( 'email', undef ), undef, 'Returns undef for undef value' );

    # patron_attribute: matchpoint
    my $attr_type = $builder->build_object(
        {
            class => 'Koha::Patron::Attribute::Types',
            value => { repeatable => 0, unique_id => 0 }
        }
    );
    Koha::Patron::Attribute->new(
        { borrowernumber => $patron->borrowernumber, code => $attr_type->code, attribute => 'UNIQUE123' } )->store;

    my $found_by_attr = $client->_find_patron_by_matchpoint( 'patron_attribute:' . $attr_type->code, 'UNIQUE123' );
    is(
        $found_by_attr->borrowernumber, $patron->borrowernumber,
        'Finds patron by patron_attribute: matchpoint'
    );

    my $not_found_by_attr = $client->_find_patron_by_matchpoint( 'patron_attribute:' . $attr_type->code, 'NOMATCH' );
    is( $not_found_by_attr, undef, 'Returns undef when patron_attribute value does not match' );

    # Duplicate matchpoint throws exception
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    Koha::Patron::Attribute->new(
        { borrowernumber => $patron2->borrowernumber, code => $attr_type->code, attribute => 'UNIQUE123' } )->store;

    throws_ok {
        $client->_find_patron_by_matchpoint( 'patron_attribute:' . $attr_type->code, 'UNIQUE123' );
    }
    'Koha::Exceptions::Auth::DuplicateMatchpoint',
        'Throws DuplicateMatchpoint when multiple patrons share the same attribute value';

    $schema->storage->txn_rollback;
};

subtest '_update_patron_from_mapped_data() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client->new;
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { firstname => 'Original', surname => 'Name' } } );

    # Core borrower fields only
    $client->_update_patron_from_mapped_data(
        { patron => $patron, mapped_data => { firstname => 'Updated', surname => 'Person' } } );
    $patron->discard_changes;
    is( $patron->firstname, 'Updated', 'Core field firstname updated' );
    is( $patron->surname,   'Person',  'Core field surname updated' );

    # patron_attribute: fields only
    my $attr_type = $builder->build_object(
        {
            class => 'Koha::Patron::Attribute::Types',
            value => { repeatable => 0, unique_id => 0 }
        }
    );

    $client->_update_patron_from_mapped_data(
        { patron => $patron, mapped_data => { 'patron_attribute:' . $attr_type->code => 'AttrValue1' } } );
    my $attrs =
        Koha::Patron::Attributes->search( { borrowernumber => $patron->borrowernumber, code => $attr_type->code } );
    is( $attrs->count,           1,            'One patron attribute created' );
    is( $attrs->next->attribute, 'AttrValue1', 'Patron attribute has correct value' );

    # Updating replaces existing attribute
    $client->_update_patron_from_mapped_data(
        { patron => $patron, mapped_data => { 'patron_attribute:' . $attr_type->code => 'AttrValue2' } } );
    $attrs =
        Koha::Patron::Attributes->search( { borrowernumber => $patron->borrowernumber, code => $attr_type->code } );
    is( $attrs->count,           1,            'Still one patron attribute after update (replaced, not duplicated)' );
    is( $attrs->next->attribute, 'AttrValue2', 'Patron attribute value was replaced' );

    # Mixed: core fields + patron attributes together
    my $attr_type2 = $builder->build_object(
        {
            class => 'Koha::Patron::Attribute::Types',
            value => { repeatable => 0, unique_id => 0 }
        }
    );

    $client->_update_patron_from_mapped_data(
        {
            patron      => $patron,
            mapped_data => {
                firstname                               => 'Mixed',
                'patron_attribute:' . $attr_type2->code => 'MixedAttr',
            }
        }
    );
    $patron->discard_changes;
    is( $patron->firstname, 'Mixed', 'Core field updated alongside patron attribute in mixed update' );

    $schema->storage->txn_rollback;
};

subtest '_update_patron_from_mapped_data() with repeatable attributes' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client->new;
    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    my $repeatable_type = $builder->build_object(
        {
            class => 'Koha::Patron::Attribute::Types',
            value => { repeatable => 1, unique_id => 0 }
        }
    );

    # A single value from the IdP is stored as-is
    $client->_update_patron_from_mapped_data(
        { patron => $patron, mapped_data => { 'patron_attribute:' . $repeatable_type->code => 'A' } } );
    my $attrs = Koha::Patron::Attributes->search(
        { borrowernumber => $patron->borrowernumber, code => $repeatable_type->code } );
    is( $attrs->count, 1, 'One value stored for a scalar mapping' );

    # A multi-valued mapping (arrayref) creates one row per value
    $client->_update_patron_from_mapped_data(
        {
            patron      => $patron,
            mapped_data => { 'patron_attribute:' . $repeatable_type->code => [ 'B', 'C' ] }
        }
    );
    $attrs = Koha::Patron::Attributes->search(
        { borrowernumber => $patron->borrowernumber, code => $repeatable_type->code } );
    is( $attrs->count, 2, 'Two rows created for a two-element array mapping' );
    my @values = sort map { $_->attribute } $attrs->as_list;
    is_deeply( \@values, [ 'B', 'C' ], 'Both values present' );

    # The whole set is replaced on the next sync, including removal of values
    # the IdP no longer sends — this is what makes it a sync, not just an append.
    $client->_update_patron_from_mapped_data(
        { patron => $patron, mapped_data => { 'patron_attribute:' . $repeatable_type->code => ['B'] } } );
    $attrs = Koha::Patron::Attributes->search(
        { borrowernumber => $patron->borrowernumber, code => $repeatable_type->code } );
    is( $attrs->count,           1,   'Previous values are replaced, not appended to' );
    is( $attrs->next->attribute, 'B', 'Only the value still supplied by the IdP remains' );

    # A non-repeatable attribute given multiple values falls back to the first one
    # instead of dying or violating the type's own repeatable constraint.
    my $single_type = $builder->build_object(
        {
            class => 'Koha::Patron::Attribute::Types',
            value => { repeatable => 0, unique_id => 0 }
        }
    );
    $client->_update_patron_from_mapped_data(
        {
            patron      => $patron,
            mapped_data => { 'patron_attribute:' . $single_type->code => [ 'X', 'Y' ] }
        }
    );
    $attrs =
        Koha::Patron::Attributes->search( { borrowernumber => $patron->borrowernumber, code => $single_type->code } );
    is( $attrs->count, 1, 'Non-repeatable attribute keeps only one value even when given several' );

    # An invalid attribute code still fails loudly
    throws_ok {
        $client->_update_patron_from_mapped_data(
            { patron => $patron, mapped_data => { 'patron_attribute:DOES_NOT_EXIST' => 'x' } } );
    }
    'Koha::Exceptions::Patron::Attribute::InvalidType', 'Invalid attribute code still fails loudly';

    $schema->storage->txn_rollback;
};

subtest '_update_patron_from_mapped_data() with a multi-valued core field mapping' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client->new;
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { surname => 'Original' } } );

    # Core borrower fields are single-value DB columns; a mapping that resolves
    # to an array (e.g. a claim mapped without an index) can't be stored as-is.
    # Falling back to the first value keeps login working instead of storing a
    # stringified reference or dying.
    $client->_update_patron_from_mapped_data(
        { patron => $patron, mapped_data => { surname => [ 'First', 'Second' ] } } );
    $patron->discard_changes;
    is( $patron->surname, 'First', 'Multi-valued core field mapping falls back to the first value' );

    $schema->storage->txn_rollback;
};
