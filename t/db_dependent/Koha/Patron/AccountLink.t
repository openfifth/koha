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
use Test::More tests => 10;
use Test::Exception;

use Koha::Patron::AccountLink;
use Koha::Patron::AccountLinks;
use Koha::Database;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Basic CRUD operations' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );

    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();

    my $link1 = Koha::Patron::AccountLink->new(
        {
            link_group_id  => $link_group_id,
            borrowernumber => $patron1->borrowernumber,
        }
    )->store;

    ok( $link1->id, 'AccountLink created with id' );
    is( $link1->link_group_id, $link_group_id, 'link_group_id set correctly' );

    my $link2 = Koha::Patron::AccountLink->new(
        {
            link_group_id  => $link_group_id,
            borrowernumber => $patron2->borrowernumber,
        }
    )->store;

    my $link3 = Koha::Patron::AccountLink->new(
        {
            link_group_id  => $link_group_id,
            borrowernumber => $patron3->borrowernumber,
        }
    )->store;

    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        3, 'Three links in same group'
    );

    # Delete one link - leaves 2, no orphan cleanup triggered
    $link1->delete;
    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        2, 'Two links after deletion (no orphan cleanup with 2 remaining)'
    );

    my $retrieved = Koha::Patron::AccountLinks->find( $link2->id );
    is( $retrieved->borrowernumber, $patron2->borrowernumber, 'Can retrieve link by id' );

    # Delete another - triggers orphan cleanup since only 1 would remain
    $link2->delete;
    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        0, 'No links after orphan cleanup (deleting from 2-patron group removes both)'
    );

    $schema->storage->txn_rollback;
};

subtest 'patron() method' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $link   = Koha::Patron::AccountLink->new(
        {
            link_group_id  => Koha::Patron::AccountLinks->get_next_group_id(),
            borrowernumber => $patron->borrowernumber,
        }
    )->store;

    my $linked_patron = $link->patron;
    isa_ok( $linked_patron, 'Koha::Patron' );
    is( $linked_patron->borrowernumber, $patron->borrowernumber, 'patron() returns correct patron' );

    $schema->storage->txn_rollback;
};

subtest 'linked_patrons() method' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );

    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();

    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron3->borrowernumber } )
        ->store;

    my $link1 = Koha::Patron::AccountLinks->find( { borrowernumber => $patron1->borrowernumber } );

    my $linked = $link1->linked_patrons;
    isa_ok( $linked, 'Koha::Patrons' );
    is( $linked->count, 2, 'linked_patrons returns 2 patrons (excludes self)' );

    my @linked_ids = $linked->get_column('borrowernumber');
    ok( ( grep { $_ == $patron2->borrowernumber } @linked_ids ), 'patron2 is in linked_patrons' );
    ok( ( grep { $_ == $patron3->borrowernumber } @linked_ids ), 'patron3 is in linked_patrons' );

    $schema->storage->txn_rollback;
};

subtest 'all_linked_borrowernumbers() method' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );

    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();

    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;

    my $link1 = Koha::Patron::AccountLinks->find( { borrowernumber => $patron1->borrowernumber } );
    my $all   = $link1->all_linked_borrowernumbers;

    is( ref($all),     'ARRAY', 'Returns arrayref' );
    is( scalar(@$all), 2,       'Contains both borrowernumbers' );

    $schema->storage->txn_rollback;
};

subtest 'get_next_group_id() class method' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $first_id = Koha::Patron::AccountLinks->get_next_group_id();
    ok( $first_id >= 1, 'get_next_group_id returns positive integer' );

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    Koha::Patron::AccountLink->new( { link_group_id => $first_id, borrowernumber => $patron->borrowernumber } )->store;

    my $second_id = Koha::Patron::AccountLinks->get_next_group_id();
    is( $second_id, $first_id + 1, 'get_next_group_id increments after use' );

    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    Koha::Patron::AccountLink->new( { link_group_id => $first_id, borrowernumber => $patron2->borrowernumber } )->store;

    my $third_id = Koha::Patron::AccountLinks->get_next_group_id();
    is( $third_id, $first_id + 1, 'get_next_group_id still returns same next id when adding to existing group' );

    $schema->storage->txn_rollback;
};

subtest 'Koha::Patron linked account methods' => sub {
    plan tests => 9;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );

    is( $patron1->account_link,           undef, 'account_link returns undef when not linked' );
    is( $patron1->linked_accounts->count, 0,     'linked_accounts returns empty set when not linked' );

    my $all_unlinked = $patron1->all_linked_borrowernumbers;
    is( scalar(@$all_unlinked), 1, 'all_linked_borrowernumbers returns just self when not linked' );
    is( $all_unlinked->[0],     $patron1->borrowernumber, '...and that is the patron itself' );

    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();

    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron3->borrowernumber } )
        ->store;

    my $link = $patron1->account_link;
    isa_ok( $link, 'Koha::Patron::AccountLink', 'account_link returns AccountLink object' );

    my $linked = $patron1->linked_accounts;
    is( $linked->count, 2, 'linked_accounts returns 2 patrons' );

    my $all_linked = $patron1->all_linked_borrowernumbers;
    is( scalar(@$all_linked), 3, 'all_linked_borrowernumbers returns all 3' );

    my $debt = $patron1->linked_accounts_debt;
    is( $debt, 0, 'linked_accounts_debt returns 0 when no fines' );

    $patron2->account->add_debit( { amount => 10.50, type => 'OVERDUE', interface => 'test' } );
    $patron3->account->add_debit( { amount => 5.25,  type => 'OVERDUE', interface => 'test' } );

    my $total_debt = $patron1->linked_accounts_debt;
    is( $total_debt, 15.75, 'linked_accounts_debt returns combined fines' );

    $schema->storage->txn_rollback;
};

subtest 'linked_account_links() method' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );

    is( $patron1->linked_account_links, undef, 'linked_account_links returns undef when not linked' );

    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;

    my $links = $patron1->linked_account_links;
    isa_ok( $links, 'Koha::Patron::AccountLinks' );
    is( $links->count, 2, 'linked_account_links returns all links in group' );

    my @borrowernumbers = $links->get_column('borrowernumber');
    ok(
               ( grep { $_ == $patron1->borrowernumber } @borrowernumbers )
            && ( grep { $_ == $patron2->borrowernumber } @borrowernumbers ),
        'Both patrons included in links'
    );

    $schema->storage->txn_rollback;
};

subtest 'link_to_patron() method' => sub {
    plan tests => 10;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron4 = $builder->build_object( { class => 'Koha::Patrons' } );

    # Test linking two unlinked patrons
    my $link = $patron1->link_to_patron($patron2);
    isa_ok( $link, 'Koha::Patron::AccountLink' );
    ok( $patron1->account_link, 'patron1 now has account_link' );
    ok( $patron2->account_link, 'patron2 now has account_link' );
    is(
        $patron1->account_link->link_group_id,
        $patron2->account_link->link_group_id,
        'Both patrons in same link group'
    );

    # Test adding to existing group
    my $link3 = $patron1->link_to_patron($patron3);
    is(
        $patron3->account_link->link_group_id,
        $patron1->account_link->link_group_id,
        'patron3 added to existing group'
    );
    is( $patron1->linked_account_links->count, 3, 'Group now has 3 members' );

    # Test AlreadyLinked exception
    throws_ok { $patron1->link_to_patron($patron2) }
    'Koha::Exceptions::PatronAccountLink::AlreadyLinked',
        'AlreadyLinked exception when patrons already in same group';

    # Test DifferentGroups exception
    my $other_group_id = Koha::Patron::AccountLinks->get_next_group_id();
    Koha::Patron::AccountLink->new( { link_group_id => $other_group_id, borrowernumber => $patron4->borrowernumber } )
        ->store;

    throws_ok { $patron1->link_to_patron($patron4) }
    'Koha::Exceptions::PatronAccountLink::DifferentGroups',
        'DifferentGroups exception when patrons in different groups';

    # Test linking when other patron has group but self doesn't
    my $patron5 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $link5   = $patron5->link_to_patron($patron1);
    is(
        $patron5->account_link->link_group_id,
        $patron1->account_link->link_group_id,
        'Unlinked patron joins existing group of other patron'
    );
    is( $patron1->linked_account_links->count, 4, 'Group now has 4 members' );

    $schema->storage->txn_rollback;
};

subtest 'delete() orphan cleanup' => sub {
    plan tests => 8;

    $schema->storage->txn_begin;

    my $patron1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron2 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron3 = $builder->build_object( { class => 'Koha::Patrons' } );

    # Create a 3-patron group
    my $link_group_id = Koha::Patron::AccountLinks->get_next_group_id();
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron1->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron2->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id, borrowernumber => $patron3->borrowernumber } )
        ->store;

    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        3, 'Group has 3 members initially'
    );

    # Delete one patron's link - should leave 2, no orphan cleanup
    $patron1->account_link->delete;

    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        2, 'Group has 2 members after first delete'
    );
    ok( $patron2->account_link, 'patron2 still has link' );
    ok( $patron3->account_link, 'patron3 still has link' );

    # Delete another patron's link - should trigger orphan cleanup
    $patron2->account_link->delete;

    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->count,
        0, 'Group has 0 members after orphan cleanup'
    );
    is( $patron3->account_link, undef, 'patron3 orphan link was cleaned up' );

    # Test 2-patron group deletion directly
    my $patron4        = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron5        = $builder->build_object( { class => 'Koha::Patrons' } );
    my $link_group_id2 = Koha::Patron::AccountLinks->get_next_group_id();
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id2, borrowernumber => $patron4->borrowernumber } )
        ->store;
    Koha::Patron::AccountLink->new( { link_group_id => $link_group_id2, borrowernumber => $patron5->borrowernumber } )
        ->store;

    $patron4->account_link->delete;

    is(
        Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id2 } )->count,
        0, '2-patron group fully cleaned up on delete'
    );
    is( $patron5->account_link, undef, 'Other patron in 2-person group also cleaned up' );

    $schema->storage->txn_rollback;
};
