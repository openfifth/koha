package Koha::Completion::BorrowerCompletion;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use strict;
use DateTime;
use C4::Context;
use Koha::Logger;
use Data::Dumper;

sub new {
    my ( $class, $params ) = @_;

    my $self = {};

    my $config = C4::Context->config('borrower_completion');

    $self->{config} = $config;

    return
        bless $self,
        $class;
}

sub normalize_pnr {
    my $self = shift;
    my $pnr  = shift;

    if ( $pnr =~ /^(\d{2}|\d{4})(\d{2})(\d{2})(?:[-+]?)(\d{4})$/ ) {
        my $y = int($1);
        my $m = int($2);
        my $d = int($3);
        my $n = int($4);

        if ( $y < 100 ) {
            my $cy = DateTime->now->year % 100;
            if ( $y < $cy ) {
                $y += 2000;
            } else {
                $y += 1900;
            }
        }

        return (
            sprintf( '%04d%02d%02d-%04d', $y, $m, $d, $n ), sprintf( '%04d%02d%02d%04d', $y, $m, $d, $n ),
            sprintf( '%04d-%02d-%02d',    $y, $m, $d )
        );
    }
    return undef;
}

sub name_capitalization {
    my $self = shift;
    my $name = shift;

    my $s     = '';
    my $first = 1;

    while ( length($name) > 0 ) {
        my $c = substr( $name, 0, 1 );
        $name = substr( $name, 1 );
        if ( !( $c =~ /^\p{XPosixAlpha}+$/ ) ) {
            $first = 1;
            $s .= $c;
        } elsif ($first) {
            $first = 0;
            $s .= uc($c);
        } else {
            $s .= lc($c);
        }
    }

    return $s;
}

sub ssl_opts {
    my $self = shift;

    my $ssl_opts = {
        SSL_cert_file => $self->{config}->{SSL_cert_file},
        SSL_use_cert  => 1
    };

    if ( defined $self->{config}->{SSL_key_file} ) {
        $ssl_opts->{SSL_key_file} = $self->{config}->{SSL_key_file};
    }

    if ( defined $self->{config}->{SSL_ca_file} ) {
        $ssl_opts->{SSL_ca_file} = $self->{config}->{SSL_ca_file};
    }

    if ( defined $self->{config}->{SSL_passwd} ) {
        $ssl_opts->{SSL_passwd_cb} = sub { return $self->{config}->{SSL_passwd}; };
    }

    return $ssl_opts;
}

sub get_val {
    my $self = shift;
    my $hr   = shift;
    my $key  = shift;

    my $val = $hr;

    my $logger = Koha::Logger->get( { category => 'Koha.Completion.NavetBorrowerCompletion' } );

    $logger->warn( Dumper($hr) );
    $logger->warn($key);
    for my $part ( split /\./, $key ) {
        $logger->warn($part);
        if ( !defined $val->{$part} ) {
            return undef;
        }
        $logger->warn($val);
        $val = $val->{$part};
    }

    return $val;
}

sub populate_form_fields {
    my $self = shift;
    my $pnr  = shift;
    my $dob  = shift;
    my $res  = shift;
    my $map  = shift;

    my @form_fields = ();

    my $pnr_attr = $self->{config}->{pnr_attribute} ? $self->{config}->{pnr_attribute} : 'PERSNUMMER';

    push @form_fields, {
        'name'     => 'patron_attr_',
        'attrname' => $pnr_attr,
        'value'    => $pnr
    };
    push @form_fields, {
        'name'  => 'dateofbirth',
        'value' => $dob
    };

    if ( $self->{config}->{populate_userid} ) {
        push @form_fields, {
            'name'  => 'userid',
            'value' => $pnr
        };
    }

    while ( my ( $srcname, $targetname ) = each %$map ) {
        my $val = $self->get_val( $res, $srcname );
        if ( defined($val) ) {
            if ( $targetname->[1] ) {
                $val = $self->name_capitalization($val);
            }
            my $record = {
                'name'  => $targetname->[0],
                'value' => $val
            };
            if ( $targetname->[0] eq 'patron_attr_' ) {
                $record->{attrname} = $targetname->[2];
            }
            push @form_fields, $record;
        }
    }

    return \@form_fields;
}

1;
