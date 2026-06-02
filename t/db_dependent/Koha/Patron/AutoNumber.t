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

use Algorithm::CheckDigits qw( CheckDigits );
use t::lib::TestBuilder;

use Koha::Database;
use Koha::AutoNumber::Sequential;
use Koha::AutoNumber::EAN13;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $ean     = CheckDigits('ean');

# Patron-context config — same values Koha::Patron::AutoNumber supplies
my %patron_cfg = (
    format_pref  => 'autoMemberNumFormat',
    counter_pref => 'autoMemberNumValue',
    db_source    => 'Borrower',
    db_column    => 'cardnumber',
);

sub set_counter {
    my ($value) = @_;
    $schema->resultset('Systempreference')
        ->search( { variable => 'autoMemberNumValue' } )
        ->update( { value    => $value } );
}

sub get_counter {
    my $row = $schema->resultset('Systempreference')->find( { variable => 'autoMemberNumValue' } );
    return $row ? $row->value + 0 : 0;
}

sub clear_numeric_cardnumbers {
    $schema->storage->dbh->do(q{UPDATE borrowers SET cardnumber = NULL WHERE cardnumber REGEXP '^[0-9]+$'});
}

subtest 'Sequential: db_max and next_value with patron context' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;
    clear_numeric_cardnumbers();

    my $gen = bless {%patron_cfg}, 'Koha::AutoNumber::Sequential';

    is( $gen->db_max($schema), 0, 'Empty table: db_max is 0' );

    $builder->build_object( { class => 'Koha::Patrons', value => { cardnumber => '1000' } } );
    is( $gen->db_max($schema), 1000, 'db_max reflects the patron cardnumber' );

    set_counter(0);
    is( $gen->next_value($schema), '1001', 'next_value: db_max=1000 wins over counter=0' );

    set_counter(5000);
    is( $gen->next_value($schema), '5001', 'next_value: counter=5000 wins over db_max' );

    is( get_counter(), 5001, 'autoMemberNumValue updated after generation' );

    $schema->storage->txn_rollback;
};

subtest 'EAN13: db_max with patron context' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;
    clear_numeric_cardnumbers();

    my $gen = bless {%patron_cfg}, 'Koha::AutoNumber::EAN13';

    is( $gen->db_max($schema), 0, 'Empty table: db_max is 0' );

    $builder->build_object( { class => 'Koha::Patrons', value => { cardnumber => '1000' } } );
    is( $gen->db_max($schema), 0, 'Short cardnumber (not 13 digits) excluded from EAN-13 db_max' );

    my $valid_ean = $ean->complete('978020163361');
    $builder->build_object( { class => 'Koha::Patrons', value => { cardnumber => $valid_ean } } );
    is( $gen->db_max($schema), $valid_ean + 0, '13-digit EAN-13 cardnumber included in db_max' );

    $builder->build_object( { class => 'Koha::Patrons', value => { cardnumber => 'ABC1234567890' } } );
    is( $gen->db_max($schema), $valid_ean + 0, 'Non-numeric cardnumber ignored' );

    $schema->storage->txn_rollback;
};

subtest 'EAN13: next_value with patron context' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;
    clear_numeric_cardnumbers();

    my $gen = bless {%patron_cfg}, 'Koha::AutoNumber::EAN13';

    set_counter(0);
    my $first = $gen->next_value($schema);
    ok( $ean->is_valid($first), "First generated value ($first) is a valid EAN-13" );
    is( length($first), 13,         'First generated value is 13 digits' );
    is( get_counter(),  $first + 0, 'autoMemberNumValue updated to the full EAN-13 value' );

    # Short cardnumber patron must not inflate the EAN-13 sequence
    $builder->build_object( { class => 'Koha::Patrons', value => { cardnumber => '99999' } } );
    set_counter(0);
    my $after_short = $gen->next_value($schema);
    ok( $ean->is_valid($after_short), 'Short-cardnumber patron does not inflate EAN-13 sequence' );
    is( length($after_short), 13, 'Value after short patron is still 13 digits' );

    $schema->storage->txn_rollback;
};

subtest 'peek: advisory preview without consuming the counter' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;
    clear_numeric_cardnumbers();

    my $seq = bless {%patron_cfg}, 'Koha::AutoNumber::Sequential';
    my $e13 = bless {%patron_cfg}, 'Koha::AutoNumber::EAN13';

    set_counter(10);
    is( $seq->peek($schema), '11', 'Sequential peek returns expected next value' );
    is( get_counter(),       10,   'peek does not update the counter' );

    # peek twice returns the same value (counter still not consumed)
    is( $seq->peek($schema), '11', 'peek is idempotent — same value on repeated calls' );

    # EAN-13 peek produces a valid barcode without consuming the counter
    set_counter(0);
    my $suggestion = $e13->peek($schema);
    ok( $ean->is_valid($suggestion), "EAN-13 peek ($suggestion) is a valid EAN-13" );
    is( get_counter(), 0, 'EAN-13 peek does not update the counter' );

    $schema->storage->txn_rollback;
};
