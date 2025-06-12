package Koha::Middleware::RealIP;

# Copyright 2019 ByWater Solutions and the Koha Dev Team
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use parent qw(Plack::Middleware);

use C4::Context;

use Net::Netmask;
use Plack::Util::Accessor qw( trusted_proxy );

=head1 METHODS

=head2 prepare_app

This method generates and stores the list of trusted ip's as Netmask objects
at the time Plack starts up, obviating the need to regerenate them on each request.

=cut

sub prepare_app {
    my $self = shift;
    $self->trusted_proxy( get_trusted_proxies() );
}

=head2 call

This method is called for each request, and will ensure the correct remote address
is set in the REMOTE_ADDR environment variable.

=cut

sub call {
    my $self = shift;
    my $env  = shift;

    my $reverse_proxy_ip_header = C4::Context->config('reverse_proxy_ip_header') || 'HTTP_X_FORWARDED_FOR';
    my $require_trusted         = C4::Context->config('require_trusted_proxy_for_headers');

    my $header = $env->{$reverse_proxy_ip_header} || $env->{'HTTP_X_FORWARDED_FOR'};
    my $addr   = $env->{REMOTE_ADDR};

    if ($header) {
        if ($require_trusted) {

            # Only trust header if REMOTE_ADDR is a trusted proxy
            my $trusted_proxies = get_trusted_proxies();
            my $is_trusted      = 0;
            foreach my $netmask (@$trusted_proxies) {
                if ( $netmask->match($addr) ) {
                    $is_trusted = 1;
                    last;
                }
            }
            if ($is_trusted) {
                $addr = get_real_ip( $env->{REMOTE_ADDR}, $header );
            }
        } else {

            # Always trust the header
            $addr = get_real_ip( $env->{REMOTE_ADDR}, $header );
        }
        $ENV{REMOTE_ADDR} = $addr;
        $env->{REMOTE_ADDR} = $addr;
    }

    return $self->app->($env);
}

=head2 get_real_ip

my $address = get_real_ip( $remote_addres, $x_forwarded_for_header );

This method takes the current remote address and the x-forwarded-for header string,
determines the correct external ip address, and returns it.

=cut

sub get_real_ip {
    my ( $remote_addr, $header ) = @_;

    my @forwarded_for = $header =~ /([^,\s]+)/g;
    return $remote_addr unless @forwarded_for;

    #X-Forwarded-For: <client>, <proxy1>, <proxy2>
    my $real_ip = shift @forwarded_for;
    return $real_ip if $real_ip;
    return $remote_addr;
}

=head2 get_trusted_proxies

This method returns an arrayref of Net::Netmask objects for all
the trusted proxies given to Koha.

=cut

sub get_trusted_proxies {
    my $proxies_conf = C4::Context->config('koha_trusted_proxies');
    return unless $proxies_conf;
    my @trusted_proxies_ip = split( / /, $proxies_conf );
    my @trusted_proxies    = ();
    foreach my $ip (@trusted_proxies_ip) {
        my $mask = Net::Netmask->new2($ip);
        if ($mask) {
            push( @trusted_proxies, $mask );
        } else {
            warn "$Net::Netmask::error";
        }
    }
    return \@trusted_proxies;
}

=head1 AUTHORS

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
