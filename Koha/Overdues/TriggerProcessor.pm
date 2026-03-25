package Koha::Overdues::TriggerProcessor;

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
use Koha::Overdues::RuleResolver;
use Koha::Overdues::ActionExecutor;
use Koha::Overdues::Repository;
use Koha::Calendar;
use Koha::Checkouts;
use Koha::DateUtils qw( dt_from_string );

=head1 NAME

Koha::Overdues::TriggerProcessor - Koha Overdue TriggerProcessor object set class

=head2 API

=head3 new

$triggerProcessor = Koha::Overdues::TriggerProcessor->new();

=cut

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

=head3 ProcessSimpleCalculationOverdues

Simple Calculation (No Closed Days)

=cut

sub ProcessSimpleCalculationOverdues {
    my ($self) = @_;
    my @known_delay_values = Koha::CirculationRules->get_known_overdue_delay_values();

    if ( !@known_delay_values ) {

        # this should not happen as it would imply the process_circulation_triggers.pl script is running despite no circulation rules being set
        return;
    }

    my $allOverduesForKnownDelays =
        Koha::Overdues::Repository->GetOverdueSummariesForKnownTriggerDelays( \@known_delay_values );

    if ( !$allOverduesForKnownDelays ) {
        return;
    }

    my %seen_branches;
    my %seen_categories;
    my %seen_itemtypes;
    my @overdue_items;

    while ( my $row = $allOverduesForKnownDelays->next ) {
        $seen_branches{ $row->get_column('branchcode') }     = 1;
        $seen_categories{ $row->get_column('categorycode') } = 1;
        $seen_itemtypes{ $row->get_column('itemtype') }      = 1;

        my $item_hashref = {
            issue_id           => $row->issue_id,
            borrowernumber     => $row->borrowernumber,
            itemnumber         => $row->itemnumber,
            branchcode         => $row->branchcode,
            date_due           => $row->date_due,
            categorycode       => $row->get_column('categorycode'),
            itemtype           => $row->get_column('itemtype'),
            days_overdue       => $row->get_column('days_overdue'),
            biblionumber       => $row->get_column('biblionumber'),
            notice_preferences => $row->get_column('notice_preferences'),
            replacementfee     => $row->get_column('replacementfee'),
            itemhomebranch     => $row->get_column('itemhomebranch'),
            itemholdingbranch  => $row->get_column('itemholdingbranch'),
            patronhomebranch   => $row->get_column('patronhomebranch'),
        };

        push @overdue_items, $item_hashref;
    }

    my @branch_list   = keys %seen_branches;
    my @category_list = keys %seen_categories;
    my @itemtype_list = keys %seen_itemtypes;

    #  fetch from the database
    my $rule_resolver = Koha::Overdues::RuleResolver->new;
    $rule_resolver->set_raw_overdue_rule_sets(
        \@branch_list, \@category_list,
        \@itemtype_list
    );

    # generate exhaustive effective set for relevant contexts
    $rule_resolver->set_effective_overdue_rule_sets(
        \@branch_list,   \@category_list,
        \@itemtype_list, \@known_delay_values
    );

    my $action_executor = Koha::Overdues::ActionExecutor->new();

    # separate notice route actions from standard route actions
    foreach my $overdue_item (@overdue_items) {
        $action_executor->route_item_actions_to_queue( $rule_resolver->{effective_overdue_rule_sets}, $overdue_item );
    }

    # TODO: enact
}

1;
