package Koha::ERM::EUsage::UsageObject;

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

use base qw(Koha::Object);

use Koha::ERM::EUsage::YearlyUsages;
use Koha::ERM::EUsage::MonthlyUsage;
use Koha::ERM::EUsage::MonthlyUsages;

=head1 NAME

Koha::ERM::EUsage::UsageObject - Base class for ERM usage report entities

=head1 SYNOPSIS

This is the base class for the usage report entities (titles, platforms,
items and databases). Each entity has monthly usage records stored in the
erm_usage_mus table. Yearly usage is read from the erm_usage_yus view, which
sums the monthly usage per year.

Subclasses must implement C<_type>.

=head1 API

=head2 Class Methods

=head3 erm_usage_muses

Method to embed erm_usage_muses to this usage object for report formatting

=cut

sub erm_usage_muses {
    my ($self) = @_;
    my $usage_mus_rs = $self->_result->erm_usage_muses;
    return Koha::ERM::EUsage::MonthlyUsages->_new_from_dbic($usage_mus_rs);
}

=head3 erm_usage_yuses

Method to embed erm_usage_yuses to this usage object for report formatting

=cut

sub erm_usage_yuses {
    my ($self) = @_;
    my $usage_yus_rs = $self->_result->erm_usage_yuses;
    return Koha::ERM::EUsage::YearlyUsages->_new_from_dbic($usage_yus_rs);
}

=head3 yearly_usages

Getter for yearly_usages for this usage object

Yearly usage is read-only. It comes from the erm_usage_yus view, which is
computed from the monthly usage, so there is nothing to store here.

=cut

sub yearly_usages {
    my ($self) = @_;

    return $self->erm_usage_yuses;
}

=head3 monthly_usages

    my $monthly_usages = $usage_object->monthly_usages( \@monthly_usages, $job_callbacks );

Getter/setter for monthly_usages for this usage object.

A monthly usage is identified by every column except usage_count: the usage
object, the data provider, year, month, metric_type, report_type and, when the
report type has them, access_type and yop.

For each monthly usage passed in:

=over

=item * no row exists for that identity: a new row is added (C<added_mus>)

=item * a row exists with the same usage_count: nothing is done (C<skipped_mus>)

=item * a row exists with a different usage_count: it is updated (C<updated_mus>)

=item * the usage_count is 0 or missing: no row is added, and the rows that
exist for that identity are deleted (C<updated_mus>)

=back

If more than one row exists for the same identity (duplicates from earlier
harvests), the oldest row is kept and the others are deleted.

The rows of this usage object are read once per call and every change of one
call runs in one transaction, so pass all the months of a report row together.

The report_info_callback in C<$job_callbacks>, when given, is called with the
counter name shown above.

=cut

sub monthly_usages {
    my ( $self, $monthly_usages, $job_callbacks ) = @_;

    if ( $monthly_usages && @{$monthly_usages} ) {
        $self->_result->result_source->schema->txn_do(
            sub {
                my %existing;
                my @rows = $self->monthly_usages->search( {}, { order_by => 'monthly_usage_summary_id' } )->as_list;
                push @{ $existing{ _identity_key( $_->unblessed ) } }, $_ for @rows;

                for my $monthly_usage ( @{$monthly_usages} ) {
                    my $key         = _identity_key($monthly_usage);
                    my $usage_count = $monthly_usage->{usage_count} // 0;
                    my @found       = @{ $existing{$key} // [] };

                    if ( $usage_count == 0 ) {
                        next unless @found;
                        $_->delete for @found;
                        delete $existing{$key};
                        $self->_report_info( $job_callbacks, 'updated_mus' );
                        next;
                    }

                    if ( !@found ) {
                        my $added = Koha::ERM::EUsage::MonthlyUsage->new($monthly_usage)->store;
                        $existing{$key} = [$added];
                        $self->_report_info( $job_callbacks, 'added_mus' );
                        next;
                    }

                    my $kept = shift @found;

                    # Remove duplicates left behind by earlier harvests
                    $_->delete for @found;
                    $existing{$key} = [$kept];

                    if ( ( $kept->usage_count // -1 ) == $usage_count ) {
                        $self->_report_info( $job_callbacks, 'skipped_mus' );
                        next;
                    }

                    $kept->usage_count($usage_count)->store;
                    $self->_report_info( $job_callbacks, 'updated_mus' );
                }
            }
        );
    }
    my $monthly_usages_rs = $self->_result->erm_usage_muses;
    return Koha::ERM::EUsage::MonthlyUsages->_new_from_dbic($monthly_usages_rs);
}

=head2 Internal methods

=head3 _identity_key

    my $key = _identity_key( \%monthly_usage );

Returns the string that identifies a monthly usage row: every column except
usage_count, in a fixed order, with NULL and missing values as the empty
string. Takes an unblessed row or the hashref passed to monthly_usages.

=cut

my @IDENTITY_COLUMNS = qw(
    title_id platform_id database_id item_id usage_data_provider_id
    year month metric_type access_type yop report_type
);

sub _identity_key {
    my ($monthly_usage) = @_;

    return join "\0", map { $monthly_usage->{$_} // '' } @IDENTITY_COLUMNS;
}

=head3 _report_info

Calls the report_info_callback in the job callbacks, when there is one

=cut

sub _report_info {
    my ( $self, $job_callbacks, $info ) = @_;

    $job_callbacks->{report_info_callback}->($info)
        if $job_callbacks && $job_callbacks->{report_info_callback};
    return;
}

1;
