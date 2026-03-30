package Koha::Auth::Hostname;

# Copyright Koha Community 2026
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

use Modern::Perl;

use base qw(Koha::Object);

use C4::Context;
use Koha::Database;

=head1 NAME

Koha::Auth::Hostname - Koha Auth Hostname Object class

=head1 API

=head2 Class methods

=head3 sync_from_syspref

    Koha::Auth::Hostname->sync_from_syspref( 'OPACBaseURL', $url );

Updates (or inserts) the reserved hostname row for the given URL syspref.
C<OPACBaseURL> is always stored as C<hostname_id = 1>; C<staffClientBaseURL>
as C<hostname_id = 2>. Does nothing if C<$value> is empty or does not contain
a recognisable hostname.

=cut

my %SYSPREF_HOSTNAME_ID = (
    opacbaseurl        => 1,
    staffclientbaseurl => 2,
);

sub sync_from_syspref {
    my ( $class, $pref_name, $value ) = @_;
    $value //= '';
    my $hostname_id = $SYSPREF_HOSTNAME_ID{ lc $pref_name } or return;
    my ($hostname)  = $value =~ m{^https?://([^/:?#]+)}     or return;
    Koha::Database->new->schema->resultset('Hostname')->update_or_create(
        { hostname_id => $hostname_id, hostname => $hostname },
        { key         => 'primary' }
    );
}

=head3 sync_from_sysprefs

Ensures that the hostnames derived from OPACBaseURL and staffClientBaseURL
are present in the hostnames table. OPACBaseURL maps to C<hostname_id = 1>
and staffClientBaseURL to C<hostname_id = 2>.

=cut

sub sync_from_sysprefs {
    my ($class) = @_;
    for my $pref ( keys %SYSPREF_HOSTNAME_ID ) {
        $class->sync_from_syspref( $pref, C4::Context->preference($pref) );
    }
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Hostname';
}

1;
