package Koha::CirculationRule;

# Copyright Vaara-kirjastot 2015
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use base qw(Koha::Object);

use Koha::Cache::Memory::Lite;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::ItemTypes;

=head1 NAME

Koha::CirculationRule - Koha CirculationRule  object class

=head1 API

=head2 Class Methods

=cut

=head3 library

=cut

sub library {
    my ($self) = @_;
    my $rs = $self->_result->branchcode;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 patron_category

=cut

sub patron_category {
    my ($self) = @_;
    my $rs = $self->_result->categorycode;
    return unless $rs;
    return Koha::Patron::Category->_new_from_dbic($rs);
}

=head3 item_type

=cut

sub item_type {
    my ($self) = @_;
    my $rs = $self->_result->itemtype;
    return unless $rs;
    return Koha::ItemTypes->_new_from_dbic($rs);
}

=head3 clone

Clone a circulation rule to another branch

=cut

sub clone {
    my ( $self, $to_branch ) = @_;

    my $cloned_rule = $self->unblessed;
    $cloned_rule->{branchcode} = $to_branch;
    delete $cloned_rule->{id};
    return Koha::CirculationRule->new($cloned_rule)->store;
}

=head3 store

    $rule->store;

Stores the rule and then clears the circulation rule cache.

=cut

sub store {
    my ( $self, @params ) = @_;

    my $result = $self->SUPER::store(@params);

    $self->flush_cache;

    return $result;
}

=head3 delete

    $rule->delete;

Deletes the rule and then clears the circulation rule cache.

=cut

sub delete {
    my ( $self, @params ) = @_;

    my $result = $self->SUPER::delete(@params);

    $self->flush_cache;

    return $result;
}

=head3 flush_cache

    Koha::CirculationRule->flush_cache;

Clears every memoized circulation rule value that
L<Koha::CirculationRules/get_effective_rule_value> holds for this request.

A rule is looked up by scope (rule name, category, library, item type) rather
than by row, and one row can answer a lookup at several scopes, so there is no
way to expire only the entries that a single write affects. Clear all of them.

This lives here, on the object, so that every write goes through it. Writes
reach the table by more routes than
L<Koha::CirculationRules/set_rule>: C<clone> stores a new rule directly, and
the staff interface deletes rules through the result set. Before this, such a
write left the cache holding a value that no longer existed.

=cut

sub flush_cache {
    my $memory_cache = Koha::Cache::Memory::Lite->get_instance;

    for my $key ( $memory_cache->all_keys ) {
        $memory_cache->clear_from_cache($key) if $key =~ m{^CircRules:};
    }

    return;
}

=head3 _type

=cut

sub _type {
    return 'CirculationRule';
}

1;
