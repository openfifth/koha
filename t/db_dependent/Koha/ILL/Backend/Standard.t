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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 2;
use Test::MockModule;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->new->schema;

subtest 'metadata() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $request = $builder->build_sample_ill_request( { backend => 'Standard' } );

    is(
        scalar %{ $request->metadata }, 0,
        'metadata() returns empty if no metadata is set'
    );

    $builder->build_object(
        {
            class => 'Koha::ILL::Request::Attributes',
            value => {
                illrequest_id => $request->illrequest_id,
                type          => 'title',
                value         => 'The Hobbit',
                backend       => 'Standard',
            }
        }
    );

    is(
        scalar %{ $request->metadata }, 1,
        'metadata() returns non-empty if metadata is set'
    );

    $builder->build_object(
        {
            class => 'Koha::ILL::Request::Attributes',
            value => {
                illrequest_id => $request->illrequest_id,
                type          => 'author',
                value         => 'JRR Tolkien',
                backend       => 'Other_backend',
            }
        }
    );

    is(
        scalar %{ $request->metadata }, 1,
        'metadata() only returns attributes from Standard'
    );

    is(
        $request->metadata->{'Title'}, 'The Hobbit',
        'metadata() only returns attributes from Standard'
    );

    is(
        $request->metadata->{'Author'}, undef,
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
                type          => 'not_Standard_field',
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
                type          => 'doi',
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

    is(
        $request->metadata->{'not_Standard_field'}, undef,
        'Standard'
    );

    is(
        $request->metadata->{'doi'}, undef,
        '123/abc'
    );

    $schema->storage->txn_rollback;

};
