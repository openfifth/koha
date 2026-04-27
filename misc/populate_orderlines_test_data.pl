#!/usr/bin/perl

# Copyright 2024 PTFS Europe
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

=head1 NAME

populate_orderlines_test_data.pl - Populate the database with sample acquisitions orderlines data

=head1 SYNOPSIS

    perl misc/populate_orderlines_test_data.pl

Runs populate_finances_test_data.pl first to ensure fiscal periods, ledgers, and funds
exist, then creates three vendors, two additional fields for orderlines, six biblios,
and six orderlines covering all create_items values (ordering, receiving, cataloging,
NULL) with a mix of statuses, fund distributions, linked items, and additional field
values.

Any data previously created by this script is removed first, so it is safe to run
multiple times as a clean reset.

=cut

use Modern::Perl;
use File::Basename qw(dirname);

use Koha::Script;
use Koha::Acquisition::Bookseller;
use Koha::Acquisition::Booksellers;
use Koha::Acquisition::OrderManagement::Orderline;
use Koha::Acquisition::OrderManagement::Orderlines;
use Koha::Acquisition::OrderManagement::OrderlineItem;
use Koha::Acquisition::Finances::Funds;
use Koha::AdditionalField;
use Koha::AdditionalFields;
use Koha::Item;

use C4::Biblio qw( AddBiblio TransformKohaToMarc );

my $VENDOR_PREFIX = 'Sample Vendor - ';
my $FIELD_PREFIX  = 'Sample ';
my $CURRENCY      = 'USD';
my $BRANCH        = 'CPL';

# ---------------------------------------------------------------
# Run finances populate script first
# ---------------------------------------------------------------
print "Running finances populate script...\n";
my $finances_script = dirname(__FILE__) . '/populate_finances_test_data.pl';
system("perl $finances_script") == 0
    or die "Failed to run $finances_script\n";

# ---------------------------------------------------------------
# Cleanup: remove any data previously created by this script.
# Fund distributions use RESTRICT on delete so must be removed
# before their orderlines.
# ---------------------------------------------------------------
print "\nCleaning up existing orderline test data...\n";

my $existing_vendors = Koha::Acquisition::Booksellers->search( { name => { -like => $VENDOR_PREFIX . '%' } } );

if ( $existing_vendors->count ) {
    my @vendor_ids = map { $_->id } $existing_vendors->as_list;

    my $existing_orderlines =
        Koha::Acquisition::OrderManagement::Orderlines->search( { vendor_id => { -in => \@vendor_ids } } );
    while ( my $orderline = $existing_orderlines->next ) {
        $orderline->fund_distributions->delete;
    }
    $existing_orderlines->reset->delete;
    print "  Deleted orderlines (and fund distributions) for sample vendors\n";

    $existing_vendors->delete;
    print "  Deleted sample vendors\n";
}

my $existing_fields = Koha::AdditionalFields->search(
    {
        tablename => 'acq_orderlines',
        name      => { -like => $FIELD_PREFIX . '%' },
    }
);
if ( $existing_fields->count ) {
    $existing_fields->delete;
    print "  Deleted sample additional fields\n";
}

# ---------------------------------------------------------------
# Look up funds created by the finances script
# ---------------------------------------------------------------
print "\nLooking up funds...\n";

my @fund_codes = qw(
    SCI-BOOKS-2025
    HUM-BOOKS-2025
    SCI-JOUR-PRINT-2025
    SCI-JOUR-ELEC-2025
    HUM-MS-MED-2025
);

my %fund_for;
for my $code (@fund_codes) {
    my $fund = Koha::Acquisition::Finances::Funds->search( { code => $code } )->next;
    die "Fund '$code' not found — run populate_finances_test_data.pl first\n" unless $fund;
    $fund_for{$code} = $fund;
    print "  Found fund: $code (id=" . $fund->fund_id . ")\n";
}

# ---------------------------------------------------------------
# Vendors
# ---------------------------------------------------------------
print "\nCreating vendors...\n";

my $vendor_academic = Koha::Acquisition::Bookseller->new(
    {
        name          => $VENDOR_PREFIX . 'Academic Press',
        active        => 1,
        gstreg        => 1,
        listincgst    => 0,
        invoiceincgst => 0,
        tax_rate      => '0.2000',
        listprice     => $CURRENCY,
        invoiceprice  => $CURRENCY,
    }
)->store;
print "  Created: " . $vendor_academic->name . " (id=" . $vendor_academic->id . ", 20% VAT, tax-exclusive)\n";

my $vendor_global = Koha::Acquisition::Bookseller->new(
    {
        name          => $VENDOR_PREFIX . 'Global Books',
        active        => 1,
        gstreg        => 1,
        listincgst    => 1,
        invoiceincgst => 1,
        tax_rate      => '0.1000',
        listprice     => $CURRENCY,
        invoiceprice  => $CURRENCY,
    }
)->store;
print "  Created: " . $vendor_global->name . " (id=" . $vendor_global->id . ", 10% tax, tax-inclusive)\n";

my $vendor_digital = Koha::Acquisition::Bookseller->new(
    {
        name          => $VENDOR_PREFIX . 'Digital Subscriptions',
        active        => 1,
        gstreg        => 0,
        listincgst    => 0,
        invoiceincgst => 0,
        tax_rate      => '0.0000',
        listprice     => $CURRENCY,
        invoiceprice  => $CURRENCY,
    }
)->store;
print "  Created: " . $vendor_digital->name . " (id=" . $vendor_digital->id . ", tax-exempt)\n";

# ---------------------------------------------------------------
# Additional fields
# ---------------------------------------------------------------
print "\nCreating additional fields...\n";

my $dept_field = Koha::AdditionalField->new(
    {
        tablename      => 'acq_orderlines',
        name           => $FIELD_PREFIX . 'Requestor Department',
        marcfield      => '',
        marcfield_mode => 'get',
        searchable     => 1,
        repeatable     => 0,
    }
)->store;
print "  Created: '" . $dept_field->name . "' (id=" . $dept_field->id . ")\n";

my $priority_field = Koha::AdditionalField->new(
    {
        tablename      => 'acq_orderlines',
        name           => $FIELD_PREFIX . 'Priority Level',
        marcfield      => '',
        marcfield_mode => 'get',
        searchable     => 0,
        repeatable     => 0,
    }
)->store;
print "  Created: '" . $priority_field->name . "' (id=" . $priority_field->id . ")\n";

# ---------------------------------------------------------------
# Helper
# ---------------------------------------------------------------
sub create_biblio {
    my ($attrs) = @_;
    my $record = TransformKohaToMarc(
        {
            'biblio.title'                => $attrs->{title}            || '',
            'biblio.author'               => $attrs->{author}           || '',
            'biblioitems.isbn'            => $attrs->{isbn}             || '',
            'biblioitems.publishercode'   => $attrs->{publisher}        || '',
            'biblioitems.publicationyear' => $attrs->{publication_year} || '',
            'biblioitems.itemtype'        => $attrs->{itemtype}         || 'BK',
        }
    );
    my ($biblionumber) = AddBiblio( $record, '' );
    return $biblionumber;
}

# ---------------------------------------------------------------
# Biblios
# ---------------------------------------------------------------
print "\nCreating biblios...\n";

my @biblio_specs = (
    {
        title     => 'Advances in Molecular Biology', author           => 'Chen, Wei', isbn     => '9780123456789',
        publisher => 'Academic Press',                publication_year => '2023',      itemtype => 'BK'
    },
    {
        title     => 'Global Economics: A Modern Approach', author           => 'Patel, Anita', isbn => '9780987654321',
        publisher => 'Global Books',                        publication_year => '2022',         itemtype => 'BK'
    },
    {
        title     => 'Quantum Computing Fundamentals', author           => 'Miller, James', isbn     => '9781234567890',
        publisher => 'Academic Press',                 publication_year => '2024',          itemtype => 'BK'
    },
    {
        title     => 'Digital Humanities Quarterly', author           => 'Various', isbn     => '9780111222333',
        publisher => 'Digital Press',                publication_year => '2024',    itemtype => 'SR'
    },
    {
        title     => 'Medieval Manuscripts of Europe', author           => 'Beaumont, Claire', isbn => '9780444555666',
        publisher => 'Global Books',                   publication_year => '2021',             itemtype => 'BK'
    },
    {
        title     => 'Environmental Science Database', author => 'Research Consortium', isbn     => '9780777888999',
        publisher => 'Digital Press',                  publication_year => '2025',      itemtype => 'ER'
    },
);

my @biblionumbers;
for my $spec (@biblio_specs) {
    my $biblionumber = create_biblio($spec);
    push @biblionumbers, $biblionumber;
    print "  Created biblio: '$spec->{title}' (biblionumber=$biblionumber)\n";
}

# ---------------------------------------------------------------
# Orderline definitions
# ---------------------------------------------------------------
my @orderline_specs = (
    {
        orderline => {
            biblionumber          => $biblionumbers[0],
            vendor_id             => $vendor_academic->id,
            status                => 'new',
            create_items          => 'ordering',
            quantity_ordered      => 2,
            vendor_price          => '89.99',
            vendor_price_currency => $CURRENCY,
            urgent_order          => 1,
            statistic1            => 'SCIENCE',
            internal_note         => 'Rush order for new faculty reading list',
        },
        fund_distributions => [
            { fund_code => 'SCI-BOOKS-2025', percentage => 100 },
        ],
        items => [
            { homebranch => $BRANCH, holdingbranch => $BRANCH, itype => 'BK', location => 'MAIN' },
            { homebranch => $BRANCH, holdingbranch => $BRANCH, itype => 'BK', location => 'MAIN' },
        ],
        additional_fields => [
            { field => 'dept',     value => 'Life Sciences' },
            { field => 'priority', value => 'High' },
        ],
    },
    {
        orderline => {
            biblionumber          => $biblionumbers[1],
            vendor_id             => $vendor_global->id,
            status                => 'ordered',
            create_items          => 'ordering',
            quantity_ordered      => 1,
            vendor_price          => '55.00',
            vendor_price_currency => $CURRENCY,
            urgent_order          => 0,
            statistic1            => 'HUMANITIES',
            internal_note         => 'For undergraduate economics course',
        },
        fund_distributions => [
            { fund_code => 'HUM-BOOKS-2025', percentage => 60 },
            { fund_code => 'SCI-BOOKS-2025', percentage => 40 },
        ],
        items => [
            { homebranch => $BRANCH, holdingbranch => $BRANCH, itype => 'BK', location => 'MAIN' },
        ],
        additional_fields => [
            { field => 'dept',     value => 'Economics' },
            { field => 'priority', value => 'Medium' },
        ],
    },
    {
        orderline => {
            biblionumber          => $biblionumbers[2],
            vendor_id             => $vendor_academic->id,
            status                => 'ordered',
            create_items          => 'receiving',
            quantity_ordered      => 3,
            vendor_price          => '120.00',
            vendor_price_currency => $CURRENCY,
            urgent_order          => 0,
            statistic1            => 'SCIENCE',
            internal_note         => 'Awaiting delivery confirmation',
        },
        fund_distributions => [
            { fund_code => 'SCI-BOOKS-2025',     percentage => 70 },
            { fund_code => 'SCI-JOUR-ELEC-2025', percentage => 30 },
        ],
        additional_fields => [
            { field => 'dept',     value => 'Physics' },
            { field => 'priority', value => 'Low' },
        ],
    },
    {
        orderline => {
            biblionumber          => $biblionumbers[3],
            vendor_id             => $vendor_digital->id,
            status                => 'draft',
            create_items          => 'receiving',
            quantity_ordered      => 1,
            vendor_price          => '450.00',
            vendor_price_currency => $CURRENCY,
            urgent_order          => 0,
            statistic1            => 'HUMANITIES',
            internal_note         => 'Annual journal subscription renewal',
        },
        fund_distributions => [
            { fund_code => 'SCI-JOUR-PRINT-2025', percentage => 50 },
            { fund_code => 'SCI-JOUR-ELEC-2025',  percentage => 50 },
        ],
        additional_fields => [
            { field => 'dept',     value => 'Digital Humanities' },
            { field => 'priority', value => 'Medium' },
        ],
    },
    {
        orderline => {
            biblionumber          => $biblionumbers[4],
            vendor_id             => $vendor_global->id,
            status                => 'new',
            create_items          => 'cataloging',
            quantity_ordered      => 1,
            vendor_price          => '280.00',
            vendor_price_currency => $CURRENCY,
            urgent_order          => 0,
            statistic1            => 'HUMANITIES',
            internal_note         => 'Rare manuscripts acquisition',
        },
        fund_distributions => [
            { fund_code => 'HUM-MS-MED-2025', percentage => 100 },
        ],
        additional_fields => [
            { field => 'dept',     value => 'Special Collections' },
            { field => 'priority', value => 'High' },
        ],
    },
    {
        orderline => {
            biblionumber          => $biblionumbers[5],
            vendor_id             => $vendor_digital->id,
            status                => 'draft',
            quantity_ordered      => 1,
            vendor_price          => '1200.00',
            vendor_price_currency => $CURRENCY,
            urgent_order          => 0,
            statistic1            => 'SCIENCE',
            internal_note         => 'Database subscription — item creation via system preference',
        },
        fund_distributions => [
            { fund_code => 'SCI-BOOKS-2025', percentage => 60 },
            { fund_code => 'HUM-BOOKS-2025', percentage => 40 },
        ],
        additional_fields => [
            { field => 'dept',     value => 'Library Systems' },
            { field => 'priority', value => 'Low' },
        ],
    },
);

# ---------------------------------------------------------------
# Create orderlines, fund distributions, items, additional fields
# ---------------------------------------------------------------
print "\nCreating orderlines...\n";

for my $spec (@orderline_specs) {
    my $orderline = Koha::Acquisition::OrderManagement::Orderline->new( $spec->{orderline} )->store;
    print "\n  Created orderline id="
        . $orderline->orderline_id
        . "  status="
        . $orderline->status
        . "  create_items="
        . ( $orderline->create_items // 'NULL' ) . "\n";

    my @distributions;
    for my $dist ( @{ $spec->{fund_distributions} } ) {
        push @distributions, {
            fund_id                         => $fund_for{ $dist->{fund_code} }->fund_id,
            percentage                      => $dist->{percentage},
            distributed_amount_oc           => 0,
            exchange_rate                   => 1,
            distributed_amount              => 0,
            tax_rate                        => 0,
            tax_value                       => 0,
            distributed_amount_tax_excluded => 0,
            distributed_amount_tax_included => 0,
        };
        print "    Fund distribution: $dist->{percentage}% -> $dist->{fund_code}\n";
    }
    $orderline->fund_distributions( \@distributions );

    if ( $spec->{items} ) {
        for my $item_data ( @{ $spec->{items} } ) {
            my $item = Koha::Item->new(
                {
                    biblionumber  => $orderline->biblionumber,
                    homebranch    => $item_data->{homebranch},
                    holdingbranch => $item_data->{holdingbranch},
                    itype         => $item_data->{itype},
                    location      => $item_data->{location},
                }
            )->store;
            Koha::Acquisition::OrderManagement::OrderlineItem->new(
                {
                    orderline_id => $orderline->orderline_id,
                    itemnumber   => $item->itemnumber,
                }
            )->store;
            print "    Created item: itemnumber=" . $item->itemnumber . "\n";
        }
    }

    $orderline->set_additional_fields(
        [
            map {
                {
                    id    => ( $_->{field} eq 'dept' ? $dept_field->id : $priority_field->id ),
                    value => $_->{value},
                }
            } @{ $spec->{additional_fields} }
        ]
    );
    print "    Set additional fields\n";
}

print "\nDone.\n";
