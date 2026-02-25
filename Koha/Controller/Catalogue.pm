package Koha::Controller::Catalogue;

use Modern::Perl;

use C4::Auth qw( get_template_and_user );
use Koha::Patrons;

sub init {
    my ( $class, $args ) = @_;

    my $query = $args->{query};

    my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
        {
            template_name => $args->{template_name},
            query         => $query,
            type          => $args->{type},
            flagsrequired => $args->{flagsrequired},
        }
    );

    _prep_searchto_template_params( $template, $query );

    return ( $template, $loggedinuser, $cookie, $flags );
}

=head2 _prep_searchto_template_params

This prepares the common 'search to' functionality params e.g.:
- 'Search to hold'
- 'Search to order'
- etc

=cut

sub _prep_searchto_template_params {
    my ( $template, $query ) = @_;

    if ( $query->cookie("holdfor") ) {
        my $holdfor_patron = Koha::Patrons->find( $query->cookie("holdfor") );
        if ($holdfor_patron) {
            $template->param(
                holdfor        => $query->cookie("holdfor"),
                holdfor_patron => $holdfor_patron,
            );
        }
    }

    if ( $query->cookie("searchToOrder") ) {
        my ( $basketno, $vendorid ) = split( /\//, $query->cookie("searchToOrder") );
        $template->param(
            searchtoorder_basketno => $basketno,
            searchtoorder_vendorid => $vendorid
        );
    }

    return 1;
}

1;
