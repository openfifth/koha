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

populate_finances_test_data.pl - Populate the database with sample acquisitions finances data

=head1 SYNOPSIS

    perl misc/populate_finances_test_data.pl

Creates two library groups, two fiscal periods, two ledgers per fiscal period,
and several funds per ledger (some with sub-funds). Each ledger and fund receives
an initial increase allocation; selected funds also have decrease allocations and
transfers between funds.

Any data previously created by this script is removed first, so it is safe to
run multiple times as a clean reset.

=cut

use Modern::Perl;

use Koha::Script;
use Koha::Library::Group;
use Koha::Library::Groups;
use Koha::Acquisition::Finances::FiscalPeriod;
use Koha::Acquisition::Finances::FiscalPeriods;
use Koha::Acquisition::Finances::Ledger;
use Koha::Acquisition::Finances::Fund;
use Koha::Acquisition::Finances::Allocation;

my $CURRENCY = 'USD';

# Library group titles and fiscal period names used by this script —
# used both for cleanup and creation.
my @GROUP_TITLES  = ( 'Science Libraries', 'Humanities Libraries' );
my @PERIOD_NAMES  = ( 'FY2024', 'FY2025' );

# ---------------------------------------------------------------
# Helper
# ---------------------------------------------------------------
sub create_allocation {
    my ($attrs) = @_;
    return Koha::Acquisition::Finances::Allocation->new($attrs)->store();
}

# ---------------------------------------------------------------
# Cleanup: remove any data previously created by this script.
# Deleting a fiscal period cascades to its ledgers, funds, and
# their allocations (including transfer allocations, which carry
# fund_id from the source fund so they are covered by the cascade).
# ---------------------------------------------------------------
print "Cleaning up existing test data...\n";

for my $name (@PERIOD_NAMES) {
    my $existing = Koha::Acquisition::Finances::FiscalPeriods->search( { name => $name } );
    if ( $existing->count ) {
        $existing->delete;
        print "  Deleted fiscal period '$name' (cascaded ledgers, funds, allocations)\n";
    }
}

for my $title (@GROUP_TITLES) {
    my $existing = Koha::Library::Groups->search( { title => $title } );
    if ( $existing->count ) {
        $existing->delete;
        print "  Deleted library group '$title'\n";
    }
}

# ---------------------------------------------------------------
# Library groups
# ---------------------------------------------------------------
print "\nCreating library groups...\n";

for my $title (@GROUP_TITLES) {
    my $group = Koha::Library::Group->new(
        {
            title           => $title,
            ft_acquisitions => 1,
        }
    )->store();
    print "  Created: $title (id=" . $group->id . ")\n";
}

# ---------------------------------------------------------------
# Fiscal periods
# ---------------------------------------------------------------
print "\nCreating fiscal periods...\n";

my $fy2024 = Koha::Acquisition::Finances::FiscalPeriod->new(
    {
        name       => 'FY2024',
        start_date => '2024-01-01',
        end_date   => '2024-12-31',
        status     => 1,
    }
)->store( { no_cascade => 1 } );
print "  Created: FY2024 (id=" . $fy2024->fiscal_period_id . ")\n";

my $fy2025 = Koha::Acquisition::Finances::FiscalPeriod->new(
    {
        name       => 'FY2025',
        start_date => '2025-01-01',
        end_date   => '2025-12-31',
        status     => 1,
    }
)->store( { no_cascade => 1 } );
print "  Created: FY2025 (id=" . $fy2025->fiscal_period_id . ")\n";

# ---------------------------------------------------------------
# Ledger + fund definitions
# extra_allocations: additional allocations beyond the automatic initial increase
# ---------------------------------------------------------------
my @ledger_specs = (
    {
        ledger => {
            fiscal_period_id => $fy2024->fiscal_period_id,
            name             => 'Science Acquisitions FY2024',
            currency         => $CURRENCY,
            ledger_amount    => '50000.00',
            status           => 1,
            locked           => 0,
        },
        funds => [
            {
                name        => 'Books',
                code        => 'SCI-BOOKS-2024',
                fund_amount => '15000.00',
                status      => 1,
            },
            {
                name        => 'Journals',
                code        => 'SCI-JOUR-2024',
                fund_amount => '20000.00',
                status      => 1,
                sub_funds   => [
                    { name => 'Print Journals',      code => 'SCI-JOUR-PRINT-2024', fund_amount => '12000.00', status => 1 },
                    { name => 'Electronic Journals', code => 'SCI-JOUR-ELEC-2024',  fund_amount => '8000.00',  status => 1 },
                ],
            },
            {
                name              => 'Databases',
                code              => 'SCI-DB-2024',
                fund_amount       => '15000.00',
                status            => 1,
                extra_allocations => [
                    {
                        type              => 'decrease',
                        allocation_amount => '2000.00',
                        reference         => 'Budget reduction Q3',
                        note              => 'Reduced to cover journal price increases',
                    },
                ],
            },
        ],
    },
    {
        ledger => {
            fiscal_period_id => $fy2024->fiscal_period_id,
            name             => 'Humanities Acquisitions FY2024',
            currency         => $CURRENCY,
            ledger_amount    => '30000.00',
            status           => 1,
            locked           => 0,
        },
        funds => [
            {
                name        => 'Books',
                code        => 'HUM-BOOKS-2024',
                fund_amount => '15000.00',
                status      => 1,
            },
            {
                name        => 'Media',
                code        => 'HUM-MEDIA-2024',
                fund_amount => '10000.00',
                status      => 1,
                sub_funds   => [
                    { name => 'DVDs',  code => 'HUM-MEDIA-DVD-2024',   fund_amount => '6000.00', status => 1 },
                    { name => 'Audio', code => 'HUM-MEDIA-AUDIO-2024', fund_amount => '4000.00', status => 1 },
                ],
            },
            {
                name              => 'Archives',
                code              => 'HUM-ARCH-2024',
                fund_amount       => '5000.00',
                status            => 1,
                extra_allocations => [
                    {
                        type              => 'decrease',
                        allocation_amount => '1000.00',
                        reference         => 'Budget reduction Q4',
                        note              => 'Annual budget cut',
                    },
                ],
            },
        ],
    },
    {
        ledger => {
            fiscal_period_id => $fy2025->fiscal_period_id,
            name             => 'Science Acquisitions FY2025',
            currency         => $CURRENCY,
            ledger_amount    => '55000.00',
            status           => 1,
            locked           => 0,
        },
        funds => [
            {
                name        => 'Books',
                code        => 'SCI-BOOKS-2025',
                fund_amount => '16000.00',
                status      => 1,
            },
            {
                name        => 'Journals',
                code        => 'SCI-JOUR-2025',
                fund_amount => '22000.00',
                status      => 1,
                sub_funds   => [
                    { name => 'Print Journals',      code => 'SCI-JOUR-PRINT-2025', fund_amount => '13000.00', status => 1 },
                    { name => 'Electronic Journals', code => 'SCI-JOUR-ELEC-2025',  fund_amount => '9000.00',  status => 1 },
                ],
            },
            {
                name        => 'Equipment',
                code        => 'SCI-EQUIP-2025',
                fund_amount => '17000.00',
                status      => 1,
            },
        ],
    },
    {
        ledger => {
            fiscal_period_id => $fy2025->fiscal_period_id,
            name             => 'Humanities Acquisitions FY2025',
            currency         => $CURRENCY,
            ledger_amount    => '35000.00',
            status           => 1,
            locked           => 0,
        },
        funds => [
            {
                name        => 'Books',
                code        => 'HUM-BOOKS-2025',
                fund_amount => '16000.00',
                status      => 1,
            },
            {
                name        => 'Manuscripts',
                code        => 'HUM-MS-2025',
                fund_amount => '12000.00',
                status      => 1,
                sub_funds   => [
                    { name => 'Medieval', code => 'HUM-MS-MED-2025', fund_amount => '7000.00', status => 1 },
                    { name => 'Modern',   code => 'HUM-MS-MOD-2025', fund_amount => '5000.00', status => 1 },
                ],
            },
        ],
    },
);

# ---------------------------------------------------------------
# Create ledgers, funds, and their allocations
# ---------------------------------------------------------------
print "\nCreating ledgers, funds, and allocations...\n";

my %funds_by_code;

for my $spec (@ledger_specs) {
    my $ledger = Koha::Acquisition::Finances::Ledger->new( $spec->{ledger} )
        ->store( { no_cascade => 1 } );
    print "\n  Created ledger: " . $ledger->name . " (id=" . $ledger->ledger_id . ")\n";

    create_allocation(
        {
            ledger_id         => $ledger->ledger_id,
            type              => 'increase',
            allocation_amount => $spec->{ledger}{ledger_amount},
            reference         => 'Initial budget',
        }
    );
    print "    Created allocation: increase " . $spec->{ledger}{ledger_amount} . " to ledger\n";

    for my $fund_data ( @{ $spec->{funds} } ) {
        my $sub_funds         = $fund_data->{sub_funds};
        my $extra_allocations = $fund_data->{extra_allocations};
        my %fund_attrs        = %$fund_data;
        delete $fund_attrs{$_} for qw(sub_funds extra_allocations);

        my $fund = Koha::Acquisition::Finances::Fund->new(
            {
                %fund_attrs,
                ledger_id        => $ledger->ledger_id,
                fiscal_period_id => $ledger->fiscal_period_id,
            }
        )->store( { no_cascade => 1 } );
        print "    Created fund: " . $fund->name . " (id=" . $fund->fund_id . ")\n";
        $funds_by_code{ $fund_data->{code} } = $fund;

        create_allocation(
            {
                fund_id           => $fund->fund_id,
                type              => 'increase',
                allocation_amount => $fund_data->{fund_amount},
                reference         => 'Initial budget',
            }
        );
        print "      Created allocation: increase " . $fund_data->{fund_amount} . " to fund\n";

        if ($extra_allocations) {
            for my $alloc (@$extra_allocations) {
                create_allocation( { fund_id => $fund->fund_id, %$alloc } );
                print "      Created allocation: "
                    . $alloc->{type} . " "
                    . $alloc->{allocation_amount}
                    . " to fund\n";
            }
        }

        if ($sub_funds) {
            for my $sub_fund_data (@$sub_funds) {
                my $sub_fund = Koha::Acquisition::Finances::Fund->new(
                    {
                        %$sub_fund_data,
                        ledger_id        => $ledger->ledger_id,
                        fiscal_period_id => $ledger->fiscal_period_id,
                        fund_parent_id   => $fund->fund_id,
                    }
                )->store( { no_cascade => 1 } );
                print "      Created sub-fund: " . $sub_fund->name . " (id=" . $sub_fund->fund_id . ")\n";
                $funds_by_code{ $sub_fund_data->{code} } = $sub_fund;

                create_allocation(
                    {
                        fund_id           => $sub_fund->fund_id,
                        type              => 'increase',
                        allocation_amount => $sub_fund_data->{fund_amount},
                        reference         => 'Initial budget',
                    }
                );
                print "        Created allocation: increase "
                    . $sub_fund_data->{fund_amount}
                    . " to sub-fund\n";
            }
        }
    }
}

# ---------------------------------------------------------------
# Transfer allocations between funds.
# fund_id is set to the source fund so the transfer allocation is
# covered by ON DELETE CASCADE when the fund is removed.
# ---------------------------------------------------------------
print "\nCreating transfer allocations...\n";

my @transfers = (
    {
        from      => 'SCI-DB-2024',
        to        => 'SCI-JOUR-ELEC-2024',
        amount    => '2000.00',
        reference => 'Transfer to cover e-journal subscriptions',
    },
    {
        from      => 'HUM-BOOKS-2024',
        to        => 'HUM-ARCH-2024',
        amount    => '1000.00',
        reference => 'Transfer for archival acquisitions',
    },
    {
        from      => 'SCI-EQUIP-2025',
        to        => 'SCI-BOOKS-2025',
        amount    => '3000.00',
        reference => 'Equipment underspend reallocated to books',
    },
);

for my $transfer (@transfers) {
    my $from_fund = $funds_by_code{ $transfer->{from} };
    my $to_fund   = $funds_by_code{ $transfer->{to} };

    create_allocation(
        {
            fund_id             => $from_fund->fund_id,
            type                => 'transfer',
            allocation_amount   => $transfer->{amount},
            is_transferred_from => $from_fund->fund_id,
            is_transferred_to   => $to_fund->fund_id,
            reference           => $transfer->{reference},
        }
    );
    print "  Created transfer: "
        . $transfer->{amount}
        . " from " . $transfer->{from}
        . " to "   . $transfer->{to} . "\n";
}

print "\nDone.\n";
