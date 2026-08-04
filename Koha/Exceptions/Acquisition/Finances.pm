package Koha::Exceptions::Acquisition::Finances;

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

use Koha::Exception;

use Exception::Class (

    'Koha::Exceptions::Acquisition::Finances' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::Acquisition::Finances::LimitExceeded' => {
        isa         => 'Koha::Exceptions::Acquisition::Finances',
        description => 'Spend limit has been exceeded',
        fields      => [ 'data_type', 'amount' ]
    },
    'Koha::Exceptions::Acquisition::Finances::AmountBreached' => {
        isa         => 'Koha::Exceptions::Acquisition::Finances',
        description => 'A parent amount would be breached',
        fields      => ['result']
    }
);

=head1 NAME

Koha::Exceptions::Acquisition::Finances - Base class for Finances exceptions

=head1 Exceptions

=head2 Koha::Exceptions::Acquisition::Finances

Generic Nasket exception

=head2 Koha::Exceptions::Acquisition::Finances::LimitExceeded

Exception to be used when a new fund allocation will breach a spending limit

=head2 Koha::Exceptions::Acquisition::Finances::AmountBreached

Exception to be used when an amount change would breach the parent object's amount.
Carries the C<{ within_limit, breach_amount }> hashref returned by
C<validate_child_object_amounts_against_parent_amount> in C<result>, so the caller
can report the breach after the transaction has been rolled back.

=cut

1;
