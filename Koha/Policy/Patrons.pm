package Koha::Policy::Patrons;

# Copyright 2026 Koha Development team
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

use Koha::Result::Boolean;

=head1 NAME

Koha::Policy::Patrons - module to deal with patrons policies

=head1 API

=head2 Class Methods

=head3 can_change_password

    my $can = Koha::Policy::Patrons->can_change_password( $actor, $patron );

Returns whether the I<Koha::Patron> $actor is allowed to change the password of the
I<Koha::Patron> $patron.

Anybody can change their own password (other checks, e.g. on the current password, are
not the concern of this policy). Changing the password of another account requires the
I<edit_borrowers> permission and, if that account has staff access, i.e. is in a staff
category or has any permission set (superlibrarian included), the I<staffaccess> permission
as well. Otherwise anyone who can edit patrons could take over a staff account, whatever
the category it belongs to.

Checks on the patron's library (e.g. I<IndependentBranches>) are not part of this policy.

The I<Koha::Result::Boolean> returned carries the I<edit_borrowers_required> or the
I<staffaccess_required> message when the answer is no.

=cut

sub can_change_password {
    my ( $class, $actor, $patron ) = @_;

    return Koha::Result::Boolean->new(1)
        if $actor->borrowernumber == $patron->borrowernumber;

    return Koha::Result::Boolean->new(0)->add_message( { message => 'edit_borrowers_required' } )
        unless $actor->has_permission( { borrowers => 'edit_borrowers' } );

    my $has_staff_access = $patron->category->category_type eq 'S' || $patron->flags;

    return Koha::Result::Boolean->new(1)
        unless $has_staff_access;

    return Koha::Result::Boolean->new(1)
        if $actor->has_permission( { staffaccess => 1 } );

    return Koha::Result::Boolean->new(0)->add_message( { message => 'staffaccess_required' } );
}

1;
