use utf8;
package Koha::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-10-14 20:56:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oDUxXckmfk6H9YCjW8PZTw

use Try::Tiny qw( catch try );
use Koha::Schema::Util::ExceptionTranslator;

=head1 UTILITY METHODS

=head2 safe_do

    $schema->safe_do(sub {
        # DBIx::Class operations that might throw exceptions
        $schema->resultset('SomeTable')->create(\%data);
    }, $columns_info);

Execute a code block with automatic DBIx::Class exception translation.
This provides a centralized way to handle database exceptions throughout the application.

=head3 Parameters

=over 4

=item * C<$code_ref> - Code reference to execute

=item * C<$columns_info> (optional) - Hash reference of column information for enhanced error reporting

=back

=head3 Example Usage

    # Basic usage
    $schema->safe_do(sub {
        $register->_result->add_to_cash_register_actions(\%action_data);
    });

    # With column info for enhanced error reporting
    my $columns_info = $register->_result->result_source->columns_info;
    $schema->safe_do(sub {
        $register->_result->create_related('some_relation', \%data);
    }, $columns_info);

=cut

sub safe_do {
    my ( $self, $code_ref, $columns_info, $object ) = @_;

    try {
        return $code_ref->();
    } catch {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($_, $columns_info, $object);
    };
}

=head2 translate_exception

    $schema->translate_exception($exception, $columns_info);

Convenience method that delegates to the ExceptionTranslator utility.
This allows the schema to act as a central point for exception handling.

=cut

sub translate_exception {
    my ( $self, $exception, $columns_info, $object ) = @_;
    return Koha::Schema::Util::ExceptionTranslator->translate_exception($exception, $columns_info, $object);
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
