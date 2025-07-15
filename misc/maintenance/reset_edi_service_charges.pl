#!/usr/bin/perl

use Modern::Perl;
use Koha::Database;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

reset_edi_service_charges.pl - Reset EDI service charge processing

=head1 SYNOPSIS

reset_edi_service_charges.pl [--dry-run] [--verbose] [--confirm]

=head1 DESCRIPTION

This script resets EDI service charge processing by:
1. Removing all existing EDI_CHARGE adjustments
2. Setting all processed EDI invoice messages back to 'received' status

After running this script, you can re-run the corrected edi_process_service_charges.pl
to process all invoices with the fixed logic.

=head1 OPTIONS

=over 8

=item B<--dry-run>

Don't make actual changes, just show what would be done (default)

=item B<--confirm>

Actually make the changes to the database

=item B<--verbose>

Show detailed progress information

=back

=cut

my $help = 0;
my $dry_run = 1;
my $confirm = 0;
my $verbose = 0;

GetOptions(
    'help|?'          => \$help,
    'dry-run'         => \$dry_run,
    'confirm'         => \$confirm,
    'verbose'         => \$verbose,
) or pod2usage(2);

if ($confirm) {
    $dry_run = 0;
}

pod2usage(1) if $help;

my $schema = Koha::Database->new()->schema();

print "=== EDI Service Charge Reset Script ===\n";
print $dry_run ? "DRY RUN MODE - No changes will be made\n" : "LIVE MODE - Making actual changes\n";
print "\n";

# Step 1: Remove all existing EDI_CHARGE adjustments
print "Step 1: Removing existing EDI_CHARGE adjustments...\n";
my @existing_adjustments = $schema->resultset('AqinvoiceAdjustment')->search({
    reason => 'EDI_CHARGE'
})->all;

print "Found " . scalar(@existing_adjustments) . " existing EDI_CHARGE adjustments\n";

my $removed_count = 0;
foreach my $adj (@existing_adjustments) {
    if ($verbose) {
        print "  Removing adjustment ID " . $adj->adjustment_id . 
              " from invoice " . $adj->invoiceid . 
              " (amount: " . $adj->adjustment . ")\n";
    }
    
    if (!$dry_run) {
        $adj->delete();
    }
    $removed_count++;
}

print "Removed $removed_count EDI_CHARGE adjustments\n\n";

# Step 2: Reset EDI invoice message statuses to 'received'
print "Step 2: Resetting EDI invoice message statuses...\n";
my @processed_messages = $schema->resultset('EdifactMessage')->search({
    message_type => 'INVOICE',
    status => 'processed'
})->all;

print "Found " . scalar(@processed_messages) . " processed EDI invoice messages\n";

my $reset_count = 0;
foreach my $msg (@processed_messages) {
    if ($verbose) {
        print "  Resetting message " . $msg->id . " (" . $msg->filename . ") to 'received'\n";
    }
    
    if (!$dry_run) {
        $msg->status('received');
        $msg->update();
    }
    $reset_count++;
}

print "Reset $reset_count EDI invoice messages to 'received' status\n\n";

print "=== Reset Complete ===\n";
if ($dry_run) {
    print "Run with --confirm to make actual changes\n";
} else {
    print "You can now run the corrected edi_process_service_charges.pl script:\n";
    print "  perl misc/cronjobs/edi_process_service_charges.pl --confirm --verbose\n";
}