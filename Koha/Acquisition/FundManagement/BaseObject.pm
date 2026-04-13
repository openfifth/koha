package Koha::Acquisition::FundManagement::BaseObject;

# Copyright 2024 PTFS Europe

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

use Scalar::Util qw( looks_like_number );

=head1 NAME

Koha::Acquisition::FundManagement::BaseObject - Koha Object base class for the Fund Management module

=head1 SYNOPSIS

    use Koha::Acquisition::FundManagement::BaseObject;

=head1 DESCRIPTION

This class must always be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 cascade_status

This method will update the status if the parent status has changed
This only applies to a parent being set to "inactive". Activating a parent object again will not change the status of the child

=cut

sub cascade_status {
    my ( $self, $args ) = @_;

    my $parent_status   = $args->{parent_status};
    my $child           = $args->{child};
    my $change_detected = 0;

    if ( $child->status != $parent_status && $parent_status == 0 ) {
        $child->status($parent_status);
        $change_detected = 1;
    }
    return $change_detected;
}

=head3 cascade_data

=cut

sub cascade_data {
    my ( $self, $args ) = @_;

    my $properties      = $args->{properties};
    my $parent          = $args->{parent};
    my $child           = $args->{child};
    my $change_detected = 0;

    foreach my $property (@$properties) {
        if ( looks_like_number($property) ) {
            if ( $child->$property != $parent->$property ) {
                $child->$property( $parent->$property );
                $change_detected = 1;
            }
        } else {
            if ( $child->$property ne $parent->$property ) {
                $child->$property( $parent->$property );
                $change_detected = 1;
            }
        }
    }

    return $change_detected;
}

=head3 fiscal_period

Method to embed the fiscal period to a given fund

=cut

sub fiscal_period {
    my ($self) = @_;
    my $fiscal_period_rs = $self->_result->fiscal_period;
    return Koha::Acquisition::FundManagement::FiscalPeriod->_new_from_dbic($fiscal_period_rs);
}

=head3 ledger

Method to embed the ledger to a given fund

=cut

sub ledger {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledger;
    return Koha::Acquisition::FundManagement::Ledger->_new_from_dbic($ledger_rs);
}

=head3 fund

Method to embed the fund to a given sub fund

=cut

sub fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->fund;
    return Koha::Acquisition::FundManagement::Fund->_new_from_dbic($fund_rs);
}

=head3 fund_group

Method to embed the fund group to a given fund

=cut

sub fund_group {
    my ($self) = @_;
    my $fund_group_rs = $self->_result->fund_group;
    return unless $fund_group_rs;
    return Koha::Acquisition::FundManagement::FundGroup->_new_from_dbic($fund_group_rs);
}

=head3 ledgers

Method to embed ledgers to the fiscal period

=cut

sub ledgers {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledgers;
    return Koha::Acquisition::FundManagement::Ledgers->_new_from_dbic($ledger_rs);
}

=head3 funds

Method to embed funds to the fiscal period

=cut

sub funds {
    my ($self) = @_;
    my $fund_rs = $self->_result->funds;
    return Koha::Acquisition::FundManagement::Funds->_new_from_dbic($fund_rs);
}

=head3 allocations

Method to embed fund allocations to the fund

=cut

sub allocations {
    my ($self) = @_;
    my $fund_allocation_rs = $self->_result->allocations;
    return Koha::Acquisition::FundManagement::Allocations->_new_from_dbic($fund_allocation_rs);
}

=head3 owner

Method to embed the owner to a given fund

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return unless $owner_rs;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 to_api

    my $json = $av->to_api;

Overloaded method that returns a JSON representation of the object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $response = $self->SUPER::to_api($params);

    my $overrides = {};

    return { %$response, %$overrides };
}

=head3 update_amount

=cut

sub update_amount {
    my ( $self, $args ) = @_;

    my $entity            = $self->_object_hierarchy()->{object};
    my $value_change_type = $args->{type};
    my $value             = $args->{value};
    my $is_increase       = $value_change_type eq 'increase' ? 1 : 0;

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
    }
}

=head3 child_object_managing_branches

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

=cut

sub validate_child_object_amounts_against_parent_amount {
    my ( $self, $args ) = @_;

    my $parent_level        = $self->is_sub_fund ? 'fund' : 'ledger';
    my $parent_amount_field = $parent_level . "_amount";
    my $parent              = $self->parent_object;

    my $search_fields = {};
    my $search_id     = $parent_level . "_id";
    $search_fields->{$search_id} = $self->$search_id;
    my $children = Koha::Acquisition::FundManagement::Funds->search($search_fields);

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

=cut

sub parent_object {
    my ( $self, $args ) = @_;

    my $parent;
    if ( $self->is_sub_fund ) {
        $parent = Koha::Acquisition::FundManagement::Funds->find( $self->fund_parent_id );
    } else {
        $parent = Koha::Acquisition::FundManagement::Ledgers->find( $self->ledger_id );
    }
    return $parent;
}

1;
