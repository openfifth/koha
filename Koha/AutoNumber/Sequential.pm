package Koha::AutoNumber::Sequential;

# Copyright 2026 Open Fifth Ltd
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

=head1 NAME

Koha::AutoNumber::Sequential - simple incrementing identifier strategy

=head1 DESCRIPTION

Generates the next identifier as C<max(counter, db_max) + 1>, where
C<db_max> is the highest numeric value currently in the configured column.
This is the default strategy and reproduces the legacy C<autoMemberNum>
behaviour for patron cardnumbers.

All logic is inherited from L<Koha::AutoNumber>.  This class exists as an
explicit, named strategy so it can be referred to unambiguously in system
preferences and tests.

=cut

use Modern::Perl;
use parent 'Koha::AutoNumber';

1;
