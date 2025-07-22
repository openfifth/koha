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

edi_process_service_charges.pl - Process MOA+8 service charges (ALC+C) from EDI invoices

=head1 SYNOPSIS

edi_process_service_charges.pl [--confirm|--execute] [--dry-run] [--help] [--verbose]

=head1 DESCRIPTION

This script processes EDI invoice messages that have been received and creates
invoice adjustments for any MOA+8 service charges (ALC+C) found in the EDIFACT data.
Allowances (ALC+A) are skipped as they don't require separate adjustments.

It should be run after edi_cron.pl to capture service charges that are not 
handled by the standard EDI processing.

IMPORTANT: Since MOA+128/203 totals are inclusive of service charges, this script
also reduces the orderline unit prices to avoid double-counting when service 
charges are extracted as separate adjustments.

=head1 OPTIONS

=over 8

=item B<--dry-run>

Don't actually create invoice adjustments, just show what would be done. This is the default mode.

=item B<--confirm> or B<--execute>

Actually create invoice adjustments. Required to make database changes.

=item B<--verbose>

Provide detailed output of processing.

=item B<--help>

Print this help message.

=back

=cut

use Getopt::Long;
use Pod::Usage;

my $help    = 0;
my $dry_run = 1;    # Default to dry-run mode
my $confirm = 0;
my $verbose = 0;

GetOptions(
    'help|?'          => \$help,
    'dry-run'         => \$dry_run,
    'confirm|execute' => \$confirm,
    'verbose'         => \$verbose,
) or pod2usage(2);

# If --confirm is specified, disable dry-run mode
if ($confirm) {
    $dry_run = 0;
}

pod2usage(1) if $help;

die "Syspref 'EDIFACT' is disabled" unless C4::Context->preference('EDIFACT');

my $schema = Koha::Database->new()->schema();
my $logger = Koha::Logger->get( { interface => 'edi', prefix => 0 } );

if ($dry_run) {
    print "Processing EDI service charges (DRY RUN - use --confirm to make actual changes)\n" if $verbose;
} else {
    print "Processing EDI service charges (LIVE MODE - making database changes)\n" if $verbose;
    $logger->info("EDI Service Charges");
}

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

$logger->info( "EDI Service Charges: Found " . scalar(@invoice_messages) . " invoice messages to process" );

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
        $logger->error( "EDI Service Charges:    Error processing invoice message " . $invoice_message->id . ": $@" );
        print "ERROR: Failed to process message " . $invoice_message->id . ": $@\n";
    }
}

print "Processed $processed_count invoice messages\n";
print "Created $adjustment_count service charge adjustments\n";

$logger->info(
    "EDI Service Charges: Completed processing. Processed $processed_count messages, created $adjustment_count adjustments"
);

sub process_invoice_service_charges {
    my ( $invoice_message, $dry_run, $verbose ) = @_;

    my $adjustments_created = 0;

    # Parse the EDI message
    my $edi      = Koha::Edifact->new( { transmission => $invoice_message->raw_msg } );
    my $messages = $edi->message_array();

    unless ( @{$messages} ) {
        return 0;
    }

    foreach my $msg ( @{$messages} ) {

        # Find the Koha invoice for this specific message within the transmission
        # Each message has its own BGM segment with invoice number
        my $koha_invoice = find_koha_invoice_for_message( $invoice_message, $msg );
        if ( !$koha_invoice ) {
            print "  WARNING: Could not find Koha invoice for message within transmission "
                . $invoice_message->id . "\n";
            $logger->warn( "EDI Service Charges:    Could not find Koha invoice for message within transmission "
                    . $invoice_message->id );
            next;
        }

        print "  Processing message for invoice "
            . $koha_invoice->invoiceid . " ("
            . $koha_invoice->invoicenumber . ")\n"
            if $verbose;

        # First, handle message-level allowances and charges
        my $message_alcs = get_message_allowances_charges($msg);

        foreach my $alc_data (@$message_alcs) {
            my $type         = $alc_data->{type};
            my $amount       = $alc_data->{amount};
            my $service_code = $alc_data->{service_code} || 'UNKNOWN';
            my $description  = $alc_data->{description}  || '';

            print "  Found invoice-level $type: $amount ($service_code)\n" if $verbose;

            # Skip allowances - only process charges
            if ( $type eq 'allowance' ) {
                print "  Skipping allowance - not creating adjustment\n" if $verbose;
                $logger->info( "EDI Service Charges: Skipped invoice-level allowance for invoice "
                        . $koha_invoice->invoicenumber
                        . ": amount=$amount, service_code=$service_code" );
                next;
            }

            # Get vendor name and map to budget ID
            my $vendor_name = get_vendor_name_from_message($invoice_message);
            my $budget_id   = map_vendor_to_budget_id($vendor_name);

            print "  Vendor: $vendor_name -> Budget: $budget_id\n" if $verbose && $vendor_name;

            my $reason   = 'EDI_CHARGE';                                        # Only processing charges now
            my $existing = $schema->resultset('AqinvoiceAdjustment')->search(
                {
                    invoiceid  => $koha_invoice->invoiceid,
                    reason     => $reason,
                    adjustment => $amount,
                    note       => { 'LIKE' => "%Invoice-level%" }
                }
            )->first;

            # Calculate adjustment amount based on CalculateFundValuesIncludingTax syspref
            my $adjustment_amount = calculate_adjustment_amount( $amount, $alc_data->{tax_amount} );

            # Skip £0 adjustments - SAP/Basware doesn't allow 0 values on GL lines (ticket 149681)
            if ( $adjustment_amount == 0 ) {
                print "  Skipping invoice-level £0 adjustment\n" if $verbose;
                $logger->info( "EDI Service Charges: Skipped invoice-level £0 adjustment for invoice "
                        . $koha_invoice->invoicenumber
                        . ": service_code=$service_code" );
                next;
            }

            if ( !$existing && !$dry_run ) {
                # Use tax rate from EDI TAX segment
                my $tax_rate_pct = $alc_data->{tax_rate} || 0;

                my $note = sprintf(
                    'Invoice-level %s from EDI (ALC+%s, MOA+8) - Service: %s%s | Tax Rate: %s%% | EDI_EXCL: %s | EDI_TAX: %s',
                    $type,
                    ( $type eq 'charge' ? 'C' : 'A' ),
                    $service_code,
                    $description ? " ($description)" : '',
                    $tax_rate_pct,
                    $amount,
                    $alc_data->{tax_amount} || 0
                );

                my $adjustment = $schema->resultset('AqinvoiceAdjustment')->create(
                    {
                        invoiceid     => $koha_invoice->invoiceid,
                        adjustment    => $adjustment_amount,
                        reason        => $reason,
                        budget_id     => $budget_id,
                        note          => $note,
                        encumber_open => 1,
                    }
                );

                print "  Created invoice-level adjustment ID " . $adjustment->adjustment_id . " for $adjustment_amount"
                    . " (charge: $amount, tax: " . $alc_data->{tax_amount} . ")\n"
                    if $verbose;
                $logger->info( "EDI Service Charges:      Created invoice-level adjustment ID "
                        . $adjustment->adjustment_id
                        . " for invoice "
                        . $koha_invoice->invoicenumber
                        . ": adjustment=$adjustment_amount (charge=$amount, tax=" . $alc_data->{tax_amount}
                        . "), budget_id=$budget_id, service_code=$service_code" );
                $adjustments_created++;
            } elsif ( !$existing ) {
                print "  Would create invoice-level $type adjustment: $adjustment_amount"
                    . " (charge: $amount, tax: " . $alc_data->{tax_amount} . ")\n";
                $logger->info( "EDI Service Charges: [DRY-RUN] Would create invoice-level adjustment for invoice "
                        . $koha_invoice->invoicenumber
                        . ": adjustment=$adjustment_amount (charge=$amount, tax=" . $alc_data->{tax_amount}
                        . "), budget_id=$budget_id, service_code=$service_code" );
                $adjustments_created++;
            } else {
                $logger->info( "EDI Service Charges: Skipped duplicate invoice-level adjustment for invoice "
                        . $koha_invoice->invoicenumber
                        . ": amount=$amount, service_code=$service_code (existing ID "
                        . $existing->adjustment_id
                        . ")" );
            }
        }

        # Then handle line-level allowances and charges
        my $lines = $msg->lineitems();
        my $orders_processed = {};

        foreach my $line ( @{$lines} ) {

            # Get all allowances and charges for this line
            my $allowances_charges = get_line_allowances_charges($line);

            unless (@$allowances_charges) {
                next;
            }

            foreach my $alc_data (@$allowances_charges) {
                my $type         = $alc_data->{type};     # 'charge' or 'allowance'
                my $amount       = $alc_data->{amount};
                my $service_code = $alc_data->{service_code} || 'UNKNOWN';
                my $description  = $alc_data->{description}  || '';

                print "  Found $type: $amount ($service_code) for line " . $line->line_item_number . "\n" if $verbose;

                # Skip allowances - only process charges
                if ( $type eq 'allowance' ) {
                    print "  Skipping line-level allowance - not creating adjustment\n" if $verbose;
                    $logger->info( "EDI Service Charges: Skipped line-level allowance for line "
                            . $line->line_item_number
                            . " in invoice "
                            . $koha_invoice->invoicenumber
                            . ": amount=$amount, service_code=$service_code" );
                    next;
                }

                # Check if we already have this adjustment
                my $reason              = 'EDI_CHARGE';    # Only processing charges now
                my $existing_adjustment = $schema->resultset('AqinvoiceAdjustment')->search(
                    {
                        invoiceid  => $koha_invoice->invoiceid,
                        reason     => $reason,
                        adjustment => $amount,
                        note       => { 'LIKE' => "%EDI Line: " . $line->line_item_number . "%" }
                    }
                )->first;

                if ($existing_adjustment) {
                    print "  $type adjustment already exists for invoice " . $koha_invoice->invoiceid . "\n"
                        if $verbose;
                    $logger->info( "EDI Service Charges: Skipped duplicate line-level adjustment for line "
                            . $line->line_item_number
                            . " in invoice "
                            . $koha_invoice->invoicenumber
                            . ": amount=$amount, service_code=$service_code (existing ID "
                            . $existing_adjustment->adjustment_id
                            . ")" );
                    next;
                }

                # Get vendor name and map to budget ID
                my $vendor_name = get_vendor_name_from_message($invoice_message);
                my $budget_id   = map_vendor_to_budget_id($vendor_name);

                print "  Vendor: $vendor_name -> Budget: $budget_id\n" if $verbose && $vendor_name;

                # Calculate adjustment amount based on CalculateFundValuesIncludingTax syspref
                my $adjustment_amount = calculate_adjustment_amount( $amount, $alc_data->{tax_amount} );

                # Skip £0 adjustments - SAP/Basware doesn't allow 0 values on GL lines (ticket 149681)
                if ( $adjustment_amount == 0 ) {
                    print "  Skipping line-level £0 adjustment for line " . $line->line_item_number . "\n" if $verbose;
                    $logger->info( "EDI Service Charges: Skipped line-level £0 adjustment for line "
                            . $line->line_item_number
                            . " in invoice "
                            . $koha_invoice->invoicenumber
                            . ": service_code=$service_code" );
                    next;
                }

                if ( !$dry_run ) {

                    # Create the invoice adjustment with enhanced order linkage
                    # Find the actual received order (which may be split from the original)
                    my $edi_ordernumber = $line->ordernumber();
                    my $received_order =
                        find_received_order_for_invoice( $edi_ordernumber, $koha_invoice, $orders_processed );
                    my $actual_ordernumber = $received_order ? $received_order->ordernumber : undef;

                    # Use tax rate from EDI TAX segment
                    my $tax_rate_pct = $alc_data->{tax_rate} || 0;

                    my $note = sprintf(
                        'EDI %s: Order #%s%s | EDI Line: %s | Service: %s%s | Tax Rate: %s%% | EDI_EXCL: %s | EDI_TAX: %s',
                        ucfirst($type),
                        $actual_ordernumber || $edi_ordernumber || 'Unknown',
                        ( $actual_ordernumber && $actual_ordernumber != $edi_ordernumber )
                        ? " (split from #$edi_ordernumber)"
                        : '',
                        $line->line_item_number,
                        $service_code,
                        $description ? " ($description)" : '',
                        $tax_rate_pct,
                        $amount,
                        $alc_data->{tax_amount} || 0
                    );

                    my $adjustment = $schema->resultset('AqinvoiceAdjustment')->create(
                        {
                            invoiceid     => $koha_invoice->invoiceid,
                            adjustment    => $adjustment_amount,
                            reason        => $reason,
                            budget_id     => $budget_id,
                            note          => $note,
                            encumber_open => 1,
                        }
                    );

                    print "  Created adjustment ID " . $adjustment->adjustment_id . " for $adjustment_amount"
                        . " (charge: $amount, tax: " . $alc_data->{tax_amount} . ")\n" if $verbose;
                    $logger->info( "EDI Service Charges:      Created line-level adjustment ID "
                            . $adjustment->adjustment_id
                            . " for line "
                            . $line->line_item_number
                            . " in invoice "
                            . $koha_invoice->invoicenumber
                            . ": adjustment=$adjustment_amount (charge=$amount, tax=" . $alc_data->{tax_amount}
                            . "), budget_id=$budget_id, service_code=$service_code, order="
                            . ( $actual_ordernumber || $edi_ordernumber || 'unknown' ) );

                    # Adjust the orderline to avoid double-counting service charges
                    # Service charges are included in MOA+128/203 totals but we're extracting them separately
                    if ( $type eq 'charge' && $received_order ) {
                        adjust_orderline_for_service_charge(
                            $received_order, $amount, $alc_data->{tax_amount}, $verbose, $edi_ordernumber,
                            $line
                        );
                    } elsif ( $type eq 'charge' && !$received_order ) {
                        $logger->warn(
                            "EDI Service Charges: Cannot adjust orderline for service charge - no received order found for line "
                                . $line->line_item_number
                                . " (original order $edi_ordernumber)" );
                    }
                } else {

                    # For dry-run, also show the split order handling
                    my $edi_ordernumber = $line->ordernumber();
                    my $received_order =
                        find_received_order_for_invoice( $edi_ordernumber, $koha_invoice, $orders_processed );
                    my $actual_ordernumber = $received_order ? $received_order->ordernumber : undef;

                    my $order_info = $actual_ordernumber || $edi_ordernumber || 'Unknown';
                    if ( $actual_ordernumber && $actual_ordernumber != $edi_ordernumber ) {
                        $order_info .= " (split from #$edi_ordernumber)";
                    }

                    print "  Would create $type adjustment for invoice "
                        . $koha_invoice->invoiceid
                        . ": $adjustment_amount (charge: $amount, tax: " . $alc_data->{tax_amount}
                        . ") [Budget: $budget_id] [Order: $order_info]\n";
                    $logger->info( "EDI Service Charges: [DRY-RUN] Would create line-level adjustment for line "
                            . $line->line_item_number
                            . " in invoice "
                            . $koha_invoice->invoicenumber
                            . ": adjustment=$adjustment_amount (charge=$amount, tax=" . $alc_data->{tax_amount}
                            . "), budget_id=$budget_id, service_code=$service_code, order=$order_info" );

                    if ( $type eq 'charge' ) {
                        if ($received_order) {
                            print "  Would adjust orderline $order_info to correct price based on EDI PRI data\n";
                        }
                    }
                }

                $adjustments_created++;
            }
        }
    }

    if ( !$dry_run ) {
        my $status = 'processed';
        $invoice_message->status($status);
        $invoice_message->update;
        print "Updated invoice message status to processed\n" if $verbose;
    } else {
        print "Would update invoice message status to processed\n";
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
            # Push any pending ALC that has an amount before starting new one
            if ( $current_alc && defined $current_alc->{amount} ) {
                push @allowances_charges, $current_alc;
            }

            my $qualifier    = $seg->elem(0);
            my $service_code = $seg->elem( 4, 0 ) || '';
            my $service_desc = $seg->elem( 4, 3 ) || '';

            $current_alc = {
                type         => ( $qualifier eq 'C' ) ? 'charge' : 'allowance',
                service_code => $service_code,
                description  => $service_desc,
                amount       => undef,
                tax_amount   => 0,       # Default to 0 if no tax segment found
                tax_rate     => 0        # Default to 0 if no tax segment found
            };
        } elsif ( $seg->tag eq 'TAX' && $current_alc ) {
            # Parse TAX segment: TAX+7+VAT+++:::20+S
            # Element 4,3 contains the tax rate percentage
            if ( $seg->elem(0) eq '7' ) {  # Tax category
                my $rate = $seg->elem( 4, 3 );
                $current_alc->{tax_rate} = $rate if defined $rate;
            }
        } elsif ( $seg->tag eq 'MOA' && $current_alc ) {
            if ( $seg->elem( 0, 0 ) eq '8' ) {
                $current_alc->{amount} = $seg->elem( 0, 1 );
            }
            # Check if this is MOA+124 (tax amount on charge/allowance)
            elsif ( $seg->elem( 0, 0 ) eq '124' && defined $current_alc->{amount} ) {
                $current_alc->{tax_amount} = $seg->elem( 0, 1 );
            }
        }
    }

    # Push any remaining ALC that has an amount
    if ( $current_alc && defined $current_alc->{amount} ) {
        push @allowances_charges, $current_alc;
    }

    return \@allowances_charges;
}

sub find_koha_invoice_for_message {
    my ( $invoice_message, $msg ) = @_;

    # Extract the BGM invoice number from this specific message using the existing method
    my $bgm_invoice_number = $msg->docmsg_number();
    if ( !$bgm_invoice_number ) {
        return;
    }

    # Find the Koha invoice by matching the BGM invoice number
    # Multiple invoices can have the same message_id (one transmission, multiple messages)
    my $schema       = Koha::Database->new()->schema();
    my $koha_invoice = $schema->resultset('Aqinvoice')->search(
        {
            message_id    => $invoice_message->id,
            invoicenumber => $bgm_invoice_number
        }
    )->first;

    unless ($koha_invoice) {
        $logger->warn( "EDI Service Charges: No Koha invoice found for BGM '$bgm_invoice_number' and message "
                . $invoice_message->id );
    }

    return $koha_invoice;
}

sub get_line_allowances_charges {
    my ($line) = @_;

    my @allowances_charges = ();
    my $current_alc        = undef;

    # Iterate through the line segments to find ALC + MOA+8 + MOA+124 sequences
    foreach my $seg ( @{ $line->{segs} } ) {
        if ( $seg->tag eq 'ALC' ) {
            # Push any pending ALC that has an amount before starting new one
            if ( $current_alc && defined $current_alc->{amount} ) {
                push @allowances_charges, $current_alc;
            }

            # Parse the ALC segment
            my $qualifier    = $seg->elem(0);               # C = Charge, A = Allowance
            my $service_code = $seg->elem( 4, 0 ) || '';    # Service description code
            my $service_desc = $seg->elem( 4, 3 ) || '';    # Service description text

            $current_alc = {
                type         => ( $qualifier eq 'C' ) ? 'charge' : 'allowance',
                service_code => $service_code,
                description  => $service_desc,
                amount       => undef,
                tax_amount   => 0,       # Default to 0 if no tax segment found
                tax_rate     => 0        # Default to 0 if no tax segment found
            };
        } elsif ( $seg->tag eq 'TAX' && $current_alc ) {
            # Parse TAX segment: TAX+7+VAT+++:::20+S
            # Element 4,3 contains the tax rate percentage
            if ( $seg->elem(0) eq '7' ) {  # Tax category
                my $rate = $seg->elem( 4, 3 );
                $current_alc->{tax_rate} = $rate if defined $rate;
            }
        } elsif ( $seg->tag eq 'MOA' && $current_alc ) {

            # Check if this is MOA+8 (allowance or charge amount)
            if ( $seg->elem( 0, 0 ) eq '8' ) {
                $current_alc->{amount} = $seg->elem( 0, 1 );
            }
            # Check if this is MOA+124 (tax amount on charge/allowance)
            elsif ( $seg->elem( 0, 0 ) eq '124' && defined $current_alc->{amount} ) {
                $current_alc->{tax_amount} = $seg->elem( 0, 1 );
            }
        }
    }

    # Push any remaining ALC that has an amount
    if ( $current_alc && defined $current_alc->{amount} ) {
        push @allowances_charges, $current_alc;
    }

    return \@allowances_charges;
}

sub get_vendor_name_from_message {
    my ($invoice_message) = @_;

    return '' unless $invoice_message;

    # Try direct vendor relationship first
    if ( $invoice_message->vendor ) {
        return $invoice_message->vendor->name;
    }

    # Fall back to EDI account relationship
    if ( $invoice_message->edi_acct && $invoice_message->edi_acct->vendor ) {
        return $invoice_message->edi_acct->vendor->name;
    }

    return '';
}

sub map_vendor_to_budget_id {
    my ($vendor_name) = @_;

    return '' unless $vendor_name;

    # Map vendor names to budget IDs
    if ( $vendor_name =~ /^WCC\b/i ) {
        return '104';    #'WCHG';
    } elsif ( $vendor_name =~ /^RBKC\b/i ) {
        return '76';     #KCHG';
    }

    # Default fallback - could be made configurable
    return '';
}

sub calculate_adjustment_amount {
    my ( $charge_amount, $tax_amount ) = @_;

    # Adjustments are added directly to budget calculations
    # Check if we should include tax based on the syspref
    if ( C4::Context->preference('CalculateFundValuesIncludingTax') ) {
        # Include tax in adjustment amount to match order line calculations
        return $charge_amount + $tax_amount;
    }

    # Return tax-exclusive amount
    return $charge_amount;
}

sub find_received_order_for_invoice {
    my ( $edi_ordernumber, $koha_invoice, $orders_processed ) = @_;

    unless ( $edi_ordernumber && $koha_invoice ) {
        return;
    }

    # Find all received orders for this invoice with parent_ordernumber = edi_ordernumber
    my @received_orders = $schema->resultset('Aqorder')->search(
        {
            invoiceid          => $koha_invoice->invoiceid,
            parent_ordernumber => $edi_ordernumber,
            orderstatus        => 'complete'
        },
        { order_by => { -asc => 'ordernumber' } }
    )->all;

    # If there is only one, it must be this order
    if ( @received_orders == 1 ) {
        my $received_order = $received_orders[0];
        $orders_processed->{ $received_order->ordernumber } = 1;
        return $received_order;
    }

    # If there are multiple, then we are in a split order scenario
    for my $actual_order (@received_orders) {
        next if ( $actual_order->ordernumber == $actual_order->parent_ordernumber );
        next if ( $orders_processed->{ $actual_order->ordernumber } );
        $orders_processed->{ $actual_order->ordernumber } = 1;
        return $actual_order;
    }

    # Fallback to first order if available
    if (@received_orders) {
        my $received_order = $received_orders[0];
        $orders_processed->{ $received_order->ordernumber } = 1;
        return $received_order;
    }

    # No matching order found for this EDI ordernumber
    return;
}

sub adjust_orderline_for_service_charge {
    my ( $order_to_adjust, $service_charge_amount, $service_charge_tax, $verbose, $original_ordernumber, $edi_line ) = @_;

    unless ($order_to_adjust) {
        return;
    }

    my $actual_ordernumber = $order_to_adjust->ordernumber;

    if ( $verbose && $actual_ordernumber != $original_ordernumber ) {
        my $parent_ordernumber = $order_to_adjust->parent_ordernumber || $original_ordernumber;
        print
            "  Found split order: EDI references $original_ordernumber, adjusting received order $actual_ordernumber (parent: $parent_ordernumber)\n";
    } elsif ($verbose) {
        print "  Using original order $original_ordernumber (no split occurred)\n";
    }

    # Use the same logic as _get_invoiced_price in Koha::EDI to get the base prices
    # Get quantity for per-unit calculation
    my $quantity = $order_to_adjust->quantityreceived || $order_to_adjust->quantity || 1;

    # Get MOA amounts from EDI data (these already include service charges)
    my $line_total = $edi_line->amt_total();       # MOA+128 (total including allowances & tax)
    my $excl_tax   = $edi_line->amt_lineitem();    # MOA+203 (item amount after allowances excluding tax)

    # If no tax some suppliers omit the total owed
    if ( !defined $line_total ) {
        my $tax_amount = $edi_line->amt_taxoncharge() || 0;
        $line_total = $excl_tax + $tax_amount;
    }

    # Convert to per-unit prices (invoices give amounts per orderline)
    my ( $base_unit_price_inc, $base_unit_price_exc );
    if ( $quantity != 1 ) {
        $base_unit_price_inc = $line_total / $quantity;
        $base_unit_price_exc = $excl_tax / $quantity;
    } else {
        $base_unit_price_inc = $line_total;
        $base_unit_price_exc = $excl_tax;
    }

    # Calculate per-unit service charge to subtract (to avoid double-counting)
    # MOA+8 is tax-exclusive, MOA+124 is the tax on the charge
    my $per_unit_service_charge_excl = $service_charge_amount / $quantity;
    my $per_unit_service_charge_tax  = $service_charge_tax / $quantity;
    my $per_unit_service_charge_incl = $per_unit_service_charge_excl + $per_unit_service_charge_tax;

    # Subtract service charges from base prices since we're creating separate adjustments
    # Use tax-exclusive for the tax-excluded price, tax-inclusive for the tax-included price
    my $final_unit_price_exc = $base_unit_price_exc - $per_unit_service_charge_excl;
    my $final_unit_price_inc = $base_unit_price_inc - $per_unit_service_charge_incl;

    # Use exact EDI tax value instead of recalculating (HMRC "Round Last" principle)
    # Get the original line tax from EDI and subtract the service charge tax
    # Note: tax_value_on_receiving is a TOTAL for all units, not per-unit
    my $original_line_tax = $edi_line->amt_taxoncharge() || 0;
    my $adjusted_tax_value = $original_line_tax - $service_charge_tax;

    # Set the order to the correct price (base EDI price - service charges)
    $order_to_adjust->update(
        {
            unitprice_tax_included => $final_unit_price_inc,
            unitprice_tax_excluded => $final_unit_price_exc,
            tax_value_on_receiving => $adjusted_tax_value,
        }
    );

    my $order_type =
        ( $actual_ordernumber != $original_ordernumber )
        ? "received order $actual_ordernumber (split from $original_ordernumber)"
        : "order $actual_ordernumber";
    print
        "  Set $order_type unit price_inc to $final_unit_price_inc (EDI base: $base_unit_price_inc - service charge incl tax: $per_unit_service_charge_incl)\n"
        if $verbose;
    print
        "  Set $order_type unit price_exc to $final_unit_price_exc (EDI base: $base_unit_price_exc - service charge excl tax: $per_unit_service_charge_excl)\n"
        if $verbose;
    print
        "  Set $order_type tax_value to $adjusted_tax_value (EDI line tax: $original_line_tax - service charge tax: $service_charge_tax) [TOTAL for all units]\n"
        if $verbose;

    # Single focused log message per EDI line segment showing adjustment and calculation
    $logger->info(
        "EDI Service Charges: Processed EDI line with service charge - Order: $order_type, Quantity: $quantity, "
        . "EDI base price_inc: $base_unit_price_inc, EDI base price_exc: $base_unit_price_exc, "
        . "Service charge (excl tax): $per_unit_service_charge_excl, Service charge tax: $per_unit_service_charge_tax, "
        . "Final price_inc: $final_unit_price_inc, Final price_exc: $final_unit_price_exc, "
        . "EDI line tax: $original_line_tax, Adjusted tax_value: $adjusted_tax_value"
    );
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

3. Test with dry-run first (default behavior):
   ./edi_process_service_charges.pl --verbose
   
4. When ready to make actual changes:
   ./edi_process_service_charges.pl --confirm --verbose

=head1 AUTHOR

Martin Renvoize <martin.renvoize@openfifth.co.uk>

=cut
