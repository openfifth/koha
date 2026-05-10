#!/usr/bin/perl

# This script creates sample waiting holds covering all display scenarios
# for testing the waiting holds page (circ/waitingreserves.pl).
#
# Run inside KTD:
#   perl t/lib/sample_waiting_holds.pl
#
# Scenarios covered:
#   - Current waiting holds (not expired) — 25 holds
#   - Expired waiting holds (past expiration date) — 7 holds
#   - Holds with cancellation requests — 3 holds
#   - Holds with desk assigned
#   - Items with different home/holding branch (triggers "Cancel and return to")
#   - Items with shelving location, call number, copy number, enumeration
#   - Patrons with various primary_contact_method values
#   - Patrons with email (notice_email_address)
#   - Patrons with phone numbers

use Modern::Perl;

use C4::Context;
use C4::Reserves qw( AddReserve );
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Desks;
use Koha::Holds;
use Koha::Items;
use Koha::Libraries;
use Koha::Patrons;

my $schema = Koha::Database->new->schema;

# Get or create libraries
my @libraries = Koha::Libraries->search( {}, { rows => 3 } )->as_list;
die "Need at least 3 libraries" unless @libraries >= 3;

# Get or create a desk
my $desk = Koha::Desks->search( {}, { rows => 1 } )->next;
unless ($desk) {
    $desk = Koha::Desk->new(
        {
            desk_name  => 'Circulation Desk 1',
            branchcode => $libraries[0]->branchcode,
        }
    )->store;
}

# Get patrons and set varied contact methods
my @patrons = Koha::Patrons->search( {}, { rows => 10 } )->as_list;
die "Need at least 5 patrons" unless @patrons >= 5;

my @contact_methods = qw( phone email phonepro emailpro mobile );
for my $i ( 0 .. $#patrons ) {
    my $p = $patrons[$i];
    $p->primary_contact_method( $contact_methods[ $i % scalar @contact_methods ] )->store;
    $p->email("patron$i\@example.com")->store unless $p->email;
    $p->phone("555-010$i")->store             unless $p->phone;
    $p->phonepro("555-020$i")->store          unless $p->phonepro;
    $p->smsalertnumber("555-030$i")->store    unless $p->smsalertnumber;
}

# Get items and enrich some with location/callnumber/copynumber/enumchron
my @items = Koha::Items->search( { onloan => undef }, { rows => 40 } )->as_list;
die "Need at least 35 items" unless @items >= 35;

my @locations = ( 'FIC', 'NF', 'REF', 'YA', 'AV' );
for my $i ( 0 .. $#items ) {
    my $item = $items[$i];

    # Set shelving location on some
    if ( $i % 3 == 0 ) {
        $item->location( $locations[ $i % scalar @locations ] )->store;
    }

    # Set call number on most
    if ( $i % 2 == 0 ) {
        $item->itemcallnumber( sprintf( "%03d.%02d ABC", $i * 10, $i ) )->store;
    }

    # Set copy number on some
    if ( $i % 5 == 0 ) {
        $item->copynumber( "c." . ( $i + 1 ) )->store;
    }

    # Set enumchron on some
    if ( $i % 7 == 0 ) {
        $item->enumchron( "v." . ( $i + 1 ) . " no.1 (2025)" )->store;
    }

    # Make some items have different holding branch (triggers transfer on cancel)
    if ( $i % 4 == 0 && $item->homebranch ne $libraries[1]->branchcode ) {
        $item->holdingbranch( $libraries[1]->branchcode )->store;
    }
}

# Create waiting holds
my $today = dt_from_string()->ymd;
my $count = 0;

for my $i ( 0 .. 34 ) {
    my $patron = $patrons[ $i % scalar @patrons ];
    my $item   = $items[$i];
    next unless $item;

    my $hold_id = AddReserve(
        {
            branchcode     => $item->holdingbranch,
            borrowernumber => $patron->borrowernumber,
            biblionumber   => $item->biblionumber,
            itemnumber     => $item->itemnumber,
            priority       => 0,
            found          => 'W',
        }
    );

    next unless $hold_id;
    my $hold = Koha::Holds->find($hold_id);

    if ( $i >= 28 ) {

        # Expired holds (holdsover tab)
        $hold->expirationdate('2025-01-15')->waitingdate('2025-01-01')->store;
    } else {

        # Current holds (holdswaiting tab)
        $hold->expirationdate('2026-06-15')->waitingdate($today)->store;
    }

    # Assign desk to some holds
    if ( $i % 6 == 0 ) {
        $hold->desk_id( $desk->desk_id )->store;
    }

    $count++;
}

# Add cancellation requests to 3 holds
my @cr_holds = Koha::Holds->search(
    { found => 'W' },
    { rows  => 3, order_by => { -desc => 'reserve_id' } }
)->as_list;

for my $hold (@cr_holds) {
    $hold->add_cancellation_request;
}

print "Created $count waiting holds:\n";
print "  - "
    . Koha::Holds->search( { found => 'W', expirationdate => { '>=' => $today } } )->count
    . " current (holdswaiting tab)\n";
print "  - "
    . Koha::Holds->search( { found => 'W', expirationdate => { '<' => $today } } )->count
    . " expired (holdsover tab)\n";
print "  - " . scalar(@cr_holds) . " with cancellation requests (holdscancelled tab)\n";
print "  - Desk assigned, varied contact methods, transfer scenarios included\n";
