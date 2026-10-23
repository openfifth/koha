package Koha::ERM::EUsage::CounterLogSummary;

# Copyright 2026 Open Fifth

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

use Modern::Perl;

use base qw(Koha::Object);

use Koha::Exception;
use Koha::ERM::EUsage::UsageDataProviders;

=head1 NAME

Koha::ERM::EUsage::CounterLogSummary - Koha ErmCounterLogSummary Object class

=head1 SYNOPSIS

This object is backed by the erm_counter_log_summary database view. It holds one row
per usage data provider, report type and harvest year, with the status of the latest
counter log for each month in C<month_1> to C<month_12>. Months with no single-month
counter log are NULL. It is read-only.

=head1 API

=head2 Class Methods

=head3 store

A counter log summary cannot be stored. Add counter logs instead.

=cut

sub store {
    Koha::Exception->throw(
        'Koha::ERM::EUsage::CounterLogSummary is read-only: erm_counter_log_summary is a view computed from erm_counter_logs'
    );
}

=head3 delete

A counter log summary cannot be deleted. Delete the counter logs instead.

=cut

sub delete {
    Koha::Exception->throw(
        'Koha::ERM::EUsage::CounterLogSummary is read-only: erm_counter_log_summary is a view computed from erm_counter_logs'
    );
}

=head3 usage_data_provider

    my $usage_data_provider = $counter_log_summary->usage_data_provider;

Returns the usage data provider of this row.

=cut

sub usage_data_provider {
    my ($self) = @_;

    return Koha::ERM::EUsage::UsageDataProvider->_new_from_dbic( $self->_result->usage_data_provider );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'ErmCounterLogSummary';
}

1;
