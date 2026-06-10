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

Sets the array or effective (resolved) rule sets for a given run of the circulation triggers script.

=cut

sub set_effective_overdue_rule_sets {
    my ( $self, $branch_list, $category_list, $itemtype_list, $effective_delay_by_raw_delay ) = @_;

    foreach my $branchcode (@$branch_list) {
        my $branch_delays = $effective_delay_by_raw_delay->{$branchcode} // {};
        foreach my $categorycode (@$category_list) {
            foreach my $itemtype (@$itemtype_list) {
                foreach my $raw_delay ( keys %$branch_delays ) {
                    my $effective_delay = $branch_delays->{$raw_delay};

                    # create the rule set
                    my $key     = join( "|", $branchcode, $categorycode, $itemtype, $effective_delay );
                    my $context = { branchcode => $branchcode, categorycode => $categorycode, itemtype => $itemtype };
                    my $effective_rules = $self->_find_effective_overdue_rule_set( $context, $raw_delay );

                    if ( !@{ $effective_rules->{actions} } ) {
                        next;
                    }
                    $self->{effective_overdue_rule_sets}{$key} = $effective_rules;
                }
            }
        }
    }
}

=head3 _find_effective_rule_value

Retrieves the effective rule sets value for a specific context, and delay combination from the cache.

=cut

sub _find_effective_overdue_rule_set {
    my ( $self, $context, $delay ) = @_;

    my $branchcode   = $context->{branchcode};
    my $categorycode = $context->{categorycode};
    my $itemtype     = $context->{itemtype};

    my $effective_rule = { delay => $delay, actions => [] };

    foreach my $action (@action_names) {
        if ( $action eq 'notice' ) {
            my $notice_code =
                $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $delay, 'notice' );
            if ( !defined $notice_code ) {
                Koha::Logger->get->warn(
                    "No notice rule found for context $branchcode|$categorycode|$itemtype at delay $delay — skipping notice action"
                );
                next;
            }
            my $mtt_value = $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $delay, 'mtt' );
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

        my $value = $self->_find_effective_rule_value( $branchcode, $categorycode, $itemtype, $delay, $action );

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

Retrieves the effective rule value for a specific context, delay, and action combination from the cache.
If none is found, returns an empty scalar.

=cut

sub _find_effective_rule_value {
    my ( $self, $branchcode, $categorycode, $itemtype, $delay, $action ) = @_;
    foreach my $key ( @{ $self->_get_fallback_contexts( $branchcode, $categorycode, $itemtype, $delay ) } ) {
        if ( !$self->{raw_overdue_rule_sets}->{$key} ) {
            next;
        }
        if ( !defined $self->{raw_overdue_rule_sets}->{$key}->{actions}->{$action} ) {
            next;
        }
        my $value = $self->{raw_overdue_rule_sets}->{$key}->{actions}->{$action};
        return $value;
    }
}

=head3 _get_fallback_contexts

Generates the fallback context keys for a specific context / delay combination. Allows to resolve effective rule sets.

=cut

sub _get_fallback_contexts {
    my ( $self, $branchcode, $categorycode, $itemtype, $delay ) = @_;

    # Fallback order for contexts
    my @keys = (
        join( "|", $branchcode, $categorycode, $itemtype, $delay ),    # exact match
        join( "|", $branchcode, $categorycode, "*",       $delay ),    # library + category
        join( "|", $branchcode, "*",           $itemtype, $delay ),    # library + itemtype
        join( "|", $branchcode, "*",           "*",       $delay ),    # library only
        join( "|", "*",         $categorycode, "*",       $delay ),    # category only
        join( "|", "*",         "*",           $itemtype, $delay ),    # itemtype only
        join( "|", "*",         "*",           "*",       $delay ),    # default
    );
    return \@keys;
}

=head3 set_raw_overdue_rule_sets

# TODO: refactor, rewrite descr
Set the array of raw overdue rule sets that are relevant for the current cicrulation triggers script run.
Format: {branchcode|categorycode|itemtype|delay => { charge, has_rules, mark_returned, mtt, notice, restrict, lost}}, where all properties are optional.
This reflects the reality of what is stored in the database 
It also ties the actions to the delay explicitly assigned to this set

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
            my $rule_set = $temporary_rule_sets->{$context_key}->{$trigger_number};
            my $delay    = $rule_set->{delay};
            if ( !defined $delay ) {
                Koha::Logger->get->warn(
                    "Trigger $trigger_number for context $context_key has no delay value — skipping");
                next;
            }
            my $cache_key = join( "|", $context_key, $delay );
            $self->{raw_overdue_rule_sets}->{$cache_key} = $rule_set;
        }
    }
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
