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
use Test::Exception;

use Koha::Token;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

BEGIN {
    use_ok('Koha::Module::Policy::Checkin');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Koha::Module::Policy::Checkin tests' => sub {

    plan tests => 3;

    subtest 'to_hashref() tests' => sub {

        plan tests => 19;

        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 0 } } );
        my $library = $builder->build_object( { class => 'Koha::Libraries' } );

        # Mock all relevant prefs to known values
        t::lib::Mocks::mock_preference( 'finesMode',                          'production' );
        t::lib::Mocks::mock_preference( 'FineNotifyAtCheckin',                1 );
        t::lib::Mocks::mock_preference( 'ExpireReservesMaxPickUpDelayCharge', 1 );
        t::lib::Mocks::mock_preference( 'SpecifyReturnDate',                  1 );
        t::lib::Mocks::mock_preference( 'CircConfirmItemParts',               1 );
        t::lib::Mocks::mock_preference( 'HoldsAutoFill',                      1 );
        t::lib::Mocks::mock_preference( 'HoldsAutoFillPrintSlip',             1 );
        t::lib::Mocks::mock_preference( 'WaitingNotifyAtCheckin',             1 );
        t::lib::Mocks::mock_preference( 'DisplayAddHoldGroups',               1 );
        t::lib::Mocks::mock_preference( 'UseRecalls',                         1 );
        t::lib::Mocks::mock_preference( 'TransfersBlockCirc',                 1 );
        t::lib::Mocks::mock_preference( 'AutomaticConfirmTransfer',           1 );
        t::lib::Mocks::mock_preference( 'ShowAllCheckins',                    1 );
        t::lib::Mocks::mock_preference( 'numReturnedItemsToShow',             12 );
        t::lib::Mocks::mock_preference( 'AudioAlerts',                        1 );
        t::lib::Mocks::mock_preference( 'CatalogConcerns',                    1 );
        t::lib::Mocks::mock_preference( 'BlockReturnOfWithdrawnItems',        1 );
        t::lib::Mocks::mock_preference( 'BlockReturnOfLostItems',             1 );

        my $policy = Koha::Module::Policy::Checkin->new(
            {
                user    => $patron,
                library => $library->branchcode,
            }
        );

        my $hashref = $policy->to_hashref;

        # User without writeoff permission - exempt_fine and forgive_hold_fees should be 0
        is( $hashref->{exempt_fine},       0, 'exempt_fine is 0 without writeoff perm' );
        is( $hashref->{forgive_hold_fees}, 0, 'forgive_hold_fees is 0 without writeoff perm' );

        # Prefs that are purely pref-driven
        is( $hashref->{fine_notify_at_checkin},     1,  'fine_notify_at_checkin reflects pref' );
        is( $hashref->{specify_return_date},        1,  'specify_return_date reflects pref' );
        is( $hashref->{dropbox_mode},               1,  'dropbox_mode always available' );
        is( $hashref->{confirm_item_parts},         1,  'confirm_item_parts reflects pref' );
        is( $hashref->{holds_auto_fill},            1,  'holds_auto_fill reflects pref' );
        is( $hashref->{holds_auto_fill_print_slip}, 1,  'holds_auto_fill_print_slip reflects pref' );
        is( $hashref->{waiting_notify_at_checkin},  1,  'waiting_notify_at_checkin reflects pref' );
        is( $hashref->{display_hold_groups},        1,  'display_hold_groups reflects pref' );
        is( $hashref->{recalls_enabled},            1,  'recalls_enabled reflects pref' );
        is( $hashref->{transfers_block},            1,  'transfers_block reflects pref' );
        is( $hashref->{auto_confirm_transfer},      1,  'auto_confirm_transfer reflects pref' );
        is( $hashref->{show_all_checkins},          1,  'show_all_checkins reflects pref' );
        is( $hashref->{max_returned_items},         12, 'max_returned_items reflects pref' );
        is( $hashref->{audio_alerts},               1,  'audio_alerts reflects pref' );
        is( $hashref->{catalog_concerns},           1,  'catalog_concerns reflects pref' );
        is( $hashref->{block_return_withdrawn},     1,  'block_return_withdrawn reflects pref' );
        is( $hashref->{block_return_lost},          1,  'block_return_lost reflects pref' );

        $schema->storage->txn_rollback;
    };

    subtest 'Permission-gated capabilities tests' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        # Superlibrarian has all permissions
        my $superlibrarian = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
        my $library        = $builder->build_object( { class => 'Koha::Libraries' } );

        t::lib::Mocks::mock_preference( 'finesMode',                          'production' );
        t::lib::Mocks::mock_preference( 'ExpireReservesMaxPickUpDelayCharge', 1 );

        my $policy = Koha::Module::Policy::Checkin->new(
            {
                user    => $superlibrarian,
                library => $library->branchcode,
            }
        );

        my $hashref = $policy->to_hashref;

        is( $hashref->{exempt_fine},       1, 'exempt_fine is 1 for superlibrarian' );
        is( $hashref->{forgive_hold_fees}, 1, 'forgive_hold_fees is 1 for superlibrarian' );

        $schema->storage->txn_rollback;
    };

    subtest 'as_jwt() tests' => sub {

        plan tests => 4;

        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 1 } } );
        my $library = $builder->build_object( { class => 'Koha::Libraries' } );

        t::lib::Mocks::mock_preference( 'finesMode',   'production' );
        t::lib::Mocks::mock_preference( 'UseRecalls',  1 );
        t::lib::Mocks::mock_preference( 'AudioAlerts', 0 );

        my $policy = Koha::Module::Policy::Checkin->new(
            {
                user    => $patron,
                library => $library->branchcode,
            }
        );

        my $jwt = $policy->as_jwt;
        ok( $jwt, 'as_jwt returns a value' );
        like( $jwt, qr/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/, 'JWT has three parts' );

        # Decode and verify payload
        my $claims = Koha::Token->new->decode_claims($jwt);

        is( $claims->{exempt_fine},     1, 'JWT payload carries exempt_fine correctly' );
        is( $claims->{recalls_enabled}, 1, 'JWT payload carries recalls_enabled correctly' );

        $schema->storage->txn_rollback;
    };
};
