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
use Test::More tests => 2;

use t::lib::TestBuilder;

use Koha::Acquisition::OrderManagement::OrderlineManagers;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'patron() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron    = $builder->build_object( { class => 'Koha::Patrons' } );
    my $orderline = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::Orderlines',
            value => { quantity_ordered => 1 }
        }
    );
    my $manager = $builder->build_object(
        {
            class => 'Koha::Acquisition::OrderManagement::OrderlineManagers',
            value => { orderline_id => $orderline->orderline_id, borrowernumber => $patron->borrowernumber }
        }
    );

    ok( $manager->patron, 'patron() returns a defined object' );
    is( $manager->patron->borrowernumber, $patron->borrowernumber, 'patron() returns the correct patron' );

    $schema->storage->txn_rollback;
};
