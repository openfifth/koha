package Koha::AutoNumber::EAN13;

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

=encoding UTF-8

=head1 NAME

Koha::AutoNumber::EAN13 - EAN-13 identifier generation strategy

=head1 DESCRIPTION

Generates valid 13-digit EAN-13 identifiers using the same
C<Algorithm::CheckDigits> module used by C<C4::Barcodes::EAN13> for item
barcodes.

Overrides two hooks from L<Koha::AutoNumber>:

=over 4

=item * C<db_max> — only considers exactly 13-digit numeric values in the
configured column, so shorter legacy identifiers cannot inflate the EAN-13
sequence.

=item * C<_next_from($prev)> — strips the check digit from the previous
value to recover the 12-digit base, increments it, zero-pads to 12 digits,
and recomputes the check digit.

=back

No additional system preferences are required.  Libraries configure their
starting number by setting the counter preference (e.g. C<autoMemberNumValue>)
to their first valid EAN-13 barcode (their institutional or GS1 prefix with a
zero sequential part and the correct check digit).

=head2 Note on prefix selection

EAN-13 barcodes on physical library cards should ideally use a GS1 company
prefix assigned to the library or consortium for global uniqueness.  Koha
does not enforce this — any valid 13-digit EAN-13 value is accepted.

=cut

use Modern::Perl;
use parent 'Koha::AutoNumber';

use Algorithm::CheckDigits qw( CheckDigits );

my $ean = CheckDigits('ean');

=head2 Methods

=head3 db_max

Returns the highest 13-digit numeric value in the configured column.
Values that are not exactly 13 digits are excluded so shorter legacy
identifiers cannot inflate the EAN-13 sequence.

Because all EAN-13 values share the same 13-digit length, lexicographic
C<MAX()> is equivalent to numeric C<MAX()>, so no C<CAST> is required.

=cut

sub db_max {
    my ( $self,   $schema ) = @_;
    my ( $source, $column ) = @{$self}{qw(db_source db_column)};
    return $schema->resultset($source)->search( { $column => { -regexp => '^[0-9]{13}$' } } )->get_column($column)->max
        // 0;
}

=head3 _next_from

Strips the EAN-13 check digit from C<$prev>, increments the 12-digit base,
zero-pads to 12 digits, and recomputes the check digit via
C<Algorithm::CheckDigits>.

=cut

sub _next_from {
    my ( $self, $prev ) = @_;
    my $base = int( $prev / 10 ) + 1;
    return $ean->complete( sprintf( '%012d', $base ) );
}

1;
