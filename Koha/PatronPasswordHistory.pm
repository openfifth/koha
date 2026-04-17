package Koha::PatronPasswordHistory;

# Copyright 2023
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

use Koha::Database;
use Koha::AuthUtils;
use C4::Context;
use C4::Auth;
use Koha::Patrons;

use base qw(Koha::Object);

=head1 NAME

Koha::PatronPasswordHistory - Koha PatronPasswordHistory Object class

=head1 API

=head2 Class methods

=head3 _type

Return the DBIC resultset type for this object

=cut

sub _type {

    # The table name in DB is borrower_password_history
    return 'BorrowerPasswordHistory';
}

=head3 koha_objects_class

Define relationship with the Koha::PatronPasswordHistories class

=cut

sub koha_objects_class {
    return 'Koha::PatronPasswordHistories';
}

=head3 store

Overridden store method to ensure the password is hashed before storing.
Also handles cleanup of old password history entries.

=cut

sub store {
    my ($self) = @_;

    my $borrowernumber = $self->borrowernumber;
    my $password       = $self->password;

    unless ($password) {
        return;
    }

    # Note: Don't use string comparison for password hashes - this is a common pattern
    # where we're intentionally storing the old password in history
    # The old check would fail when the patron's current hashed password was exactly
    # what we were trying to store (which is the expected case when changing passwords)

    # Hash the password if it hasn't been hashed already
    unless ( $self->in_storage ) {
        if ( $password && $password !~ /\$2a\$/ ) {
            $self->password( Koha::AuthUtils::hash_password($password) );
        }
    }

    # Store in database
    $self = $self->SUPER::store();

    # Get the history count preference
    my $history_count = C4::Context->preference('PasswordHistoryCount') || 0;

    # Clean up old history entries
    # Adjust history count to account for current password
    my $history_entries_to_keep = $history_count <= 1
        ? $history_count         # If 0 or 1, keep that many
        : $history_count - 1;    # Otherwise keep historical entries minus current

    # Clean up old entries
    Koha::PatronPasswordHistories->cleanup_old_password_history(
        $borrowernumber,
        $history_entries_to_keep
    );

    return $self;
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1;
