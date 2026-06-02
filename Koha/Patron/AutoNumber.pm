package Koha::Patron::AutoNumber;

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

Koha::Patron::AutoNumber - patron cardnumber generation adapter

=head1 SYNOPSIS

    my $gen  = Koha::Patron::AutoNumber->new;
    my $next = $gen->next_value($schema);   # inside a transaction

=head1 DESCRIPTION

Thin adapter that instantiates L<Koha::AutoNumber> with the patron-specific
context:

=over 4

=item * C<format_pref>  => C<autoMemberNumFormat>

=item * C<counter_pref> => C<autoMemberNumValue>

=item * C<db_table>     => C<borrowers>

=item * C<db_column>    => C<cardnumber>

=back

All generation logic lives in L<Koha::AutoNumber> and its strategy subclasses.
This class exists so that the rest of Koha can call
C<< Koha::Patron::AutoNumber->new >> without knowing about the generic
framework, and so that a future C<Koha::Item::AutoNumber> can follow the same
pattern for item barcodes.

=cut

use Modern::Perl;
use Koha::AutoNumber;

=head2 Class methods

=head3 new

Returns a L<Koha::AutoNumber> strategy object configured for patron
cardnumber generation.  The active strategy is selected by the
C<autoMemberNumFormat> system preference.

=cut

sub new {
    my ($class) = @_;
    return Koha::AutoNumber->new(
        {
            format_pref  => 'autoMemberNumFormat',
            counter_pref => 'autoMemberNumValue',
            db_source    => 'Borrower',
            db_column    => 'cardnumber',
        }
    );
}

1;
