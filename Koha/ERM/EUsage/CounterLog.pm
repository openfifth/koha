package Koha::ERM::EUsage::CounterLog;

# Copyright 2023 PTFS Europe

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

use JSON      qw( decode_json );
use Try::Tiny qw( catch try );

use Koha::BackgroundJob;
use Koha::Database;
use Koha::ERM::EUsage::CounterLogSummaries;
use Koha::Patron;

use base qw(Koha::Object);

my @SUMMARY_KEY_COLUMNS = qw( usage_data_provider_id report_type report_year );

=head1 NAME

Koha::ERM::EUsage::CounterLog - Koha ErmCounterLog Object class

=head1 API

=head2 Class Methods

=cut

=head3 sushi_code_status

    my $status = Koha::ERM::EUsage::CounterLog->sushi_code_status(3031);

Maps a COUNTER SUSHI exception code to the counter log status it implies:

=over

=item C<retry>: 1000 Service Not Available, 1010 Service Busy, 1011 Report Queued,
1020 Too Many Requests, 3031 Usage Not Ready, 3040 Partial Data Returned.

=item C<no_usage>: 3030 No Usage Available.

=item C<no_data>: 3032 Usage No Longer Available.

=item C<error>: every other code of 1000 and above (authorization, unsupported
report, invalid request).

=item C<info>: the request parameter warnings 3050 Parameter Not Recognized,
3060 Invalid ReportFilter Value, 3061 Incongruous ReportFilter Value and 3062
Invalid ReportAttribute Value (the report is complete), codes below 1000, an undefined code, or a code that is not numeric.

=back

Docs v5: https://cop5.projectcounter.org/en/5.0.2/appendices/f-handling-errors-and-exceptions.html
Docs v5.1: https://cop5.countermetrics.org/en/5.1/appendices/d-handling-errors-and-exceptions.html

=cut

my %SUSHI_CODE_STATUS = (
    1000 => 'retry',
    1010 => 'retry',
    1011 => 'retry',
    1020 => 'retry',
    3030 => 'no_usage',
    3031 => 'retry',
    3032 => 'no_data',
    3040 => 'retry',
    3050 => 'info',
    3060 => 'info',
    3061 => 'info',
    3062 => 'info',
);

sub sushi_code_status {
    my ( $class, $code ) = @_;

    return 'info' unless defined $code && $code =~ /^\d+$/;
    return $SUSHI_CODE_STATUS{$code} if exists $SUSHI_CODE_STATUS{$code};
    return $code >= 1000 ? 'error' : 'info';
}

=head3 decoded_logdetails

    my $details = $counter_log->decoded_logdetails;

Returns the C<logdetails> column decoded from JSON as a hashref. Returns an empty
hashref when the column is empty or does not hold valid JSON.

=cut

sub decoded_logdetails {
    my ($self) = @_;

    my $logdetails = $self->logdetails;
    return {} unless defined $logdetails && length $logdetails;

    my $decoded = try { decode_json($logdetails) } catch { undef };
    return ref($decoded) eq 'HASH' ? $decoded : {};
}

=head3 background_job

    my $job = $counter_log->background_job;

Returns the C<Koha::BackgroundJob> that created this counter log, or undef.

=cut

sub background_job {
    my ($self) = @_;

    my $job_rs = $self->_result->background_job;
    return unless $job_rs;
    return Koha::BackgroundJob->_new_from_dbic($job_rs);
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::ERM::EUsage::CounterLog
on the API.

=cut

sub to_api_mapping {
    return {
        borrowernumber => 'patron_id',
    };
}

=head3 store

    $counter_log->store;

Stores the counter log, then rebuilds the row of the counter log summary of its usage
data provider, report type and year. When the key of a stored counter log changes,
the row of the old key is rebuilt too. See
L<Koha::ERM::EUsage::CounterLogSummaries/rebuild>.

=cut

sub store {
    my ($self) = @_;

    # A counter log that moves to another provider, report type or year leaves a summary behind
    my $old_key;
    if ( $self->in_storage ) {
        my %dirty = $self->_result->get_dirty_columns;
        if ( grep { exists $dirty{$_} } @SUMMARY_KEY_COLUMNS ) {
            my $stored = Koha::Database->new->schema->resultset('ErmCounterLog')->find( $self->erm_counter_log_id );
            $old_key = { map { $_ => $stored->get_column($_) } @SUMMARY_KEY_COLUMNS } if $stored;
        }
    }

    $self->SUPER::store;
    $self->_rebuild_summaries( $self->_summary_key, $old_key );

    return $self;
}

=head3 delete

    $counter_log->delete;

Deletes the counter log, then rebuilds the row of the counter log summary of its usage
data provider, report type and year.

=cut

sub delete {
    my ($self) = @_;

    my $key = $self->_summary_key;

    my $result = $self->SUPER::delete;
    $self->_rebuild_summaries($key);

    return $result;
}

=head3 patron

Return the patron for this counter_file

=cut

sub patron {
    my ($self) = @_;
    my $patrons_rs = $self->_result->patron;
    return unless $patrons_rs;
    return Koha::Patron->_new_from_dbic($patrons_rs);
}

=head2 Internal methods

=head3 _summary_key

    my $key = $self->_summary_key;

Returns the usage data provider, report type and year of the counter log as a hashref,
or undef when one of them is missing: such a counter log is not summarised.

=cut

sub _summary_key {
    my ($self) = @_;

    my $key = { map { $_ => $self->$_ } @SUMMARY_KEY_COLUMNS };
    return ( grep { !defined $key->{$_} } @SUMMARY_KEY_COLUMNS ) ? undef : $key;
}

=head3 _rebuild_summaries

    $self->_rebuild_summaries( @keys );

Rebuilds the counter log summary row of each key. Keys that are undef, incomplete or repeated are skipped.

=cut

sub _rebuild_summaries {
    my ( $self, @keys ) = @_;

    my %seen;
    for my $key (@keys) {
        next unless $key && !grep { !defined $key->{$_} } @SUMMARY_KEY_COLUMNS;
        next if $seen{ join "\0", @{$key}{@SUMMARY_KEY_COLUMNS} }++;
        Koha::ERM::EUsage::CounterLogSummaries->rebuild($key);
    }
}

=head3 _type

=cut

sub _type {
    return 'ErmCounterLog';
}

1;
