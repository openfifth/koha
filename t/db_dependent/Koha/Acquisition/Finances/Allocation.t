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

use Test::NoWarnings;
use Test::More tests => 3;

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Acquisition::Finances::Allocation;
use Koha::Acquisition::Finances::Allocations;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() and delete() tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $allocation    = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );
    my $allocation_id = $allocation->allocation_id;

    ok( defined $allocation_id, 'Allocation stored and has an ID' );

    my $retrieved = Koha::Acquisition::Finances::Allocations->find($allocation_id);
    ok( defined $retrieved, 'Allocation can be retrieved from DB' );

    $allocation->delete;
    my $deleted = Koha::Acquisition::Finances::Allocations->find($allocation_id);
    ok( !defined $deleted, 'Allocation deleted successfully' );

    $schema->storage->txn_rollback;
};

subtest '_object_hierarchy() tests' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $allocation = $builder->build_object( { class => 'Koha::Acquisition::Finances::Allocations' } );

    my $hierarchy = $allocation->_object_hierarchy;

    is( $hierarchy->{object}, 'allocation', 'object is allocation' );

    $schema->storage->txn_rollback;
};
