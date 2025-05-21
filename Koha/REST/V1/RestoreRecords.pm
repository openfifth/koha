package Koha::REST::V1::RestoreRecords;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::RestoreRecords;
use Try::Tiny qw( catch try );

=head1 NAME

Koha::REST::V1::RestoreRecords

=head1 API

=head2 Methods

=head3 restore_biblio

Controller function that handles restoring a deleted bibliographic record

=cut

sub restore_biblio {
    my $c = shift->openapi->valid_input or return;

    my $biblionumber = $c->param('biblionumber');

    return try {
        my $restorer = Koha::RestoreRecords->new();
        my $result = $restorer->restore_biblio($biblionumber);

        if ($result->{success}) {
            return $c->render( status => 200, openapi => { success => 1 } );
        } else {
            return $c->render(
                status => 404,
                openapi => { error => $result->{error} || 'Failed to restore record' }
            );
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 restore_item

Controller function that handles restoring a deleted item

=cut

sub restore_item {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->param('itemnumber');

    return try {
        my $restorer = Koha::RestoreRecords->new();
        my $result = $restorer->restore_item($itemnumber);

        if ($result->{success}) {
            return $c->render( status => 200, openapi => { success => 1 } );
        } else {
            return $c->render(
                status => 404,
                openapi => { error => $result->{error} || 'Failed to restore item' }
            );
        }
    } catch {
        $c->unhandled_exception($_);
    };
}

1;