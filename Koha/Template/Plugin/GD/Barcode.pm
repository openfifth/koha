package Koha::Template::Plugin::GD::Barcode;

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

=head1 NAME

Koha::Template::Plugin::GD::Barcode

=head1 SYNOPSIS

    [% USE GD.Barcode %]

    <img src="[% GD.Barcode.create_as_data_url('Code39', item.barcode) | html %]">

=head1 DESCRIPTION

This Template plugin allows to create barcode image as data URL

Mostly useful in notices and slips

=cut

use Modern::Perl;

use GD::Barcode;
use MIME::Base64;

use base qw( Template::Plugin );

=head1 METHODS

=head2 new

Creates a new instance of the plugin

=cut

sub new {
    my ($class) = @_;

    my $self = {};

    return bless $self, $class;
}

=head2 create_as_data_url

Create a barcode image as a data URL

    [% GD.Barcode.create_as_data_url(type, barcode, args, plot_args) %]

C<type>, C<barcode> and C<args> are passed to C<GD::Barcode::new>

C<plot_args> is passed to C<GD::Barcode::plot>

See L<GD::Barcode/new> and L<GD::Barcode/plot>

It returns a data URL suited for use in an img src attribute

=cut

sub create_as_data_url {
    my ( $self, $type, $barcode, $args, $plot_args ) = @_;

    $args      //= {};
    $plot_args //= {};

    my $data = GD::Barcode->new( $type, $barcode, $args )->plot(%$plot_args)->png;

    return 'data:image/png;base64,' . encode_base64($data);
}

1;
