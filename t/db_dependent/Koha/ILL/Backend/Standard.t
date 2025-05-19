#!/usr/bin/perl

# Copyright 2025 Koha Development team
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

use Test::More tests => 4;
use Test::MockModule;
use Test::NoWarnings;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::ILL::Backend::Standard;
use Koha::ILL::Requests;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'edititem() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    # Create a test library for validation
    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    # Create a test ILL request with NEW status (required for editing)
    my $request = $builder->build_object(
        {
            class => 'Koha::ILL::Requests',
            value => { status => 'NEW' }
        }
    );

    # Add some initial attributes
    $request->add_or_update_attributes(
        {
            title  => 'Original Title',
            author => 'Original Author',
            isbn   => '1234567890'
        }
    );

    my $backend = Koha::ILL::Backend::Standard->new;

    # Test form stage (initial load)
    my $form_params = {
        request => $request,
        other   => { stage => 'init' }
    };

    my $form_result = $backend->edititem($form_params);
    is( $form_result->{error},  0,          'edititem form stage returns success' );
    is( $form_result->{method}, 'edititem', 'edititem form stage returns correct method' );
    is( $form_result->{stage},  'form',     'edititem form stage returns form stage' );

    # Test commit stage (form submission with all required fields)
    my $commit_params = {
        request => $request,
        other   => {
            stage        => 'form',
            type         => 'book',                  # Required field
            branchcode   => $library->branchcode,    # Required field
            title        => 'Updated Title',
            author       => 'Updated Author',
            year         => '2023',                  # New attribute
            custom_key   => "custom1\0custom2",      # Custom fields
            custom_value => "value1\0value2"
        }
    };

    my $commit_result = $backend->edititem($commit_params);

    # Check the result structure (method returns 'create' in commit stage)
    is( $commit_result->{error},  0,        'edititem commit returns success' );
    is( $commit_result->{method}, 'create', 'edititem commit returns create method' );
    is( $commit_result->{stage},  'commit', 'edititem commit returns commit stage' );

    # Refresh request to get updated attributes
    $request->discard_changes;

    # Check attributes were updated correctly
    my $title_attr   = $request->extended_attributes->find( { type => 'title' } );
    my $author_attr  = $request->extended_attributes->find( { type => 'author' } );
    my $year_attr    = $request->extended_attributes->find( { type => 'year' } );
    my $custom1_attr = $request->extended_attributes->find( { type => 'custom1' } );
    my $custom2_attr = $request->extended_attributes->find( { type => 'custom2' } );

    is( $title_attr->value,  'Updated Title',  'Title attribute updated' );
    is( $author_attr->value, 'Updated Author', 'Author attribute updated' );
    ok( $year_attr, 'New year attribute created' );
    is( $year_attr->value,    '2023',   'Year attribute has correct value' );
    is( $custom1_attr->value, 'value1', 'Custom1 attribute created correctly' );
    is( $custom2_attr->value, 'value2', 'Custom2 attribute created correctly' );

    $schema->storage->txn_rollback;
};

subtest 'metadata() tests' => sub {

    plan tests => 14;

    $schema->storage->txn_begin;

    # Create a test ILL request
    my $request = $builder->build_sample_ill_request( { backend => 'Standard' } );

    # Add various attributes including some that should be ignored
    $request->add_or_update_attributes(
        {
            title        => 'Test Title',
            author       => 'Test Author',
            isbn         => '1234567890',
            eissn        => 'eissntest',
            year         => '2023',
            custom_field => 'custom_value',

            # These should be ignored by metadata()
            requested_partners           => 'partner@example.com',
            type                         => 'book',
            copyrightclearance_confirmed => '1',
            unauthenticated_email        => 'user@example.com'
        }
    );

    my $backend  = Koha::ILL::Backend::Standard->new;
    my $metadata = $backend->metadata($request);

    # Check that metadata is a hashref
    is( ref($metadata), 'HASH', 'metadata returns a hashref' );

    # Check that included attributes are present (metadata uses display names)
    is( $metadata->{Title},        'Test Title',   'Title included in metadata' );
    is( $metadata->{Author},       'Test Author',  'Author included in metadata' );
    is( $metadata->{ISBN},         '1234567890',   'ISBN included in metadata' );
    is( $metadata->{eISSN},        'eissntest',    'eISSN included in metadata' );
    is( $metadata->{Year},         '2023',         'Year included in metadata' );
    is( $metadata->{Custom_field}, 'custom_value', 'Custom field included in metadata' );

    # Check that ignored attributes are excluded
    ok( !exists $metadata->{Requested_partners},           'requested_partners excluded from metadata' );
    ok( !exists $metadata->{Copyrightclearance_confirmed}, 'copyrightclearance_confirmed excluded from metadata' );

    my $new_request = $builder->build_sample_ill_request( { backend => 'Standard' } );

    is(
        scalar %{ $new_request->metadata }, 0,
        'metadata() returns empty if no metadata is set'
    );

    $builder->build_object(
        {
            class => 'Koha::ILL::Request::Attributes',
            value => {
                illrequest_id => $new_request->illrequest_id,
                type          => 'title',
                value         => 'The Hobbit',
                backend       => 'Standard',
            }
        }
    );

    is(
        scalar %{ $new_request->metadata }, 1,
        'metadata() returns non-empty if metadata is set'
    );

    $builder->build_object(
        {
            class => 'Koha::ILL::Request::Attributes',
            value => {
                illrequest_id => $new_request->illrequest_id,
                type          => 'author',
                value         => 'JRR Tolkien',
                backend       => 'Other_backend',
            }
        }
    );

    is(
        scalar %{ $new_request->metadata }, 1,
        'metadata() only returns attributes from Standard'
    );

    is(
        $new_request->metadata->{'Title'}, 'The Hobbit',
        'metadata() only returns attributes from Standard'
    );

    is(
        $new_request->metadata->{'Author'}, undef,
        'metadata() only returns attributes from Standard'
    );

    $schema->storage->txn_rollback;
};

subtest 'migrate() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $request = $builder->build_sample_ill_request( { backend => 'Other_backend' } );

    # Add attribute that Standard does not consider metadata
    $builder->build_object(
        {
            class => 'Koha::ILL::Request::Attributes',
            value => {
                illrequest_id => $request->illrequest_id,
                type          => 'Not_Standard_field',
                value         => 'test',
                backend       => 'Other_backend',
            }
        }
    );

    # Add attribute that Standard considers metadata
    $builder->build_object(
        {
            class => 'Koha::ILL::Request::Attributes',
            value => {
                illrequest_id => $request->illrequest_id,
                type          => 'DOI',
                value         => '123/abc',
                backend       => 'Other_backend',
            }
        }
    );

    my $test = $request->backend_migrate(
        {
            backend       => 'Standard',
            illrequest_id => $request->illrequest_id
        }
    );

    is( $request->metadata->{'Not_Standard_field'}, undef, 'Non standard field not migrated' );

    is( $request->metadata->{'DOI'}, '123/abc', 'Standard field migrated' );

    $schema->storage->txn_rollback;
};
