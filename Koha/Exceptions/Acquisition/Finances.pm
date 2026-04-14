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
    }
);

=head1 NAME

Koha::Exceptions::Acquisition::Finances - Base class for Finances exceptions

=head1 Exceptions

=head2 Koha::Exceptions::Acquisition::Finances

Generic Nasket exception

=head2 Koha::Exceptions::Acquisition::Finances::LimitExceeded

Exception to be used when a new fund allocation will breach a spending limit

=cut

1;
