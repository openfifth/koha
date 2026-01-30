package Koha::Events;

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
use Module::Load qw( load );

my %subscribers;
my $initialized = 0;

# TODO: Implement a way for hook classes to depend on a condition i.e. sys pref
my @HOOK_CLASSES = qw(
    Koha::ILL::ISO18626::EventHooks 
);

sub subscribe {
    my ( $class_name, $event_name, $callback ) = @_;

    push @{ $subscribers{$class_name}{$event_name} }, $callback;
}

sub emit {
    my ( $class_name, $event_name, @args ) = @_;

    if ( !$initialized ) {
        foreach my $hook_class (@HOOK_CLASSES) {
            eval { load $hook_class; };
            warn "Koha::Events: Failed to load $hook_class: $@" if $@;
        }
        $initialized = 1;
    }

    return unless exists $subscribers{$class_name};
    return unless exists $subscribers{$class_name}{$event_name};

    my $callbacks = $subscribers{$class_name}{$event_name};

    foreach my $callback ( @$callbacks ) {
        eval { $callback->(@args) };
        warn "Koha::Events: Callback error: $@" if $@;
    }
}

1;
