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

use Koha::Schema::Util::ExceptionTranslator;

=head1 UTILITY METHODS

=head2 translate_exception

    $schema->translate_exception($exception, $columns_info, $object);

Convenience method that delegates to the ExceptionTranslator utility.
This allows the schema to act as a central point for exception handling.

=cut

sub translate_exception {
    my ( $self, $exception, $columns_info, $object ) = @_;
    return Koha::Schema::Util::ExceptionTranslator->translate_exception($exception, $columns_info, $object);
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
