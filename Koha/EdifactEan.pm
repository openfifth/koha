package Koha::EdifactEan;

# Copyright 2025 PTFS Europe

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

use Koha::Library;

use base qw( Koha::Object );

=head1 NAME

Koha::EdifactEan - Koha Library EAN Account Object class

=head1 API

=head2 Class Methods

=cut

=head3 library

=cut

sub library {
    my ($self) = @_;
    my $rs = $self->_result->branch;
    return unless $rs;
    return Koha::Library->_new_from_dbic($rs);
}

=head3 to_api_mapping

=cut

sub to_api_mapping {
    return { ee_id => 'edi_ean_account_id' };
}

=head3 _type

=cut

sub _type {
    return 'EdifactEan';
}

1;
