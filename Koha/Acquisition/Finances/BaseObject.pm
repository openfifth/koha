package Koha::Acquisition::Finances::BaseObject;

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use base qw(Koha::Object);

=head1 NAME

Koha::Acquisition::Finances::BaseObject - Koha Object base class for the Finances module

=head1 SYNOPSIS

    use Koha::Acquisition::Finances::BaseObject;

=head1 DESCRIPTION

This class must always be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 cascade_status

    $obj->cascade_status({ parent_status => $bool, child => $child_obj });

Updates C<$child>'s status to match C<parent_status> if they differ.
Returns 1 if a change was made, 0 otherwise.

=cut

sub cascade_status {
    my ( $self, $args ) = @_;

    my $parent_status   = $args->{parent_status};
    my $child           = $args->{child};
    my $change_detected = 0;

    if ( $child->status != $parent_status ) {
        $child->status($parent_status);
        $change_detected = 1;
    }
    return $change_detected;
}

=head3 fiscal_period

Returns the C<Koha::Acquisition::Finances::FiscalPeriod> associated with this object.

=cut

sub fiscal_period {
    my ($self) = @_;
    my $fiscal_period_rs = $self->_result->fiscal_period;
    return Koha::Acquisition::Finances::FiscalPeriod->_new_from_dbic($fiscal_period_rs);
}

=head3 ledger

Returns the C<Koha::Acquisition::Finances::Ledger> associated with this object.

=cut

sub ledger {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledger;
    return Koha::Acquisition::Finances::Ledger->_new_from_dbic($ledger_rs);
}

=head3 fund

Returns the C<Koha::Acquisition::Finances::Fund> associated with this object.

=cut

sub fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->fund;
    return Koha::Acquisition::Finances::Fund->_new_from_dbic($fund_rs);
}

=head3 ledgers

Returns a C<Koha::Acquisition::Finances::Ledgers> result set for all ledgers attached to this object.

=cut

sub ledgers {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledgers;
    return Koha::Acquisition::Finances::Ledgers->_new_from_dbic($ledger_rs);
}

=head3 funds

Returns a C<Koha::Acquisition::Finances::Funds> result set for all funds attached to this object.

=cut

sub funds {
    my ($self) = @_;
    my $fund_rs = $self->_result->funds;
    return Koha::Acquisition::Finances::Funds->_new_from_dbic($fund_rs);
}

=head3 allocations

Returns a C<Koha::Acquisition::Finances::Allocations> result set for all allocations attached to this object.

=cut

sub allocations {
    my ($self) = @_;
    my $fund_allocation_rs = $self->_result->allocations;
    return Koha::Acquisition::Finances::Allocations->_new_from_dbic($fund_allocation_rs);
}

=head3 owner

Returns the C<Koha::Patron> who owns this object, or C<undef> if no owner is set.

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return unless $owner_rs;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 to_api

    my $json = $obj->to_api;
    my $json = $obj->to_api({ embed => { ... } });

Overloaded method returning a hashref representation of the object suitable for API output.
Delegates to C<Koha::Object::to_api> and applies finance-specific overrides.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $response = $self->SUPER::to_api($params);

    my $overrides = {};

    return { %$response, %$overrides };
}

=head3 update_amount

    my $result = $obj->update_amount({ type => 'INCREASE', value => 50.00 });

Adjusts the entity amount field (e.g. C<fund_amount> or C<ledger_amount>) by C<value>.

For increases, validates the new total against the parent object's budget via
C<validate_child_object_amounts_against_parent_amount> (skipped for ledgers, which have no
ceiling). Returns the validation hashref C<{ within_limit => 1|0, breach_amount => $n }>
on increase, or C<undef> on decrease.

Accepted C<type> values: C<INCREASE>, C<DECREASE>.

=cut

sub update_amount {
    my ( $self, $args ) = @_;

    my $entity            = $self->_object_hierarchy()->{object};
    my $value_change_type = $args->{type};
    my $value             = $args->{value};
    my $is_increase       = $value_change_type eq 'INCREASE' ? 1 : 0;

    my $entity_field = $entity . "_amount";

    my $new_value = $is_increase ? $self->$entity_field + $value : $self->$entity_field - $value;
    if ($is_increase) {
        my $result =
              $entity ne 'ledger'
            ? $self->validate_child_object_amounts_against_parent_amount( { new_allocation => $value } )
            : { within_limit => 1 };
        if ( $result->{within_limit} ) {
            $self->$entity_field($new_value)->store;
            return $result;
        } else {
            return $result;
        }
    } else {
        $self->$entity_field($new_value)->store;
        return;
    }
}

=head3 child_object_managing_branches

    my $branches = $obj->child_object_managing_branches;
    my $branches = $obj->child_object_managing_branches({ managing_branches => \@existing });

Recursively collects C<{ branchcode, branchname }> pairs for every managing library set on
direct and indirect child objects (funds E<rarr> sub-funds, ledgers E<rarr> funds, etc.).

Returns an arrayref of unique branch hashrefs; duplicates on C<branchcode> are suppressed.

=cut

sub child_object_managing_branches {
    my ( $self, $args ) = @_;

    my $children_class = $self->_object_hierarchy()->{children};
    my $children       = $self->$children_class->as_list;

    my $managing_branches = $args->{managing_branches} || [];
    foreach my $child (@$children) {
        my $managing_library = $child->managing_library;
        if ($managing_library) {
            my $branch = {
                branchcode => $child->managing_branch,
                branchname => $managing_library->branchname
            };
            push( @$managing_branches, $branch )
                unless grep( $_->{branchcode} eq $branch->{branchcode}, @$managing_branches );
        }
        $managing_branches = $child->child_object_managing_branches( { managing_branches => $managing_branches } );
    }
    return $managing_branches;
}

=head3 validate_child_object_amounts_against_parent_amount

    my $result = $obj->validate_child_object_amounts_against_parent_amount;
    my $result = $obj->validate_child_object_amounts_against_parent_amount({ new_allocation => 100 });

Checks whether the sum of all sibling fund amounts (plus an optional C<new_allocation>)
fits within the parent object's allocated amount.

Returns a hashref:

    {
        within_limit  => 1|0,  # 1 if the total is within budget
        breach_amount => $n,   # how much over budget (0 if within limit)
    }

=cut

sub validate_child_object_amounts_against_parent_amount {
    my ( $self, $args ) = @_;

    my $parent_level        = $self->is_sub_fund ? 'fund' : 'ledger';
    my $parent_amount_field = $parent_level . "_amount";
    my $parent              = $self->parent_object;

    my $search_fields =
        $parent_level eq 'ledger'
        ? { ledger_id      => $self->ledger_id, parent_fund_id => undef }
        : { parent_fund_id => $self->parent_fund_id };
    my $children = Koha::Acquisition::Finances::Funds->search($search_fields);

    my $children_value;
    foreach my $child ( @{ $children->as_list } ) {
        $children_value += $child->fund_amount;
    }
    my $new_allocation = defined $args->{new_allocation} ? $args->{new_allocation} : $self->fund_amount;
    $children_value += $new_allocation;
    my $parent_value = $parent->$parent_amount_field;

    return {
        within_limit  => $children_value <= $parent_value ? 1 : 0,
        breach_amount => $children_value - $parent_value
    };
}

=head3 parent_object

Returns the parent object: a C<Koha::Acquisition::Finances::Fund> if this is a sub-fund
(C<parent_fund_id> is set), or a C<Koha::Acquisition::Finances::Ledger> otherwise.

=cut

sub parent_object {
    my ( $self, $args ) = @_;

    my $parent;
    if ( $self->is_sub_fund ) {
        $parent = Koha::Acquisition::Finances::Funds->find( $self->parent_fund_id );
    } else {
        $parent = Koha::Acquisition::Finances::Ledgers->find( $self->ledger_id );
    }
    return $parent;
}

1;
