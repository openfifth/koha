package Koha::Overdues::Repository;

# Copyright Open Fifth 2025
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
use Try::Tiny;
use Koha::Checkouts;
use Koha::DateUtils qw( dt_from_string );
use Koha::Logger;

=head1 NAME

Koha::Overdues::Repository - Data access layer for the overdues trigger system.

=head1 API

=head2 Class Methods

=head3 GetOverdueSummariesForKnownTriggerDelays

my $overdues = Koha::Overdues::Repository->GetOverdueSummariesForKnownTriggerDelays( \@known_delay_values )

Fetches overdue checkouts whose date_due matches one of the known trigger delay dates.
Returns a Koha::Checkouts resultset.

=cut

sub GetOverdueSummariesForKnownTriggerDelays {
    my ( $class, $known_delay_values ) = @_;

    if ( !@$known_delay_values ) {
        return;
    }

    my %attributes = overdue_summaries_query_attributes();
    $attributes{order_by} = \'me.date_due, me.borrowernumber';

    my @dates = map { dt_from_string()->subtract( days => $_ )->strftime('%Y-%m-%d') } @$known_delay_values;

    my $where = \[
        'DATE(me.date_due) IN (' . join( ',', ('?') x @dates ) . ')',
        @dates
    ];

    try {
        return Koha::Checkouts->search( $where, \%attributes );
    } catch {
        Koha::Logger->get->error("Failed to fetch overdues for known trigger delays: $_");
        return;
    };
}

=head3 overdue_summaries_query_attributes

Returns the DBIx::Class search attributes required to fetch overdue summaries
for the circulation triggers script.

=cut

sub overdue_summaries_query_attributes {
    return (
        join => [
            'item',
            { 'patron' => 'borrower_message_preferences' },
        ],
        '+select' => [
            'item.biblionumber',
            'item.itype',
            'item.replacementprice',
            'item.homebranch',
            'item.holdingbranch',
            'patron.categorycode',
            'patron.branchcode',
            \["DATEDIFF(CURDATE(), DATE(me.date_due))"],
            'borrower_message_preferences.wants_digest',
        ],
        '+as' => [
            'biblionumber',
            'itemtype',
            'replacementfee',
            'itemhomebranch',
            'itemholdingbranch',
            'categorycode',
            'patronhomebranch',
            'days_overdue',
            'notice_preferences',
        ],
        group_by => [
            'me.borrowernumber',
            'me.issue_id',
            'me.issuer_id',
            'me.itemnumber',
            'me.booking_id',
            'me.date_due',
            'me.branchcode',
            'me.returndate',
            'me.checkin_library',
            'me.lastreneweddate',
            'me.renewals_count',
            'me.unseen_renewals',
            'me.auto_renew',
            'me.auto_renew_error',
            'me.timestamp',
            'me.issuedate',
            'me.onsite_checkout',
            'me.note',
            'me.notedate',
            'me.noteseen',
            'item.biblionumber',
            'item.itype',
            'item.replacementprice',
            'item.homebranch',
            'item.holdingbranch',
            'patron.categorycode',
            'patron.branchcode',
            \["DATEDIFF(CURDATE(), DATE(me.date_due))"],
            'borrower_message_preferences.wants_digest',
        ],
    );
}

1;
