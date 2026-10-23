package Koha::REST::V1::ERM::EUsage::CounterLogSummaries;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::ERM::EUsage::CounterLogSummaries;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing Koha::ERM::EUsage::CounterLogSummary objects:
one row per usage data provider, report type and harvest year with the latest harvest
status of each month.

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $summaries_set = Koha::ERM::EUsage::CounterLogSummaries->new;
        my $summaries     = $c->objects->search($summaries_set);
        return $c->render( status => 200, openapi => $summaries );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
