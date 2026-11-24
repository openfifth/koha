#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw( $Bin );

use Test::NoWarnings;
use Test::More tests => 21;

BEGIN { use_ok('Koha::Edifact') }

my $filedir = "$Bin/edi_testfiles";

my @files = map { "$filedir/$_" } ( 'ordrsp1.CEA', 'ordrsp2.CEA', 'ordrsp3.CEA', 'ordrsp4.CEA' );

my @responses;
for my $filename (@files) {

    my $order_response = Koha::Edifact->new( { filename => $filename, } );

    isa_ok( $order_response, 'Koha::Edifact' );
    push @responses, $order_response;
}

# tests on file 1
# Order accepted with amendments
my $order_response = $responses[0];

my $msg       = $order_response->message_array();
my $no_of_msg = @{$msg};
is( $no_of_msg, 1, "Correct number of messages returned" );

isa_ok( $msg->[0], 'Koha::Edifact::Message' );

my $lines = $msg->[0]->lineitems();

my $no_of_lines = @{$lines};

is( $no_of_lines, 3, "Correct number of orderlines returned" );

#
is( $lines->[0]->ordernumber(), 'P28837', 'Line 1 correct ordernumber' );
is(
    $lines->[0]->coded_orderline_text(),
    'Not yet published',
    'NP returned and translated'
);

is( $lines->[1]->ordernumber(), 'P28838', 'Line 2 correct ordernumber' );
is(
    $lines->[1]->action_notification(),
    'cancelled', 'Cancelled action returned'
);
is(
    $lines->[1]->coded_orderline_text(),
    'Out of print', 'OP returned and translated'
);

is( $lines->[2]->ordernumber(), 'P28846', 'Line 3 correct ordernumber' );
is(
    $lines->[2]->action_notification(),
    'recorded', 'Accepted with change action returned'
);

is(
    $lines->[0]->availability_date(), '19971120',
    'Availability date returned'
);

# Coded reasons on a line, one entry for each FTX+LIN segment, as TABLE:CODE
is_deeply( $lines->[0]->orderline_codes, ['8B:NP'], 'Coded reason of a line is returned with its code list' );
is_deeply( $lines->[1]->orderline_codes, ['8B:OP'], 'Coded reason of a cancelled line is returned' );

# A line can carry several coded reasons without any free text (as sent by some suppliers)
my $transmission =
      "UNA:+.? 'UNB+UNOC:3+5412345000176+4012345000094+200101:1200+1++ORDRSP'"
    . "UNH+1+ORDRSP:D:96A:UN:EAN005'BGM+231+RSP001+9'"
    . "LIN+1+2+9780008711245:EN'QTY+21:1'"
    . "FTX+LIN++OP:8B:28'FTX+LIN++223:12B:28'"
    . "RFF+LI:63850'UNS+S'CNT+2:1'UNT+10+1'UNZ+1+1'";
my $multi = Koha::Edifact->new( { transmission => $transmission } );
my $line  = $multi->message_array->[0]->lineitems->[0];
is_deeply( $line->orderline_codes, [ '8B:OP', '12B:223' ], 'Every coded reason on the line is kept, in order' );
is(
    $line->coded_orderline_text, 'Oustanding order line cancelled: unable to supply',
    'The text still comes from the last coded reason'
);
