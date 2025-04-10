package Koha::PatronPasswordHistories;

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Koha::Database;
use Koha::PatronPasswordHistory;
use C4::Context;
use Koha::AuthUtils;

use base qw(Koha::Objects);

=head1 NAME

Koha::PatronPasswordHistories - Koha PatronPasswordHistory Object set class

=head1 API

=head2 Class Methods

=head3 cleanup_old_password_history

    Koha::PatronPasswordHistories->cleanup_old_password_history($borrowernumber, $count);

Clean up old password history for a patron, keeping only the specified number of most recent entries.
If count is 0 or negative, all password history for the patron will be deleted.

=cut

sub cleanup_old_password_history {
    my ($class, $borrowernumber, $count) = @_;
    
    return unless $borrowernumber;
    
    # If count is 0 or negative, delete all entries
    if ($count <= 0) {
        my $deleted = $class->search({
            borrowernumber => $borrowernumber
        })->delete;
        return $deleted;
    }
    
    # Get IDs of entries to keep (the most recent ones)
    my @keep_ids = $class->search(
        { borrowernumber => $borrowernumber },
        { 
            order_by => { -desc => 'created_on' },
            rows => $count,
            columns => ['id']
        }
    )->get_column('id');
    
    # Delete all entries for this borrower except the ones we're keeping
    my $deleted = 0;
    if (@keep_ids) {
        $deleted = $class->search({
            borrowernumber => $borrowernumber,
            id => { -not_in => \@keep_ids }
        })->delete;
    }
    
    return $deleted;
}

=head3 _type

Return the DBIC resultset type for this class

=cut

sub _type {
    # The table name in DB is borrower_password_history
    return 'BorrowerPasswordHistory';
}

=head3 object_class

Return the object class for items in this collection

=cut

sub object_class {
    return 'Koha::PatronPasswordHistory';
}

=head3 has_used_password

    my $bool = Koha::PatronPasswordHistories->has_used_password({
        borrowernumber => $borrowernumber,
        password => $plain_text_password,
        current_password => $hashed_current_password # Optional
    });

Check if the given password exists in the password history for this patron.
If current_password is provided, it will also check against that.
Returns true if the password has been used before, false otherwise.

=cut

sub has_used_password {
    my ($class, $params) = @_;
    
    my $borrowernumber = $params->{borrowernumber};
    my $password = $params->{password};
    my $current_password = $params->{current_password};
    
    unless ($borrowernumber && $password) {
        return 0;
    }
    
    my $history_count = C4::Context->preference('PasswordHistoryCount') || 0;
    
    # If history count is 0, don't check history at all
    if ($history_count == 0) {
        return 0;
    }
    
    # If history count is 1, only check current password
    if ($history_count == 1) {
        my $matches_current = $current_password && C4::Auth::checkpw_hash($password, $current_password);
        return $matches_current ? 1 : 0;
    }
    
    # First check if password matches current one, if provided
    if ($current_password && C4::Auth::checkpw_hash($password, $current_password)) {
        return 1; # Current password counts as a used password
    }
    
    # Adjust history count to account for current password
    my $history_entries_to_check = $current_password ? $history_count - 1 : $history_count;
    
    return 0 if $history_entries_to_check <= 0; # No need to check history if only checking current
    
    # Get the most recent password history entries
    my $password_history = $class->search(
        { borrowernumber => $borrowernumber },
        { 
            order_by => { -desc => 'created_on' },
            rows => $history_entries_to_check
        }
    );
    
    # Check each password history entry
    while (my $history_entry = $password_history->next) {
        # Use checkpw_hash to properly compare the plaintext password with stored hash
        my $matches = C4::Auth::checkpw_hash($password, $history_entry->password);
        if ($matches) {
            return 1; # Password found in history
        }
    }
    
    return 0; # Password not found in history
}

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1; 