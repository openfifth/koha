#!/usr/bin/perl
#
# This file is part of Koha
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
use utf8;

use t::lib::TestBuilder;

use Koha::DateUtils qw( dt_from_string );

my $builder = t::lib::TestBuilder->new;

for ( 1 .. 1000 ) {
    my $patron =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => 'CPL', categorycode => 'P' } } );
    my $staff =
        $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => 'CPL', categorycode => 'S' } } );

    my $item = $builder->build_sample_item(
        {
            homebranch    => 'CPL',
            holdingbranch => 'CPL'
        }
    );
    my $item2 = $builder->build_sample_item(
        {
            homebranch    => 'CPL',
            holdingbranch => 'CPL'
        }
    );

    my $checkout = Koha::Checkout->new(
        {
            itemnumber     => $item->itemnumber,
            borrowernumber => $patron->borrowernumber,
            date_due       => dt_from_string()->subtract( days => 1 ),
            issuer_id      => $staff->borrowernumber,
            branchcode     => $patron->branchcode,
            issuedate      => \'NOW()',
        }
    )->store();

    my $checkout2 = Koha::Checkout->new(
        {
            itemnumber     => $item2->itemnumber,
            borrowernumber => $patron->borrowernumber,
            date_due       => dt_from_string()->subtract( days => 1 ),
            issuer_id      => $staff->borrowernumber,
            branchcode     => $patron->branchcode,
            issuedate      => \'NOW()',
        }
    )->store();

    my $overdueline = Koha::Account::Line->new(
        {
            issue_id          => $checkout->id,
            borrowernumber    => $checkout->borrowernumber,
            itemnumber        => $checkout->itemnumber,
            branchcode        => $checkout->branchcode,
            date              => \'NOW()',
            debit_type_code   => 'OVERDUE',
            status            => 'UNRETURNED',
            interface         => 'cli',
            amount            => '1',
            amountoutstanding => '1',
        }
    )->store();
    my $overdueline2 = Koha::Account::Line->new(
        {
            issue_id          => $checkout2->id,
            borrowernumber    => $checkout2->borrowernumber,
            itemnumber        => $checkout2->itemnumber,
            branchcode        => $checkout2->branchcode,
            date              => \'NOW()',
            debit_type_code   => 'OVERDUE',
            status            => 'UNRETURNED',
            interface         => 'cli',
            amount            => '1',
            amountoutstanding => '1',
        }
    )->store();
    warn $_;
}
