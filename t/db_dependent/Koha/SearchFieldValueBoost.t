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
use Test::More tests => 4;

use Koha::Database;
use Koha::SearchFields;
use Koha::SearchFieldValueBoost;
use Koha::SearchFieldValueBoosts;

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

subtest 'search_field() tests' => sub {

    plan tests => 2;

    my $search_field = $builder->build_object( { class => 'Koha::SearchFields' } );
    my $boost =
        Koha::SearchFieldValueBoost->new( { search_field_id => $search_field->id, value => 'MU', weight => 2.0 } )
        ->store;

    isa_ok( $boost->search_field, 'Koha::SearchField' );
    is( $boost->search_field->id, $search_field->id, 'search_field() returns the linked search field' );
};

subtest 'search_field_id cascade delete tests' => sub {

    plan tests => 1;

    my $search_field = $builder->build_object( { class => 'Koha::SearchFields' } );
    Koha::SearchFieldValueBoost->new( { search_field_id => $search_field->id, value => 'MU', weight => 2.0 } )->store;

    $search_field->delete;

    is(
        Koha::SearchFieldValueBoosts->search( { search_field_id => $search_field->id } )->count, 0,
        'Deleting a search field cascades to delete its value boosts'
    );
};

subtest 'existing_boosts_by_search_field_name() and restore_from_existing_boosts() tests' => sub {

    plan tests => 5;

    Koha::SearchFieldValueBoosts->search->delete;

    # Two fields, one with two boosted values, mirroring a real setup (e.g. itype MU/BK)
    my $field_1 = $builder->build_object( { class => 'Koha::SearchFields' } );
    my $field_2 = $builder->build_object( { class => 'Koha::SearchFields' } );
    my ( $field_1_name, $field_2_name ) = ( $field_1->name, $field_2->name );
    Koha::SearchFieldValueBoost->new( { search_field_id => $field_1->id, value => 'MU',  weight => 2.0 } )->store;
    Koha::SearchFieldValueBoost->new( { search_field_id => $field_1->id, value => 'BK',  weight => 0.5 } )->store;
    Koha::SearchFieldValueBoost->new( { search_field_id => $field_2->id, value => 'DVD', weight => 3.0 } )->store;

    my $existing_boosts = Koha::SearchFieldValueBoosts->existing_boosts_by_search_field_name;
    is( $existing_boosts->{$field_1_name}{MU} + 0,  2,   'Captures the first field\'s first boost' );
    is( $existing_boosts->{$field_1_name}{BK} + 0,  0.5, 'Captures the first field\'s second boost' );
    is( $existing_boosts->{$field_2_name}{DVD} + 0, 3,   'Captures the second field\'s boost' );

    # Reproduce what saving the mappings form does: delete and recreate every search_field row,
    # which cascade-deletes all boosts and assigns new ids.
    Koha::SearchFields->search->delete;
    my $new_field_1 = Koha::SearchFields->find_or_create(
        { name => $field_1_name, label => $field_1->label, type => $field_1->type } );
    my $new_field_2 = Koha::SearchFields->find_or_create(
        { name => $field_2_name, label => $field_2->label, type => $field_2->type } );

    Koha::SearchFieldValueBoosts->restore_from_existing_boosts($existing_boosts);

    is_deeply(
        [
            sort { $a <=> $b }
            map  { $_ + 0 }
            map  { $_->weight } Koha::SearchFieldValueBoosts->search( { search_field_id => $new_field_1->id } )->as_list
        ],
        [ 0.5, 2 ],
        'Both boosts on the first field survive against its new id'
    );
    is(
        Koha::SearchFieldValueBoosts->find( { search_field_id => $new_field_2->id, value => 'DVD' } )->weight + 0,
        3, 'The boost on the second field survives against its new id'
    );
};

$schema->storage->txn_rollback;
