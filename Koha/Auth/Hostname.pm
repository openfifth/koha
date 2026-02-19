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

=head3 sync_from_sysprefs

Ensures that the hostnames derived from OPACBaseURL and staffClientBaseURL
are present in the hostnames table. Called lazily before listing hostnames
via the REST API.

=cut

sub sync_from_sysprefs {
    my ($class) = @_;
    my $schema = Koha::Database->new->schema;
    for my $pref (qw( OPACBaseURL staffClientBaseURL )) {
        my $url        = C4::Context->preference($pref)  or next;
        my ($hostname) = $url =~ m{^https?://([^/:?#]+)} or next;
        $schema->resultset('Hostname')->find_or_create( { hostname => $hostname } );
    }
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Hostname';
}

1;
