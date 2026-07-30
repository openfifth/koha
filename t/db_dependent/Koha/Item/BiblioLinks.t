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
use Test::More tests => 6;
use Test::Exception;
use Test::MockModule;
use Test::Warn;

use C4::Context;
use Koha::Database;

use t::lib::TestBuilder;
use t::lib::Mocks;

BEGIN {
    use_ok('Koha::Item::BiblioLink');
    use_ok('Koha::Item::BiblioLinks');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 1 );
    t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue',   0 );

    my $native_biblio = $builder->build_sample_biblio();
    my $linked_biblio = $builder->build_sample_biblio();
    my $item          = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );

    my @indexed_biblionumbers;
    my $engine       = C4::Context->preference('SearchEngine') // 'Zebra';
    my $indexer_mock = Test::MockModule->new("Koha::SearchEngine::${engine}::Indexer");
    $indexer_mock->mock(
        'index_records',
        sub {
            my ( $self, $ids ) = @_;
            push @indexed_biblionumbers, ref $ids eq 'ARRAY' ? @$ids : $ids;
        }
    );

    my $link = Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $linked_biblio->biblionumber,
            link_type    => 'binding',
        }
    )->store;

    is( ref($link), 'Koha::Item::BiblioLink', 'store() returns a Koha::Item::BiblioLink' );

    $link->discard_changes;
    is( $link->link_type, 'binding', 'link_type is stored' );
    ok( $link->created_on, 'created_on is set by the database default' );

    is( ref( $link->item ),          'Koha::Item',                 '->item returns a Koha::Item' );
    is( $link->item->itemnumber,     $item->itemnumber,            '->item returns the linked item' );
    is( ref( $link->biblio ),        'Koha::Biblio',               '->biblio returns a Koha::Biblio' );
    is( $link->biblio->biblionumber, $linked_biblio->biblionumber, '->biblio returns the linked biblio' );

    is_deeply(
        \@indexed_biblionumbers, [ $linked_biblio->biblionumber ],
        'store() triggered a reindex of the linked biblio'
    );

    throws_ok {
        Koha::Item::BiblioLink->new(
            {
                itemnumber   => $item->itemnumber,
                biblionumber => $native_biblio->biblionumber,
                link_type    => 'binding',
            }
        )->store;
    }
    'Koha::Exceptions::Item::BiblioLink::SameBiblio',
        'Linking an item to the record its item record lives on is refused';

    warning_like {
        throws_ok {
            Koha::Item::BiblioLink->new(
                {
                    itemnumber   => $item->itemnumber,
                    biblionumber => $linked_biblio->biblionumber,
                    link_type    => 'binding',
                }
            )->store;
        }
        'Koha::Exceptions::Object::DuplicateID', 'Duplicate link is refused';
    }
    qr/Duplicate ID/, 'Duplicate link warns before throwing';

    is(
        Koha::Item::BiblioLinks->search( { itemnumber => $item->itemnumber } )->count, 1,
        'Only one link row exists for the item'
    );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 1 );
    t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue',   0 );

    my $native_biblio = $builder->build_sample_biblio();
    my $linked_biblio = $builder->build_sample_biblio();
    my $item          = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );

    my $link = Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $linked_biblio->biblionumber,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );

    my $hold = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                biblionumber => $linked_biblio->biblionumber,
                itemnumber   => $item->itemnumber,
                found        => undef,
            }
        }
    );

    throws_ok { $link->delete }
    'Koha::Exceptions::Item::BiblioLink::HoldsExist',
        'Removing a link with holds for the item on the linked biblio is refused';

    is( Koha::Item::BiblioLinks->search( { id => $link->id } )->count, 1, 'Link was not removed' );

    my @indexed_biblionumbers;
    my $engine       = C4::Context->preference('SearchEngine') // 'Zebra';
    my $indexer_mock = Test::MockModule->new("Koha::SearchEngine::${engine}::Indexer");
    $indexer_mock->mock(
        'index_records',
        sub {
            my ( $self, $ids ) = @_;
            push @indexed_biblionumbers, ref $ids eq 'ARRAY' ? @$ids : $ids;
        }
    );

    lives_ok { $link->delete( { force => 1 } ) } 'Removing the link with force => 1 succeeds';

    is( Koha::Item::BiblioLinks->search( { id => $link->id } )->count, 0, 'Link was removed' );

    is_deeply(
        \@indexed_biblionumbers, [ $linked_biblio->biblionumber ],
        'delete() triggered a reindex of the linked biblio'
    );

    # Biblio-level holds are stranded too when the link is the record's only
    # source of items
    $hold->delete;
    $link = Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $linked_biblio->biblionumber,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );
    my $biblio_level_hold = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                biblionumber => $linked_biblio->biblionumber,
                itemnumber   => undef,
                found        => undef,
            }
        }
    );

    throws_ok { $link->delete }
    'Koha::Exceptions::Item::BiblioLink::HoldsExist',
        'Removing the record\'s only item source with a biblio-level hold is refused';

    $builder->build_sample_item( { biblionumber => $linked_biblio->biblionumber } );
    lives_ok { $link->delete( { skip_record_index => 1 } ) }
    'Removing the link is allowed once the record has an item of its own';

    $schema->storage->txn_rollback;
};

subtest 'cascade deletion tests' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'EnableBoundWithItems', 1 );
    t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue',   0 );

    my $native_biblio   = $builder->build_sample_biblio();
    my $linked_biblio_1 = $builder->build_sample_biblio();
    my $linked_biblio_2 = $builder->build_sample_biblio();
    my $item            = $builder->build_sample_item( { biblionumber => $native_biblio->biblionumber } );

    Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $linked_biblio_1->biblionumber,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );
    Koha::Item::BiblioLink->new(
        {
            itemnumber   => $item->itemnumber,
            biblionumber => $linked_biblio_2->biblionumber,
            link_type    => 'binding',
        }
    )->store( { skip_record_index => 1 } );

    is( Koha::Item::BiblioLinks->search( { itemnumber => $item->itemnumber } )->count, 2, 'Two links exist' );

    $linked_biblio_1->delete;
    is(
        Koha::Item::BiblioLinks->search( { itemnumber => $item->itemnumber } )->count, 1,
        'Deleting a linked biblio removes its link row by cascade'
    );

    $item->delete( { skip_record_index => 1 } );
    is(
        Koha::Item::BiblioLinks->search( { biblionumber => $linked_biblio_2->biblionumber } )->count, 0,
        'Deleting the item removes the remaining link rows by cascade'
    );

    $schema->storage->txn_rollback;
};
