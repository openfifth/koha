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

use Test::More tests => 5;
use Test::NoWarnings;
use Test::MockModule;

use Algorithm::CheckDigits qw( CheckDigits );

use Koha::AutoNumber;
use Koha::AutoNumber::Sequential;
use Koha::AutoNumber::EAN13;
use Koha::Patron::AutoNumber;

# Single stable mock — avoids the Test::MockModule scope issue where repeated
# t::lib::Mocks::mock_preference calls silently revert the mock.
my %prefs;
my $ctx_mock = Test::MockModule->new('C4::Context');
$ctx_mock->mock( 'preference', sub { $prefs{ lc( $_[1] ) } } );

my $ean = CheckDigits('ean');

# Patron-context config used throughout
my %patron_config = (
    format_pref  => 'autoMemberNumFormat',
    counter_pref => 'autoMemberNumValue',
    db_source    => 'Borrower',
    db_column    => 'cardnumber',
);

subtest 'Koha::AutoNumber factory tests' => sub {

    plan tests => 5;

    $prefs{automembernumformat} = '';
    isa_ok(
        Koha::AutoNumber->new( \%patron_config ),
        'Koha::AutoNumber::Sequential',
        'Empty format_pref defaults to Sequential'
    );

    $prefs{automembernumformat} = 'sequential';
    isa_ok(
        Koha::AutoNumber->new( \%patron_config ),
        'Koha::AutoNumber::Sequential',
        'sequential returns Sequential'
    );

    $prefs{automembernumformat} = 'ean13';
    isa_ok(
        Koha::AutoNumber->new( \%patron_config ),
        'Koha::AutoNumber::EAN13',
        'ean13 returns EAN13'
    );

    $prefs{automembernumformat} = 'unrecognised';
    isa_ok(
        Koha::AutoNumber->new( \%patron_config ),
        'Koha::AutoNumber::Sequential',
        'Unrecognised format_pref falls back to Sequential'
    );

    # Patron adapter returns the same strategy classes
    $prefs{automembernumformat} = 'ean13';
    isa_ok(
        Koha::Patron::AutoNumber->new,
        'Koha::AutoNumber::EAN13',
        'Koha::Patron::AutoNumber->new delegates to Koha::AutoNumber'
    );
};

subtest 'Sequential::effective_floor uses base-class default' => sub {

    plan tests => 2;

    my $gen = bless {%patron_config}, 'Koha::AutoNumber::Sequential';

    is( $gen->effective_floor(0),   0,   'Floor of 0 is 0' );
    is( $gen->effective_floor(999), 999, 'Floor returns counter unchanged' );
};

subtest 'EAN13::_next_from arithmetic' => sub {

    plan tests => 4;

    my $gen = bless {%patron_config}, 'Koha::AutoNumber::EAN13';

    # From 0: base = int(0/10)+1 = 1
    my $first = $gen->_next_from(0);
    ok( $ean->is_valid($first), "First value ($first) is a valid EAN-13" );
    is( length($first), 13, 'First value is exactly 13 digits' );

    # From a real EAN-13
    my $prev = 9780201633610;
    my $next = $gen->_next_from($prev);
    ok( $ean->is_valid($next), "Next after $prev ($next) is a valid EAN-13" );
    ok( $next > $prev,         'Generated value is greater than previous' );
};

subtest 'EAN13 uses base-class defaults for format_value and effective_floor' => sub {

    plan tests => 2;

    my $gen = bless {%patron_config}, 'Koha::AutoNumber::EAN13';

    is( $gen->format_value(42),     '42', 'format_value: base-class default (no padding)' );
    is( $gen->effective_floor(500), 500,  'effective_floor: base-class default (counter unchanged)' );
};
