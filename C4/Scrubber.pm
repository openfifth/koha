package C4::Scrubber;

# Copyright Liblime 2008
# Parts copyright sys-tech.net 2011
# Copyright PTFS Europe 2011
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

use strict;
use warnings;
use Carp qw( croak carp );
use HTML::Scrubber;
use File::Basename qw( fileparse );
use Try::Tiny qw( try catch );
use YAML::XS;

use C4::Context;
use Koha::Config;

my %scrubbertypes = (
    default        => {},    # place holder, default settings are below as fallbacks in call to constructor
    comment        => { allow => [qw( br b i em big small strong )], },
    note           => { allow => [qw[ br b i em big small strong u hr span div p ol ul li dl dt dd ]] },
    record_display => {
        allow => [
            qw(
                div span h1 h2 h3 h4 h5 h6 p br
                ul ol li dl dt dd
                a img
                strong b em i u s strike del ins sup sub
                blockquote cite q abbr acronym dfn
                table thead tbody tfoot tr td th caption
                pre code kbd samp var
                hr
                address
            )
        ],
        rules => [
            div => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            span => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            p => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            a => {
                href   => qr{^(?:https?://|/cgi-bin/|mailto:|#)}i,
                class  => qr/^[\w\s\-_]+$/,
                title  => 1,
                target => qr/^_(?:blank|self|parent|top)$/,
            },

            ul => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            ol => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            li => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            i => {
                class        => qr/^[\w\s\-_]+$/,
                'aria-label' => 1,
            },
        ],
    },
    opac_virtual_card => {
        allow => [
            qw(
                div span h1 h2 h3 h4 h5 h6 p br
                ul ol li dl dt dd
                a img svg
                strong b em i u
                hr
            )
        ],
        rules => [
            div => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },

            span => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },
            p => {
                class => qr/^[\w\s\-_]+$/,
                id    => qr/^[\w\-_]+$/,
            },
            'svg' => {
                'id'                  => qr/^[\w\-_]+$/,
                'class'               => qr/^[\w\s\-_]+$/,
                'data-barcode'        => qr/^[\w\-_]+$/,
                'data-barcode-format' => qr/^[\w\-_]+$/,
            },
            'img' => {
                'src'   => qr/^(?:https?:\/\/|\/)/i,
                'alt'   => 1,
                'class' => qr/^[\w\s\-_]+$/,
                'id'    => qr/^[\w\-_]+$/,
            },
        ],
    }
);

override_default_settings(
    {
        settings => \%scrubbertypes,
    }
);

=head1 NAME

C4::Scrubber

=head1 API

=head2 Functions

=cut

=head3 override_default_settings


=cut

sub override_default_settings {
    my ($args) = @_;
    my $settings = $args->{settings};
    if ($settings) {
        my ( $koha_conf_filename, $config_dir ) = fileparse( Koha::Config->guess_koha_conf );
        my $filename = sprintf( "%s/html_scrubber.yaml", $config_dir );
        if ( $filename && -f $filename ) {
            try {
                my $override_settings = YAML::XS::LoadFile($filename);
                if ( $override_settings && ref $override_settings && ref $override_settings eq 'HASH' ) {
                    foreach my $type ( keys %$override_settings ) {
                        $settings->{$type} = $override_settings->{$type};
                    }
                }
            } catch {
                carp "Could not load html_scrubber.yaml overrides from '$filename', falling back to built-in defaults: $_";
            };
        }
    }
    return $settings;
}

=head3 new

=cut

sub new {
    shift;    # ignore our class we are wrapper
    my $type = (@_) ? shift : 'default';
    $type = 'default' if !defined $type;
    if ( !exists $scrubbertypes{$type} ) {
        croak "New called with unrecognized type '$type'";
    }
    my $settings = $scrubbertypes{$type};
    my $scrubber = HTML::Scrubber->new(
        allow   => exists $settings->{allow}   ? $settings->{allow}   : [],
        rules   => exists $settings->{rules}   ? $settings->{rules}   : [],
        default => exists $settings->{default} ? $settings->{default} : [ 0 => { '*' => 0 } ],
        comment => exists $settings->{comment} ? $settings->{comment} : 0,
        process => 0,
    );
    return $scrubber;
}

1;
__END__

=head1 C4::Sanitize

Standardized wrapper with settings for building HTML::Scrubber tailored to various koha inputs.

The default is to scrub everything, leaving no markup at all.  This is compatible with the expectations
for Tags.

=head1 Functions

=head2 new

Missing POD for new.

=cut
