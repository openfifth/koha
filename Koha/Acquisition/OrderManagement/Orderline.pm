package Koha::Acquisition::OrderManagement::Orderline;

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
use base qw(Koha::Object::Mixin::AdditionalFields Koha::Object);

use Koha::Acquisition::OrderManagement::OrderlineUser;

=head1 NAME

Koha::Acquisition::OrderManagement::Orderline Object class

=head1 API

=head2 Class methods

=head3 add_patrons_to_notify

=cut

sub add_patrons_to_notify {
    my ( $self, $args ) = @_;

    my $patrons_to_notify = $args->{patrons_to_notify};

    foreach my $patron (@$patrons_to_notify) {
        Koha::Acquisition::OrderManagement::OrderlineUser->new(
            {
                orderline_id   => $self->orderline_id,
                borrowernumber => $patron
            }
        )->store;
    }
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqOrderline';
}

1;
