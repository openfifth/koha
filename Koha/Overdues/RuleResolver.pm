package Koha::Overdues::RuleResolver;

use Modern::Perl;

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

use Try::Tiny;
use Koha::Exceptions;
use Koha::CirculationRules;
use Koha::Logger;

=head1 NAME

Koha::Overdues::RuleResolver - Koha Overdues RuleResolver object set class

=head1 API

=head2 Class Methods

=cut

my @action_names = ( 'notice', 'charge', 'lost', 'restrict', 'mark_returned', 'forgive_fine' );

=head3 new

Instantiate the class.
=cut

sub new {
    my ($class) = @_;
    my $self = {
        effective_overdue_rule_sets => {},
        raw_overdue_rule_sets       => {},
    };
    return bless $self, $class;
}

=head3 set_effective_overdue_rule_sets

Sets the effective (resolved) rule sets for a given run of the circulation triggers script.

C<$context_list> is an arrayref of C<"branchcode|categorycode|itemtype"> keys: the distinct
contexts the run's overdue items present, collected in
L<Koha::Overdues::TriggerProcessor/_dispatch_overdues>. Crossing the branch, category and
itemtype lists instead would resolve every combination of the values seen, most of which no
item ever looks up.

Triggers are resolved by trigger number: a context's trigger inherits each rule it does not
set, its delay included, from the same trigger number in a less specific context. Each
resolved set is then keyed by the effective delay it fires at, which is what
L<Koha::Overdues::ActionExecutor/route_item_actions_to_queue> looks up. Where two trigger
numbers of one context resolve to the same delay, the lower trigger number is kept.

=cut

sub set_effective_overdue_rule_sets {
    my ( $self, $context_list, $effective_delay_by_raw_delay ) = @_;

    my %trigger_numbers = map { ( split /\|/ )[3] => 1 } keys %{ $self->{raw_overdue_rule_sets} };

    foreach my $context_key (@$context_list) {
        my ( $branchcode, $categorycode, $itemtype ) = split /\|/, $context_key, 3;
        my $branch_delays = $effective_delay_by_raw_delay->{$branchcode} // {};
        my $context       = { branchcode => $branchcode, categorycode => $categorycode, itemtype => $itemtype };

        foreach my $trigger_number ( sort { $a <=> $b } keys %trigger_numbers ) {
            my $raw_delay =
                $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $trigger_number, 'delay' );
            if ( !defined $raw_delay ) {
                if ( grep { $self->{raw_overdue_rule_sets}->{$_} }
                    @{ $self->_get_fallback_contexts( $branchcode, $categorycode, $itemtype, $trigger_number ) } )
                {
                    Koha::Logger->get->warn(
                        "Trigger $trigger_number for context $context_key has no delay value, own or inherited — skipping"
                    );
                }
                next;
            }

            my $effective_delay = $branch_delays->{$raw_delay};
            if ( !defined $effective_delay ) {
                next;
            }

            my $key = join( "|", $branchcode, $categorycode, $itemtype, $effective_delay );
            if ( $self->{effective_overdue_rule_sets}{$key} ) {
                Koha::Logger->get->warn(
                    "Trigger $trigger_number for context $context_key fires at the same delay as an earlier trigger — skipping"
                );
                next;
            }

            my $effective_rules = $self->_find_effective_overdue_rule_set( $context, $trigger_number, $raw_delay );

            if ( !@{ $effective_rules->{actions} } ) {
                next;
            }
            $self->{effective_overdue_rule_sets}{$key} = $effective_rules;
        }
    }

    return;
}

=head3 _find_effective_overdue_rule_set

Retrieves the effective rule set for a specific context and trigger number from the cache.

=cut

sub _find_effective_overdue_rule_set {
    my ( $self, $context, $trigger_number, $delay ) = @_;

    my $branchcode   = $context->{branchcode};
    my $categorycode = $context->{categorycode};
    my $itemtype     = $context->{itemtype};

    my $effective_rule = { delay => $delay, actions => [] };

    foreach my $action (@action_names) {
        if ( $action eq 'notice' ) {
            my $notice_code =
                $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $trigger_number, 'notice' );
            if ( !defined $notice_code ) {
                Koha::Logger->get->warn(
                    "No notice rule found for context $branchcode|$categorycode|$itemtype at delay $delay — skipping notice action"
                );
                next;
            }

            # An empty notice code suppresses the notice for this context (we already have accounted for fallbacks).
            # '' means 'No letter', and must result in notice suppression.
            if ( !length $notice_code ) {
                next;
            }
            my $mtt_value =
                $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $trigger_number, 'mtt' );
            if ( !defined $mtt_value ) {
                Koha::Logger->get->warn(
                    "No mtt rule found for notice $notice_code at delay $delay — skipping notice action");
                next;
            }

            my @mtts = grep { length } split /\s*,\s*/, $mtt_value;
            if ( !@mtts ) {
                next;
            }

            push @{ $effective_rule->{actions} }, {
                type        => 'notice',
                notice_code => $notice_code,
                mtts        => \@mtts,
            };
            next;
        }

        my $value =
            $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $trigger_number, $action );

        if ( !defined $value ) {
            next;
        }

        push @{ $effective_rule->{actions} }, {
            type  => $action,
            value => $value
        };
    }

    return $effective_rule;
}

=head3 _find_effective_rule_value

Retrieves the effective rule value for a specific context, trigger number, and action combination
from the cache. C<delay> resolves like any action.
An empty C<mtt> is skipped and the walk continues; an empty action value halts it and is returned.
If none is found, returns undef.

=cut

sub _find_effective_rule_value {
    my ( $self, $branchcode, $categorycode, $itemtype, $trigger_number, $action ) = @_;
    foreach my $key ( @{ $self->_get_fallback_contexts( $branchcode, $categorycode, $itemtype, $trigger_number ) } ) {
        my $rule_set = $self->{raw_overdue_rule_sets}->{$key};
        if ( !$rule_set ) {
            next;
        }
        my $value = $action eq 'delay' ? $rule_set->{delay} : $rule_set->{actions}->{$action};
        if ( !defined $value ) {
            next;
        }

        if ( $action eq 'mtt' && !length $value ) {
            next;
        }

        return $value;
    }
    return;
}

=head3 _get_fallback_contexts

Generates the fallback context keys for a specific context / trigger number combination. Allows to resolve effective rule sets.

=cut

sub _get_fallback_contexts {
    my ( $self, $branchcode, $categorycode, $itemtype, $trigger_number ) = @_;

    # Fallback order for contexts
    my @keys = (
        join( "|", $branchcode, $categorycode, $itemtype, $trigger_number ),    # exact match
        join( "|", $branchcode, $categorycode, "*",       $trigger_number ),    # library + category
        join( "|", $branchcode, "*",           $itemtype, $trigger_number ),    # library + itemtype
        join( "|", $branchcode, "*",           "*",       $trigger_number ),    # library only
        join( "|", "*",         $categorycode, $itemtype, $trigger_number ),    # category + itemtype
        join( "|", "*",         $categorycode, "*",       $trigger_number ),    # category only
        join( "|", "*",         "*",           $itemtype, $trigger_number ),    # itemtype only
        join( "|", "*",         "*",           "*",       $trigger_number ),    # default
    );
    return \@keys;
}

=head3 set_raw_overdue_rule_sets

# TODO: refactor, rewrite descr
Set the array of raw overdue rule sets that are relevant for the current cicrulation triggers script run.
Format: {branchcode|categorycode|itemtype|trigger_number => { delay, actions => { charge, has_rules, mark_returned, mtt, notice, restrict, lost } }}, where all properties are optional.
This reflects the reality of what is stored in the database
A trigger that sets no delay of its own is kept: it inherits one in L</set_effective_overdue_rule_sets>

=cut

sub set_raw_overdue_rule_sets {
    my ( $self, $branch_list, $category_list, $itemtype_list ) = @_;

    my $rules = $self->get_raw_overdue_rule_sets( $branch_list, $category_list, $itemtype_list );

    if ( !$rules ) {
        return;
    }

    # Temporary storage: {context}{trigger_number} = {delay => X, actions => { type => value }}
    my $temporary_rule_sets = {};

    # get all rules
    while ( my $row = $rules->next ) {
        my ( $trigger_number, $rule_type ) = $row->rule_name =~ /^overdue_(\d+)_(.+)$/ or next;
        my $context_key = join( "|", $row->branchcode // '*', $row->categorycode // '*', $row->itemtype // '*' );

        if ( $rule_type eq 'delay' ) {
            $temporary_rule_sets->{$context_key}->{$trigger_number}->{delay} = $row->rule_value;
            next;
        }

        $temporary_rule_sets->{$context_key}->{$trigger_number}->{actions}->{$rule_type} = $row->rule_value;
    }

    # format and cache all rules
    foreach my $context_key ( keys %{$temporary_rule_sets} ) {
        foreach my $trigger_number ( keys %{ $temporary_rule_sets->{$context_key} } ) {
            my $cache_key = join( "|", $context_key, $trigger_number );
            $self->{raw_overdue_rule_sets}->{$cache_key} = $temporary_rule_sets->{$context_key}->{$trigger_number};
        }
    }

    return;
}

=head3 get_raw_overdue_rule_sets

Retrieves the effective overdue rule set values for a given context

=cut

sub get_raw_overdue_rule_sets {
    my ( $self, $branch_list, $category_list, $itemtype_list ) = @_;

    my $where = {
        'me.rule_name' => { -like => 'overdue\_%' },
        -and           => [
            -or => [
                { 'me.branchcode' => undef },
                { 'me.branchcode' => { -in => $branch_list } }
            ],
            -or => [
                { 'me.categorycode' => undef },
                { 'me.categorycode' => { -in => $category_list } }
            ],
            -or => [
                { 'me.itemtype' => undef },
                { 'me.itemtype' => { -in => $itemtype_list } }
            ],
        ]
    };

    try {
        my $rs = Koha::CirculationRules->search( $where, {} );
        return $rs;
    } catch {
        Koha::Logger->get->error("Failed to get overdue rule sets: $_");
        return;
    };
}

1;
