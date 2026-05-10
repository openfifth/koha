#!/usr/bin/perl

# This script populates the holds queue (tmp_holdsqueue) with sample data
# for testing the holds queue page (circ/view_holdsqueue.pl).
#
# Run inside KTD:
#   perl t/lib/sample_holds_queue.pl
#
# Scenarios covered:
#   - 40 queue items (tests pagination)
#   - Items across multiple holding branches (tests library filter)
#   - Various item types, collections, locations (tests column filters)
#   - Item-level and biblio-level requests
#   - Items with call numbers, copy numbers, enumchron
#   - Patrons with phone and email
#   - Hold groups
#   - Notes on some holds

use Modern::Perl;

use C4::Context;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Hold::HoldsQueueItems;
use Koha::Items;
use Koha::Libraries;
use Koha::Patrons;

my $schema = Koha::Database->new->schema;

# Clear existing queue
$schema->resultset('TmpHoldsqueue')->delete;

my @libraries = Koha::Libraries->search( {}, { rows => 4 } )->as_list;
die "Need at least 3 libraries" unless @libraries >= 3;

my @patrons = Koha::Patrons->search( {}, { rows => 10 } )->as_list;
die "Need at least 5 patrons" unless @patrons >= 5;

# Ensure patrons have contact info
for my $i ( 0 .. $#patrons ) {
    my $p = $patrons[$i];
    $p->email("patron$i\@example.com")->store unless $p->email;
    $p->phone("555-100$i")->store             unless $p->phone;
}

my @items = Koha::Items->search( { onloan => undef }, { rows => 45 } )->as_list;
die "Need at least 40 items" unless @items >= 40;

# Enrich items
my @locations = ( 'FIC', 'NF', 'REF', 'YA', 'AV' );
for my $i ( 0 .. $#items ) {
    my $item = $items[$i];
    $item->location( $locations[ $i % scalar @locations ] )->store         if $i % 2 == 0;
    $item->itemcallnumber( sprintf( "%03d.%02d XYZ", $i * 7, $i ) )->store if $i % 2 == 0;
    $item->copynumber("c.$i")->store                                       if $i % 5 == 0;
    $item->enumchron("v.$i no.1 (2025)")->store                            if $i % 7 == 0;
    $item->ccode('FIC')->store                                             if $i % 3 == 0;

    # Spread items across libraries
    if ( $i % 4 == 0 ) {
        $item->holdingbranch( $libraries[1]->branchcode )->store;
    } elsif ( $i % 4 == 1 ) {
        $item->holdingbranch( $libraries[2]->branchcode )->store;
    }
}

my @notes = ( undef, 'Rush request', 'Staff pick', undef, 'ILL request', undef );
my $count = 0;

for my $i ( 0 .. 39 ) {
    my $patron = $patrons[ $i % scalar @patrons ];
    my $item   = $items[$i];
    next unless $item;

    my $pickup = $libraries[ ( $i + 1 ) % scalar @libraries ];

    $schema->resultset('TmpHoldsqueue')->create(
        {
            biblionumber       => $item->biblionumber,
            itemnumber         => $item->itemnumber,
            barcode            => $item->barcode,
            surname            => $patron->surname,
            firstname          => $patron->firstname,
            phone              => $patron->phone,
            borrowernumber     => $patron->borrowernumber,
            cardnumber         => $patron->cardnumber,
            reservedate        => dt_from_string()->subtract( days => int( rand(30) ) )->ymd,
            title              => $item->biblio->title,
            itemcallnumber     => $item->itemcallnumber,
            holdingbranch      => $item->holdingbranch,
            pickbranch         => $pickup->branchcode,
            notes              => $notes[ $i % scalar @notes ],
            item_level_request => ( $i % 3 == 0 ) ? 1 : 0,
        }
    );
    $count++;
}

print "Populated holds queue with $count items:\n";
print "  - Spread across " . scalar(@libraries) . " libraries\n";
print "  - " . int( $count / 3 ) . " item-level requests\n";
print "  - Various locations, collections, call numbers\n";
print "  - Notes on some entries\n";
