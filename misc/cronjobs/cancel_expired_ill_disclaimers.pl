#!/usr/bin/perl

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

cancel_expired_ill_disclaimers.pl - Cancels ILL requests whose type disclaimer prompts have elapsed.

=head1 SYNOPSIS

    cancel_expired_ill_disclaimers.pl --help
    cancel_expired_ill_disclaimers.pl --test
    cancel_expired_ill_disclaimers.pl --commit

=head1 DESCRIPTION

This script can be used to automatically cancel ILL requests which have
type disclaimers that have expired.

=head1 OPTIONS

=over 8

=item B<-h|--help>

Display the help message and exit

=item B<-t|--test>

Ensure that the script only reports the number of requests it would cancel.

=item B<-c|--confirm>

Confirm that the script should actually cancel the requests.

=item B<-v|--verbose>

Output each request as it is found.

=back

=cut

use Modern::Perl;
use Getopt::Long qw( GetOptions );
use Pod::Usage   qw( pod2usage );

use Koha::DateUtils qw( dt_from_string );
use Koha::Script -cron;
use Koha::ILL::Requests;

use C4::Log qw( cronlogaction );

my $command_line_options = join( " ", @ARGV );
cronlogaction( { info => $command_line_options } );

my ( $help, $confirm, $test, $verbose );
GetOptions(
    'h|help'    => \$help,
    'c|confirm' => \$confirm,
    't|test'    => \$test,
    'v|verbose' => \$verbose,
) || pod2usage(2);
pod2usage(1) if $help;

$confirm = 0 if $test;

my $requests = Koha::ILL::Requests->search();

my $dtf         = Koha::Database->new->schema->storage->datetime_parser;
my $cutoff_time = $dtf->format_datetime( dt_from_string() );

my $cancelled_requests = 0;
while ( my $request = $requests->next ) {
    next unless $request->type_disclaimer_prompts->count;
    next if $request->type_disclaimer_prompts->search(
        {
            '-or' => [
                date_replied => { '!=' => undef },
                valid_until  => { '>=' => $cutoff_time }
            ]
        }
    )->count;

    print "Found request " . $request->id . "\n" if $verbose;
    $cancelled_requests++;

    next unless $confirm;

    $request->status('CANCREQ')->store;
}

# Print totals
my $verb = $confirm ? 'Cancelled' : 'Found';
print "cancel_expired_ill_disclaimers: $verb $cancelled_requests requests\n";

cronlogaction( { action => 'End', info => "COMPLETED" } );

1;

__END__
