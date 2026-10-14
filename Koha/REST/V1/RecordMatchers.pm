package Koha::REST::V1::RecordMatchers;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::RecordMatchers;

use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::RecordMatchers - Koha REST API for record matching rules (V1)

=head1 API

=head2 Methods

=head3 list

Method that handles listing Koha::RecordMatcher objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $matchers = $c->objects->search( Koha::RecordMatchers->new );
        return $c->render( status => 200, openapi => $matchers );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Method that handles retrieving a single Koha::RecordMatcher object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $matcher = $c->objects->find( Koha::RecordMatchers->new, $c->param('record_matcher_id') );
        return $c->render_resource_not_found("Record matcher")
            unless $matcher;

        return $c->render( status => 200, openapi => $matcher );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
