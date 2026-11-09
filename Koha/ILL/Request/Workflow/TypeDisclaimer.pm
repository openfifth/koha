package Koha::ILL::Request::Workflow::TypeDisclaimer;

# Copyright 2023 PTFS Europe Ltd
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

use Modern::Perl;

use Koha::ILL::TypeDisclaimers;

use POSIX qw( strftime );

use base qw(Koha::ILL::Request::Workflow);

=head1 NAME

Koha::ILL::Request::TypeDisclaimer - Koha ILL TypeDisclaimer

=head1 SYNOPSIS

Object-oriented class that provides the ILL request type disclaimer

=head1 DESCRIPTION

This class provides the ability to verify if it should render type disclaimer
and handle the template params accordingly

=head1 API

=head2 Class Methods

=head3 show_type_disclaimer

    my $show_type_disclaimer =
    Koha::ILL::Request::TypeDisclaimer->show_type_disclaimer($params);

Given $params, return true if type disclaimer should be shown

=cut

sub show_type_disclaimer {
    my ( $self, $request ) = @_;

    return 0 unless $self->{metadata}->{type};

    my $disc_info = $self->get_type_disclaimer_info( $self->{metadata}->{type} );

    if ( $disc_info->{interface} ) {
        return 0 if $disc_info->{interface} eq 'none';
        return 0
            if ( $disc_info->{interface} ne 'both'
            && $disc_info->{interface} ne $self->{ui_context} );
    }

    if ($request) {
        $disc_info = $self->_filter_uncompleted_fields( $disc_info, $request );
    }

    return

        # ILLModuleDisclaimerByType was parsed correctly
        $disc_info

        # There are fields remaining to fill out
        && $disc_info->{fields}

        # Type disclaimer has not yet been submitted
        && !$self->{metadata}->{type_disclaimer_submitted};
}

=head3 type_disclaimer_template_params

    my $type_disclaimer_template_params =
    Koha::ILL::Request::TypeDisclaimer->type_disclaimer_template_params(
        $params);

Given $params, return true if type disclaimer should be rendered

=cut

sub type_disclaimer_template_params {
    my ( $self, $params, $request ) = @_;

    my $disc_info = $self->get_type_disclaimer_info( $params->{type} );

    if ($request) {
        $disc_info = $self->_filter_uncompleted_fields( $disc_info, $request );
    }

    $params->{method} = 'typedisclaimer' if $self->{ui_context} eq 'staff';
    delete $params->{stage}              if $self->{ui_context} eq 'staff';

    return (
        whole      => $params,
        metadata   => $self->prep_metadata($params),
        disclaimer => $disc_info,
        $self->{ui_context} eq 'opac'
        ? (
            illrequestsview => 1,
            message         => $params->{message},
            op              => 'typedisclaimer',
            )
        : ()
    );
}

=head3 after_request_created

    $type_disclaimer->after_request_created($params, $request);

Actions that need to be done after the request has been created.

Returns 1 on success, 0 on failure.

=cut

sub after_request_created {
    my ( $self, $params, $request ) = @_;

    my $disc_info = $self->get_type_disclaimer_info( $params->{type} );

    if ($request) {
        $disc_info = $self->_filter_uncompleted_fields( $disc_info, $request );
    }

    # Validate required parameters before creating record of disclaimer
    return 0
        unless @{ $disc_info->{fields} };

    foreach my $field ( @{ $disc_info->{fields} } ) {
        my $value = $params->{ 'type_disclaimer_value_' . $field->{code} };

        # TODO: only for fill-in?
        next unless $value;

        my $type_disclaimer = {
            illrequest_id => $request->illrequest_id,
            code          => $field->{code},
            text          => $field->{text},
            value         => $value,
            date          => strftime( "%Y-%m-%dT%H:%M:%S", localtime( time() ) )
        };

        Koha::ILL::TypeDisclaimer->new($type_disclaimer)->store;
    }

    return 1;
}

=head3 clear_type_disclaimer

    $type_disclaimer->clear_type_disclaimer($request);

Clears the record of the type disclaimer for the given request.

=cut

sub clear_type_disclaimer {
    my ( $self, $request ) = @_;

    $request->type_disclaimers->delete();
}

=head3 get_type_disclaimer_info

    my $type_disclaimer_info =
      Koha::ILL::Request::Workflow::TypeDisclaimer->get_type_disclaimer_info( $request_type );

Given request type, returns the respective
type disclaimer info
Returns undef if sys pref is empty or malformed
=cut

sub get_type_disclaimer_info {
    my ( $class, $type ) = @_;

    my $disc_sys_pref = $class->_get_type_disclaimer_sys_pref;

    my @matching_request_type =
        map ( $_ eq $type ? $_ : (), keys %$disc_sys_pref );

    my $disc_info = undef;
    my $matched_type;
    if ( scalar @matching_request_type ) {
        $matched_type = $disc_sys_pref->{$type};
        $disc_info->{interface} = 'none' if $disc_sys_pref->{$type}->{bypass};
    } elsif ( $disc_sys_pref->{all} ) {
        $matched_type = $disc_sys_pref->{all};
    }

    my $fields;
    if ( exists $matched_type->{fields} ) {
        $fields = $matched_type->{fields};
    } else {
        $fields = [
            {
                text => $matched_type->{text}, av_category_code => $matched_type->{av_category_code},
                code => $matched_type->{code}
            }
        ];
    }

    $disc_info->{fields} = [
        map {
            {
                text => $fields->[$_]->{text}, av_cat => $fields->[$_]->{av_category_code},
                code => $fields->[$_]->{code} // 'unlabelled_' . $_
            }
        } 0 .. @{$fields} - 1
    ];

    $disc_info->{interface} //= $matched_type->{interface};

    # Check for duplicate codes
    my %codes;
    foreach my $field ( @{ $disc_info->{fields} } ) {
        return if exists $codes{ $field->{code} };
        $codes{ $field->{code} } = 1;
    }

    return $disc_info;
}

=head3 _filter_uncompleted_fields

    my $disc_info = $self->_filter_uncompleted_fields($disc_info, $request);

Filters disclaimer fields to only those that haven't yet been completed.

=cut

sub _filter_uncompleted_fields {
    my ( $self, $disc_info, $request ) = @_;
    return $disc_info unless $request;

    my %completed_codes;
    $completed_codes{$_} = 1 for ( $request->type_disclaimers->get_column('code') );

    my $result   = {%$disc_info};
    my @filtered = grep { !exists $completed_codes{ $_->{code} } } @{ $disc_info->{fields} };
    $result->{fields} = \@filtered;

    return $result;
}

=head3 _get_type_disclaimer_sys_pref

    my $disc_sys_pref = $self->_get_type_disclaimer_sys_pref;

Returns YAML from ILLModuleDisclaimerByType syspref
Returns empty if empty or YAML error

=cut

sub _get_type_disclaimer_sys_pref {
    my ($self) = @_;

    return C4::Context->yaml_preference("ILLModuleDisclaimerByType") // {};
}

=head1 AUTHOR

Pedro Amorim <pedro.amorim@ptfs-europe.com>

=cut

1;
