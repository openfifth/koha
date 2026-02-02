package Koha::ShibbolethFieldMapping;

use Modern::Perl;
use Koha::Exceptions;
use base qw(Koha::Object);

=head1 NAME

Koha::ShibbolethFieldMapping - Koha ShibbolethFieldMapping Object class

=head1 API

=head2 Class Methods

=cut

=head3 store

Override the base store method to enforce business rules:
- Only one matchpoint can be set at a time
- Required fields must be present

=cut

sub store {
    my $self = shift;

    unless ( $self->koha_field ) {
        Koha::Exceptions::MissingParameter->throw( error => "koha_field is required" );
    }

    unless ( $self->idp_field || $self->default_content ) {
        Koha::Exceptions::MissingParameter->throw( error => "Either idp_field or default_content must be provided" );
    }

    # Handle matchpoint logic before storing
    if ( $self->is_matchpoint ) {
        Koha::ShibbolethFieldMappings->new->ensure_single_matchpoint( $self->mapping_id );
    }

    return $self->SUPER::store(@_);
}

=head3 _type

=cut

sub _type {
    return 'ShibbolethFieldMapping';
}

1;
