package Koha::REST::V1::BorrowerCompletion;

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
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use DateTime::Format::Builder;
use DateTime::Format::Strptime;
use Koha::DateUtils qw( output_pref );

# use Koha::Completion::AddressServiceBorrowerCompletion;

use Koha::Completion::BorrowerCompletion;
use Koha::Completion::AddressServiceBorrowerCompletion;
use C4::Context;

sub fetch {
    my $c          = shift->openapi->valid_input or return;
    my $dateformat = C4::Context->preference('dateformat');

    my $config = C4::Context->config('borrower_completion');
    my $bcservice;
    my $backend = $config->{backend};

    my $logger = Koha::Logger->get( { category => 'Koha.Completion.BorrowerCompletion' } );

    $logger->warn('fetch');

    ( my $file = $backend ) =~ s{::}{/}g;
    $file .= '.pm';

    eval {
        require $file;
        $backend->can('new') or die "Class $backend has no constructor";
        $bcservice = $backend->new;
    };
    if ($@) {
        $logger->warn( 'eval result: ' . $@ );

        return $c->render(
            status  => 500,
            openapi => { error => $@ }
        );
    }

    my $pnr         = $c->validation->param('pnr');
    my $completions = $bcservice->fetch_completions($pnr);

    if ( defined( $completions->{error} ) ) {
        return $c->render(
            status  => $completions->{status},
            openapi => { error => $completions->{error} }
        );
    }

    my $parser = DateTime::Format::Strptime->new(
        pattern => '%F',
    );

    for my $compl ( @{ $completions->{form_fields} } ) {
        if ( $compl->{'name'} eq 'dateofbirth' ) {
            $compl->{'value'} = output_pref(
                {
                    dt       => $parser->parse_datetime( $compl->{'value'} ),
                    dateonly => 1
                }
            );
        }
    }

    return $c->render(
        status  => 200,
        openapi => {
            form_id     => "entryform",
            form_fields => $completions->{form_fields}
        }
    );
}

=head1 AUTHOR

Andreas Jonsson, E<lt>andreas.jonsson@kreablo.seE<gt>

=cut

1;
