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
use base qw(Koha::Object);

use Mojo::JSON qw(decode_json);
use JSON       qw ( encode_json );

=head1 NAME

Koha::Acquisition::OrderManagement::Orderline Object class

=head1 API

=head2 Class methods

=head3 store

=cut

sub store {
    my ($self) = @_;

    $self->set_lib_group_visibility() if $self->lib_group_visibility;
    $self = $self->SUPER::store();
    return $self;
}

# =head3 _library_group_visibility_parameters

# Configure library group limits

# =cut

# sub _library_group_visibility_parameters {
#     return {
#         class             => "Orderline",
#         visibility_column => "lib_group_visibility",
#     };
# }

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Orderline';
}

1;
