#!/usr/bin/perl

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

use Koha::Database;
use Koha::RecordMatchers;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'search() returns Koha::RecordMatcher objects' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    my $matcher = $builder->build_object( { class => 'Koha::RecordMatchers', value => { code => 'RMTEST' } } );

    my $found = Koha::RecordMatchers->search( { code => 'RMTEST' } )->next;
    isa_ok( $found, 'Koha::RecordMatcher' );
    is( $found->matcher_id,                                        $matcher->matcher_id, 'Same matcher found' );
    is( Koha::RecordMatchers->search( { code => 'NOPE' } )->count, 0, 'Nothing found for unknown code' );

    $schema->storage->txn_rollback;
};

subtest 'to_api() uses record_matcher_id' => sub {
    plan tests => 5;
    $schema->storage->txn_begin;

    my $matcher = $builder->build_object(
        {
            class => 'Koha::RecordMatchers',
            value => { code => 'RMAPI', description => 'An API matcher', record_type => 'biblio', threshold => 100 },
        }
    );

    my $api = $matcher->to_api;
    is( $api->{record_matcher_id}, $matcher->matcher_id, 'record_matcher_id mapped from matcher_id' );
    ok( !exists $api->{matcher_id}, 'matcher_id not exposed' );
    is( $api->{code},        'RMAPI',  'code exposed' );
    is( $api->{record_type}, 'biblio', 'record_type exposed' );
    is( $api->{threshold},   100,      'threshold exposed' );

    $schema->storage->txn_rollback;
};
