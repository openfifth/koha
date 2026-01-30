package Koha::Controller::Catalogue;

use Modern::Perl;

use C4::Auth qw( get_template_and_user );
use Koha::ILL::ISO18626::Requests;
use Koha::Patrons;

=head1 NAME

Koha::Controller::Catalogue - Koha Controller

=head1 API

=head2 Class Methods

=cut

=head3 init

    my ( $template, $loggedinuser, $cookie, $flags ) = Koha::Controller::Catalogue->init( $args );

Initializes the catalogue controller by generating the template, authenticating the user, and populating the template with standard search-related variables.

Takes a hashref C<$args> containing the CGI C<query>, C<template_name>, C<type>, and C<flagsrequired>.

Returns a list containing the C<$template> object, the C<$loggedinuser> ID, the session C<$cookie>, and the user's C<$flags>.

=cut

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

=head3 _prep_searchto_template_params

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

    if ( $query->cookie("holdforsupplyill") ) {
        my $holdfor_supply_ill = Koha::ILL::ISO18626::Requests->find( $query->cookie("holdforsupplyill") );
        if ($holdfor_supply_ill) {
            $template->param(
                holdforsupplyill => $query->cookie("holdforsupplyill"),
            );
        }
    }

    return 1;
}

1;
