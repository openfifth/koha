#!/usr/bin/perl

# Copyright 2025 Open Fifth
#
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use utf8;

use Koha::Script -cron;
use C4::Context;
use Koha::Database;
use Koha::Edifact;
use Koha::Logger;
use Koha::Acquisition::Invoice::Adjustments;

=head1 NAME

edi_process_service_charges.pl - Process MOA+203 service charges from EDI invoices

=head1 SYNOPSIS

edi_process_service_charges.pl [--dry-run] [--help] [--verbose]

=head1 DESCRIPTION

This script processes EDI invoice messages that have been received and creates
invoice adjustments for any MOA+203 service charges found in the EDIFACT data.

It should be run after edi_cron.pl to capture service charges that are not 
handled by the standard EDI processing.

=head1 OPTIONS

=over 8

=item B<--dry-run>

Don't actually create invoice adjustments, just show what would be done.

=item B<--verbose>

Provide detailed output of processing.

=item B<--help>

Print this help message.

=back

=cut

use Getopt::Long;
use Pod::Usage;

my $help    = 0;
my $dry_run = 0;
my $verbose = 0;

GetOptions(
    'help|?'  => \$help,
    'dry-run' => \$dry_run,
    'verbose' => \$verbose,
) or pod2usage(2);

pod2usage(1) if $help;

die "Syspref 'EDIFACT' is disabled" unless C4::Context->preference('EDIFACT');

my $schema = Koha::Database->new()->schema();
my $logger = Koha::Logger->get( { interface => 'edi', prefix => 0 } );

print "Processing EDI service charges..." . ( $dry_run ? " (DRY RUN)" : "" ) . "\n" if $verbose;

# Find invoice messages that have been received but not yet processed for service charges
my @invoice_messages = $schema->resultset('EdifactMessage')->search(
    {
        message_type => 'INVOICE',
        status       => 'received',

        # Add a custom field to track if we've processed service charges
        # You might want to add a custom field to edifact_messages table
        # or use another approach to track processed messages
    }
)->all;

my $processed_count  = 0;
my $adjustment_count = 0;

foreach my $invoice_message (@invoice_messages) {
    print "Processing message ID: " . $invoice_message->id . " (" . $invoice_message->filename . ")\n" if $verbose;

    eval {
        my $adjustments_created = process_invoice_service_charges( $invoice_message, $dry_run, $verbose );
        $adjustment_count += $adjustments_created;
        $processed_count++;
    };
    if ($@) {
        $logger->error( "Error processing invoice message " . $invoice_message->id . ": $@" );
        print "ERROR: Failed to process message " . $invoice_message->id . ": $@\n";
    }
}

print "Processed $processed_count invoice messages\n";
print "Created $adjustment_count service charge adjustments\n";

sub process_invoice_service_charges {
    my ( $invoice_message, $dry_run, $verbose ) = @_;

    my $adjustments_created = 0;

    # Parse the EDI message
    my $edi      = Koha::Edifact->new( { transmission => $invoice_message->raw_msg } );
    my $messages = $edi->message_array();

    return 0 unless @{$messages};

    foreach my $msg ( @{$messages} ) {

        # First, handle message-level allowances and charges
        my $message_alcs = get_message_allowances_charges($msg);
        foreach my $alc_data (@$message_alcs) {
            my $type         = $alc_data->{type};
            my $amount       = $alc_data->{amount};
            my $service_code = $alc_data->{service_code} || 'UNKNOWN';
            my $description  = $alc_data->{description}  || '';

            print "  Found invoice-level $type: $amount ($service_code)\n" if $verbose;

            # Find the Koha invoice for this message
            my $koha_invoice = find_koha_invoice_for_message($invoice_message);

            if ($koha_invoice) {
                my $reason   = $type eq 'charge' ? 'EDI_CHARGE' : 'EDI_ALLOWANCE';
                my $existing = $schema->resultset('AqinvoiceAdjustment')->search(
                    {
                        invoiceid  => $koha_invoice->invoiceid,
                        reason     => $reason,
                        adjustment => $amount,
                        note       => { 'LIKE' => "%Invoice-level%" }
                    }
                )->first;

                if ( !$existing && !$dry_run ) {
                    my $note = sprintf(
                        'Invoice-level %s from EDI (ALC+%s, MOA+8) - Service: %s%s',
                        $type,
                        ( $type eq 'charge' ? 'C' : 'A' ),
                        $service_code,
                        $description ? " ($description)" : ''
                    );

                    my $adjustment = $schema->resultset('AqinvoiceAdjustment')->create(
                        {
                            invoiceid     => $koha_invoice->invoiceid,
                            adjustment    => $amount,
                            reason        => $reason,
                            note          => $note,
                            encumber_open => 1,
                        }
                    );

                    print "  Created invoice-level adjustment ID " . $adjustment->adjustment_id . " for $amount\n"
                        if $verbose;
                    $adjustments_created++;
                } elsif ( !$existing ) {
                    print "  Would create invoice-level $type adjustment: $amount\n";
                    $adjustments_created++;
                }
            }
        }

        # Then handle line-level allowances and charges
        my $lines = $msg->lineitems();

        foreach my $line ( @{$lines} ) {

            # Get all allowances and charges for this line
            my $allowances_charges = get_line_allowances_charges($line);

            next unless @$allowances_charges;

            foreach my $alc_data (@$allowances_charges) {
                my $type         = $alc_data->{type};     # 'charge' or 'allowance'
                my $amount       = $alc_data->{amount};
                my $service_code = $alc_data->{service_code} || 'UNKNOWN';
                my $description  = $alc_data->{description}  || '';

                print "  Found $type: $amount ($service_code) for line " . $line->line_item_number . "\n" if $verbose;

                # Find the corresponding invoice in Koha
                my $koha_invoice = find_koha_invoice_for_line( $line, $invoice_message );

                if ( !$koha_invoice ) {
                    print "  WARNING: Could not find Koha invoice for line " . $line->line_item_number . "\n";
                    next;
                }

                # Check if we already have this adjustment
                my $reason              = $type eq 'charge' ? 'EDI_CHARGE' : 'EDI_ALLOWANCE';
                my $existing_adjustment = $schema->resultset('AqinvoiceAdjustment')->search(
                    {
                        invoiceid  => $koha_invoice->invoiceid,
                        reason     => $reason,
                        adjustment => $amount,
                        note       => { 'LIKE' => "%Line: " . $line->line_item_number . "%" }
                    }
                )->first;

                if ($existing_adjustment) {
                    print "  $type adjustment already exists for invoice " . $koha_invoice->invoiceid . "\n"
                        if $verbose;
                    next;
                }

                if ( !$dry_run ) {

                    # Create the invoice adjustment
                    my $note = sprintf(
                        '%s from EDI invoice (ALC+%s, MOA+8) - Line: %s, Service: %s%s',
                        ucfirst($type),
                        ( $type eq 'charge' ? 'C' : 'A' ),
                        $line->line_item_number,
                        $service_code,
                        $description ? " ($description)" : ''
                    );

                    my $adjustment = $schema->resultset('AqinvoiceAdjustment')->create(
                        {
                            invoiceid     => $koha_invoice->invoiceid,
                            adjustment    => $amount,
                            reason        => $reason,
                            note          => $note,
                            encumber_open => 1,
                        }
                    );

                    print "  Created adjustment ID " . $adjustment->adjustment_id . " for $amount\n" if $verbose;
                    $logger->info( "Created $type adjustment for invoice " . $koha_invoice->invoiceid . ": $amount" );
                } else {
                    print "  Would create $type adjustment for invoice " . $koha_invoice->invoiceid . ": $amount\n";
                }

                $adjustments_created++;
            }
        }
    }

    if ( !$dry_run ) {
        my $status = 'post-' . $invoice_message->status;
        $invoice_message->status($status);
        $invoice_message->update;
        print "Updated invoice message status to post-" . $invoice_message->status . "\n" if $verbose;
    } else {
        print "Would update invoice message status to post-" . $invoice_message->status . "\n";
    }

    return $adjustments_created;
}

sub get_message_allowances_charges {
    my ($msg) = @_;

    my @allowances_charges = ();
    my $current_alc        = undef;

    # Look for ALC segments before the first LIN segment (invoice-level)
    foreach my $seg ( @{ $msg->{datasegs} } ) {
        last if $seg->tag eq 'LIN';    # Stop at first line item

        if ( $seg->tag eq 'ALC' ) {
            my $qualifier    = $seg->elem(0);
            my $service_code = $seg->elem( 4, 0 ) || '';
            my $service_desc = $seg->elem( 4, 3 ) || '';

            $current_alc = {
                type         => ( $qualifier eq 'C' ) ? 'charge' : 'allowance',
                service_code => $service_code,
                description  => $service_desc,
                amount       => undef
            };
        } elsif ( $seg->tag eq 'MOA' && $current_alc ) {
            if ( $seg->elem( 0, 0 ) eq '8' ) {
                $current_alc->{amount} = $seg->elem( 0, 1 );
                push @allowances_charges, $current_alc;
                $current_alc = undef;
            }
        }
    }

    return \@allowances_charges;
}

sub find_koha_invoice_for_message {
    my ($invoice_message) = @_;

    # Find invoice by message_id in aqinvoices table
    my $schema = Koha::Database->new()->schema();
    return $schema->resultset('Aqinvoice')->search( { message_id => $invoice_message->id } )->first;
}

sub get_line_allowances_charges {
    my ($line) = @_;

    my @allowances_charges = ();
    my $current_alc        = undef;

    # Iterate through the line segments to find ALC + MOA+8 pairs
    foreach my $seg ( @{ $line->{segs} } ) {
        if ( $seg->tag eq 'ALC' ) {

            # Parse the ALC segment
            my $qualifier    = $seg->elem(0);               # C = Charge, A = Allowance
            my $service_code = $seg->elem( 4, 0 ) || '';    # Service description code
            my $service_desc = $seg->elem( 4, 3 ) || '';    # Service description text

            $current_alc = {
                type         => ( $qualifier eq 'C' ) ? 'charge' : 'allowance',
                service_code => $service_code,
                description  => $service_desc,
                amount       => undef
            };
        } elsif ( $seg->tag eq 'MOA' && $current_alc ) {

            # Check if this is MOA+8 (allowance or charge amount)
            if ( $seg->elem( 0, 0 ) eq '8' ) {
                $current_alc->{amount} = $seg->elem( 0, 1 );
                push @allowances_charges, $current_alc;
                $current_alc = undef;    # Reset for next ALC
            }
        }
    }

    return \@allowances_charges;
}

sub find_koha_invoice_for_line {
    my ( $line, $invoice_message ) = @_;

    my $ordernumber = $line->ordernumber();
    return unless $ordernumber;

    # Find the invoice via the ordernumber
    my $order = $schema->resultset('Aqorder')->find($ordernumber);
    return unless $order && $order->get_column('invoiceid');

    return $schema->resultset('Aqinvoice')->find( $order->get_column('invoiceid') );
}

=head1 SETUP INSTRUCTIONS

1. Add this to your crontab after edi_cron.pl:
   
   # Process EDI invoices (standard)
   0 */2 * * * /path/to/koha/misc/cronjobs/edi_cron.pl
   
   # Process service charges (runs 15 minutes after)
   15 */2 * * * /path/to/koha/misc/cronjobs/edi_process_service_charges.pl

2. Create the ADJ_REASON authorised values:
   - Go to Administration > Authorised Values
   - Add category ADJ_REASON if it doesn't exist
   - Add value: EDI_CHARGE with description "EDI Charge (ALC+C)"
   - Add value: EDI_ALLOWANCE with description "EDI Allowance (ALC+A)"

3. Test with dry-run first:
   ./edi_process_service_charges.pl --dry-run --verbose

=head1 AUTHOR

Martin Renvoize <martin.renvoize@openfifth.co.uk>

=cut
