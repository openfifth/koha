#!/usr/bin/perl

# Copyright 2026 Koha Development Team
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

edi_transport_dump.pl - dump configured EDI file transport credentials in plaintext

=head1 SYNOPSIS

  edi_transport_dump.pl

=head1 DESCRIPTION

Prints a table of every vendor EDI account, its linked file transport
(transport type, host, port, username) and the decrypted plaintext
password, for debugging EDI connection problems.

This deliberately prints secrets to the terminal. Run it only when
needed and clear your scrollback/history afterwards.

=cut

use Modern::Perl;

use Koha::Script;
use Koha::Database;
use Koha::File::Transports;

my $schema   = Koha::Database->new->schema;
my $accounts = $schema->resultset('VendorEdiAccount')->search( {}, { order_by => 'id' } );

my @headings = ( 'Account', 'Vendor', 'Transport', 'Host', 'Port', 'Username', 'Password' );
my @rows;

while ( my $account = $accounts->next ) {
    my $transport = $account->file_transport_id ? Koha::File::Transports->find( $account->file_transport_id ) : undef;

    if ($transport) {
        push @rows,
            [
            $account->id, $account->description // q{}, $transport->transport, $transport->host,
            $transport->port, $transport->user_name // q{}, $transport->plain_text_password // q{},
            ];
    } else {
        push @rows, [ $account->id, $account->description // q{}, '(none)', q{}, q{}, q{}, q{} ];
    }
}

my @widths = map { length($_) } @headings;
for my $row (@rows) {
    for my $i ( 0 .. $#$row ) {
        my $len = length( $row->[$i] );
        $widths[$i] = $len if $len > $widths[$i];
    }
}

my $format = join( '  ', map { "%-${_}s" } @widths ) . "\n";
printf $format, @headings;
printf $format, map { '-' x $_ } @widths;
printf $format, @$_ for @rows;
