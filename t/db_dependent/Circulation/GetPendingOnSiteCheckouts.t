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
use Test::MockModule;
use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Circulation qw( AddIssue GetPendingOnSiteCheckouts );
use C4::Biblio      qw( AddBiblio );
use C4::Items;
use C4::Members;

use Koha::Libraries;
use Koha::Patrons;
use Koha::Patron::Categories;

use MARC::Record;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

$dbh->do(q|DELETE FROM issues|);

my $branchcode = $builder->build( { source => 'Branch' } )->{branchcode};
my $itemtype   = $builder->build( { source => 'Itemtype' } )->{itemtype};

my %item_infos = (
    homebranch    => $branchcode,
    holdingbranch => $branchcode,
    itype         => $itemtype
);

my ($biblionumber1) = AddBiblio( MARC::Record->new, '' );
my $itemnumber1 =
    Koha::Item->new( { barcode => '0101', %item_infos, biblionumber => $biblionumber1 } )->store->itemnumber;
my $itemnumber2 =
    Koha::Item->new( { barcode => '0102', %item_infos, biblionumber => $biblionumber1 } )->store->itemnumber;

my ($biblionumber2) = AddBiblio( MARC::Record->new, '' );
my $itemnumber3 =
    Koha::Item->new( { barcode => '0203', %item_infos, biblionumber => $biblionumber2 } )->store->itemnumber;

my $categorycode = $builder->build( { source => 'Category' } )->{categorycode};
my $patron       = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => { categorycode => $categorycode, branchcode => $branchcode }
    }
);

# Need to mock userenv for AddIssue
my $module = Test::MockModule->new('C4::Context');
$module->mock( 'userenv', sub { { branch => $branchcode } } );
AddIssue( $patron, '0101' );
AddIssue( $patron, '0203' );

# Begin tests...
my $onsite_checkouts = GetPendingOnSiteCheckouts;
is( scalar @$onsite_checkouts, 0, "No pending on-site checkouts" );

my $itemnumber4 =
    Koha::Item->new( { barcode => '0104', %item_infos, biblionumber => $biblionumber1 } )->store->itemnumber;
AddIssue( $patron, '0104', undef, undef, undef, undef, { onsite_checkout => 1 } );
$onsite_checkouts = GetPendingOnSiteCheckouts;
is( scalar @$onsite_checkouts, 1, "There is 1 pending on-site checkout" );

subtest 'items on a display' => sub {
    plan tests => 9;

    my $item_on =
        Koha::Item->new( { barcode => '0501', %item_infos, biblionumber => $biblionumber1, location => 'CART' } )
        ->store;
    AddIssue( $patron, '0501', undef, undef, undef, undef, { onsite_checkout => 1 } );

    my $make_display = sub {
        my (%values) = @_;
        return $builder->build_object(
            {
                class => 'Koha::Displays',
                value => {
                    display_name        => 'Spring books',
                    display_location    => undef,
                    enabled             => 1,
                    start_date          => '2000-01-01',
                    end_date            => '2100-01-01',
                    display_days        => 7,
                    display_return_over => 'no',
                    %values,
                }
            }
        );
    };
    my $put = sub {
        my ( $display, %dates ) = @_;
        return $builder->build_object(
            {
                class => 'Koha::Display::Items',
                value => {
                    display_id   => $display->display_id,
                    itemnumber   => $item_on->itemnumber,
                    biblionumber => $biblionumber1,
                    date_added   => '2000-01-01',
                    date_remove  => '2100-01-01',
                    %dates,
                }
            }
        );
    };
    my $found = sub {
        my ($rows) = grep { $_->{itemnumber} == $item_on->itemnumber } @{ GetPendingOnSiteCheckouts() };
        return $rows;
    };

    t::lib::Mocks::mock_preference( 'UseDisplayModule', 1 );

    # Not on a display: its own location
    is( $found->()->{effective_location}, 'CART', 'The item is shown at its own location' );

    # Every way of not being active leaves it alone
    my $disabled = $make_display->( enabled => 0, display_location => 'DISABLED' );
    $put->($disabled);
    my $ended = $make_display->( end_date => '2001-01-01', display_location => 'ENDED' );
    $put->($ended);
    my $future = $make_display->( start_date => '2099-01-01', display_location => 'FUTURE' );
    $put->($future);
    my $running = $make_display->( display_location => 'RUNNING' );
    $put->( $running,                                         date_added  => '2099-01-01' );
    $put->( $make_display->( display_location => 'REMOVED' ), date_remove => '2001-01-01' );
    is( $found->()->{effective_location}, 'CART', 'Inactive displays and display items do not change the location' );

    # An active one with a location replaces it
    my $active = $make_display->( display_location => 'DISPLAY1' );
    $put->($active);
    is( $found->()->{effective_location}, 'DISPLAY1', 'An active display sets the location' );

    # Without a location of its own it is described by its name
    $active->display_location(undef)->store;
    my $row = $found->();
    is(
        $row->{effective_location_description}, 'DISPLAY: Spring books',
        'The display is named when it has no location'
    );

    # The most recently added active display wins
    my $newer = $make_display->( display_location => 'NEWER', display_name => 'Newer' );
    $put->( $newer, date_added => '2000-06-01' );
    is( $found->()->{effective_location}, 'NEWER', 'The most recently added active display wins' );

    is(
        scalar( grep { $_->{itemnumber} == $item_on->itemnumber } @{ GetPendingOnSiteCheckouts() } ), 1,
        'The item is listed once'
    );

    # Module off: no display is looked at
    t::lib::Mocks::mock_preference( 'UseDisplayModule', 0 );
    $row = $found->();
    is( $row->{effective_location}, 'CART', 'With the module off the item keeps its location' );
    ok( !$row->{display_name},                          '...and is not described by a display' );
    ok( defined $row->{effective_location_description}, '...and still has a location description' );
};

$schema->storage->txn_rollback;

