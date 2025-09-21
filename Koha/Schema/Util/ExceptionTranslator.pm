package Koha::Schema::Util::ExceptionTranslator;

# Copyright 2025 Koha Development team
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

use Koha::Exceptions::Object;

=encoding utf8

=head1 NAME

Koha::Schema::Util::ExceptionTranslator - Centralized DBIx::Class exception translation

=head1 SYNOPSIS

    use Koha::Schema::Util::ExceptionTranslator;

    try {
        # DBIx::Class operation that might fail
        $schema->resultset('SomeTable')->create(\%data);
    } catch {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($_, \%columns_info);
    };

=head1 DESCRIPTION

This utility class provides centralized exception translation from DBIx::Class
exceptions to Koha-specific exceptions. This eliminates the need for duplicated
exception handling code throughout the codebase.

=head1 METHODS

=head2 translate_exception

    Koha::Schema::Util::ExceptionTranslator->translate_exception($exception, $columns_info);

Translates a DBIx::Class exception into an appropriate Koha exception and throws it.
If the exception cannot be translated, it rethrows the original exception.

=head3 Parameters

=over 4

=item * C<$exception> - The caught exception object

=item * C<$columns_info> (optional) - Hash reference of column information for enhanced error reporting

=back

=head3 Exception Types Handled

=over 4

=item * Foreign key constraint violations → C<Koha::Exceptions::Object::FKConstraint>

=item * Duplicate key violations → C<Koha::Exceptions::Object::DuplicateID>

=item * Invalid data type values → C<Koha::Exceptions::Object::BadValue>

=item * Data truncation for enum columns → C<Koha::Exceptions::Object::BadValue>

=back

=cut

sub translate_exception {
    my ( $class, $exception, $columns_info, $object ) = @_;

    # Only handle DBIx::Class exceptions
    return $exception->rethrow() unless ref($exception) eq 'DBIx::Class::Exception';

    my $msg = $exception->{msg};

    # Foreign key constraint failures
    if ( $msg =~ /Cannot add or update a child row: a foreign key constraint fails/ ) {

        # FIXME: MySQL error, if we support more DB engines we should implement this for each
        if ( $msg =~ /FOREIGN KEY \(`(?<column>.*?)`\)/ ) {
            Koha::Exceptions::Object::FKConstraint->throw(
                error     => 'Broken FK constraint',
                broken_fk => $+{column}
            );
        }
    }

    # Foreign key constraint deletion failures (parent row deletion blocked)
    elsif ( $msg =~
        /Cannot delete or update a parent row\: a foreign key constraint fails \(\`(?<database>.*?)\`\.\`(?<table>.*?)\`, CONSTRAINT \`(?<constraint>.*?)\` FOREIGN KEY \(\`(?<fk>.*?)\`\) REFERENCES \`.*\` \(\`(?<column>.*?)\`\)/
        )
    {
        Koha::Exceptions::Object::FKConstraintDeletion->throw(
            column     => $+{column},
            constraint => $+{constraint},
            fk         => $+{fk},
            table      => $+{table},
        );
    }

    # Duplicate key violations
    elsif ( $msg =~ /Duplicate entry '(.*?)' for key '(?<key>.*?)'/ ) {
        Koha::Exceptions::Object::DuplicateID->throw(
            error        => 'Duplicate ID',
            duplicate_id => $+{key}
        );
    }

    # Invalid data type values
    elsif ( $msg =~ /Incorrect (?<type>\w+) value: '(?<value>.*)' for column \W?(?<property>\S+)/ ) {

        # The optional \W in the regex might be a quote or backtick
        my $type     = $+{type};
        my $value    = $+{value};
        my $property = $+{property};
        $property =~ s/['`]//g;

        Koha::Exceptions::Object::BadValue->throw(
            type     => $type,
            value    => $value,
            property => $property =~ /(\w+\.\w+)$/
            ? $1
            : $property,    # results in table.column without quotes or backticks
        );
    }

    # Data truncation for enum columns
    elsif ( $msg =~ /Data truncated for column \W?(?<property>\w+)/ ) {

        # The optional \W in the regex might be a quote or backtick
        my $property = $+{property};

        # Only handle enum truncation if we have column info
        if ( $columns_info && $columns_info->{$property} ) {
            my $type = $columns_info->{$property}->{data_type};
            if ( $type && $type eq 'enum' ) {
                my $value = 'Invalid enum value';    # Default value

                # If we have an object, try to get the actual property value
                if ( $object && $object->can($property) ) {
                    eval { $value = $object->$property; };
                }

                Koha::Exceptions::Object::BadValue->throw(
                    type     => 'enum',
                    property => $property =~ /(\w+\.\w+)$/
                    ? $1
                    : $property,    # results in table.column without quotes or backticks
                    value => $value,
                );
            }
        }
    }

    # Catch-all: rethrow the original exception if we can't translate it
    $exception->rethrow();
}

=head1 FUTURE ENHANCEMENTS

This utility is designed to be extended to support:

=over 4

=item * Multiple database engines (PostgreSQL, SQLite, etc.)

=item * Additional exception types as they are identified

=item * Enhanced error reporting with more context

=back

=head1 AUTHOR

Koha Development Team

=cut

1;
