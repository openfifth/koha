#!/usr/bin/perl

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

use Test::NoWarnings;
use Test::More tests => 3;
use Test::Exception;

use Koha::Database;
use Koha::ERM::EUsage::MonthlyUsage;
use Koha::ERM::EUsage::YearlyUsage;
use Koha::ERM::EUsage::YearlyUsages;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'erm_usage_yus view sums monthly usage per year' => sub {

    plan tests => 10;

    $schema->storage->txn_begin;

    my $title       = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageTitles' } );
    my $other_title = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageTitles' } );

    my $common = {
        title_id               => $title->title_id,
        usage_data_provider_id => $title->usage_data_provider_id,
        report_type            => 'TR_J1',
    };

    my @monthly_usages = (
        { year => 2023, month => 1, usage_count => 5,  metric_type => 'Total_Item_Requests' },
        { year => 2023, month => 2, usage_count => 7,  metric_type => 'Total_Item_Requests' },
        { year => 2023, month => 1, usage_count => 3,  metric_type => 'Unique_Item_Requests' },
        { year => 2024, month => 1, usage_count => 11, metric_type => 'Total_Item_Requests' },
    );
    Koha::ERM::EUsage::MonthlyUsage->new( { %{$common}, %{$_} } )->store for @monthly_usages;

    # A row for another title must not be summed into this title
    Koha::ERM::EUsage::MonthlyUsage->new(
        {
            title_id               => $other_title->title_id,
            usage_data_provider_id => $other_title->usage_data_provider_id,
            report_type            => 'TR_J1',
            year                   => 2023,
            month                  => 1,
            usage_count            => 100,
            metric_type            => 'Total_Item_Requests',
        }
    )->store;

    my $yearly_usages = Koha::ERM::EUsage::YearlyUsages->search(
        { title_id => $title->title_id },
        { order_by => [ 'year', 'metric_type' ] }
    );
    is( $yearly_usages->count, 3, 'One yearly row per year and metric type' );

    my ( $total_2023, $unique_2023, $total_2024 ) = $yearly_usages->as_list;

    is( $total_2023->year,        2023,                  'First row is 2023' );
    is( $total_2023->metric_type, 'Total_Item_Requests', 'First row is Total_Item_Requests' );
    is( $total_2023->totalcount,  12,                    'Two months of 2023 are summed' );
    is( $total_2023->report_type, 'TR_J1',               'report_type is carried through' );

    is( $unique_2023->totalcount, 3,    'Unique_Item_Requests is summed separately' );
    is( $total_2024->year,        2024, 'Third row is 2024' );
    is( $total_2024->totalcount,  11,   'A single month gives its own total' );

    is( $title->yearly_usages->count, 3, 'UsageObject->yearly_usages reads the view' );

    my $api = $total_2023->to_api;
    is( $api->{yearly_usage_summary_id}, $total_2023->yearly_usage_summary_id, 'View exposes a primary key' );

    $schema->storage->txn_rollback;
};

subtest 'YearlyUsage is read-only' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    throws_ok {
        Koha::ERM::EUsage::YearlyUsage->new( { year => 2023, totalcount => 1 } )->store;
    }
    'Koha::Exception', 'store throws';

    my $title = $builder->build_object( { class => 'Koha::ERM::EUsage::UsageTitles' } );
    Koha::ERM::EUsage::MonthlyUsage->new(
        {
            title_id               => $title->title_id,
            usage_data_provider_id => $title->usage_data_provider_id,
            report_type            => 'TR_J1',
            year                   => 2023,
            month                  => 1,
            usage_count            => 1,
            metric_type            => 'Total_Item_Requests',
        }
    )->store;
    my $yearly_usage = Koha::ERM::EUsage::YearlyUsages->search( { title_id => $title->title_id } )->next;

    throws_ok { $yearly_usage->delete } 'Koha::Exception', 'delete throws';

    $schema->storage->txn_rollback;
};
