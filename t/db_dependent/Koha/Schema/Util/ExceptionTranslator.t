#!/usr/bin/perl

# Copyright 2025 Koha Development team
#
# This file is part of Koha
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::NoWarnings;
use Test::More tests => 9;
use Test::Exception;

use Koha::Database;
use Koha::Schema::Util::ExceptionTranslator;

use t::lib::TestBuilder;

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->new->schema;

subtest 'foreign_key_constraint_translation' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Create a mock DBIx::Class::Exception for FK constraint
    my $exception =
        bless { msg =>
            "Cannot add or update a child row: a foreign key constraint fails (`koha`.`items`, CONSTRAINT `items_ibfk_1` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`))"
        }, 'DBIx::Class::Exception';

    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($exception);
    }
    'Koha::Exceptions::Object::FKConstraint', 'FK constraint exception is properly translated';

    $schema->storage->txn_rollback;
};

subtest 'duplicate_key_translation' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Create a mock DBIx::Class::Exception for duplicate key
    my $exception = bless { msg => "Duplicate entry 'test\@example.com' for key 'borrowers.email'" },
        'DBIx::Class::Exception';

    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($exception);
    }
    'Koha::Exceptions::Object::DuplicateID', 'Duplicate key exception is properly translated';

    $schema->storage->txn_rollback;
};

subtest 'bad_value_translation' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Create a mock DBIx::Class::Exception for bad value
    my $exception = bless { msg => "Incorrect datetime value: '2025-13-45' for column 'date_due' at row 1" },
        'DBIx::Class::Exception';

    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($exception);
    }
    'Koha::Exceptions::Object::BadValue', 'Bad value exception is properly translated';

    $schema->storage->txn_rollback;
};

subtest 'enum_truncation_translation' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Create a mock DBIx::Class::Exception for enum truncation
    my $exception = bless { msg => "Data truncated for column 'status' at row 1" }, 'DBIx::Class::Exception';

    my $columns_info = { status => { data_type => 'enum' } };

    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception( $exception, $columns_info );
    }
    'Koha::Exceptions::Object::BadValue', 'Enum truncation exception is properly translated';

    $schema->storage->txn_rollback;
};

subtest 'non_dbix_exception_passthrough' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Create a regular exception (not DBIx::Class::Exception)
    my $exception = bless { msg => "Some other error" }, 'Some::Other::Exception';

    # Mock the rethrow method
    $exception->{rethrown} = 0;
    {

        package Some::Other::Exception;
        sub rethrow { $_[0]->{rethrown} = 1; die $_[0]; }
    }

    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($exception);
    }
    qr/Some::Other::Exception/, 'Non-DBIx::Class exceptions are rethrown unchanged';

    $schema->storage->txn_rollback;
};

subtest 'fk_constraint_deletion_translation' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;

    # Create a mock DBIx::Class::Exception for FK constraint deletion
    my $exception =
        bless { msg =>
            "Cannot delete or update a parent row: a foreign key constraint fails (`koha`.`items`, CONSTRAINT `items_ibfk_1` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`))"
        }, 'DBIx::Class::Exception';

    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception($exception);
    }
    'Koha::Exceptions::Object::FKConstraintDeletion', 'FK constraint deletion exception is properly translated';

    $schema->storage->txn_rollback;
};

subtest 'enum_truncation_with_object_value' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    # Create a mock object with a property accessor
    my $mock_object = bless { test_enum => 'invalid_value' }, 'TestObject';

    # Add the can method to simulate a real object
    {
        no strict 'refs';
        *{"TestObject::can"} = sub {
            my ( $self, $method ) = @_;
            return $method eq 'test_enum' ? sub { return $self->{test_enum} } : undef;
        };
        *{"TestObject::test_enum"} = sub { return $_[0]->{test_enum} };
    }

    # Create a mock DBIx::Class::Exception for enum data truncation
    my $exception = bless { msg => "Data truncated for column 'test_enum'" }, 'DBIx::Class::Exception';

    # Mock column info with enum type
    my $columns_info = { test_enum => { data_type => 'enum' } };

    # Test with object - should include the actual value
    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception( $exception, $columns_info, $mock_object );
    }
    'Koha::Exceptions::Object::BadValue', 'Enum truncation with object throws BadValue exception';

    # Test without object - should use default value
    throws_ok {
        Koha::Schema::Util::ExceptionTranslator->translate_exception( $exception, $columns_info );
    }
    'Koha::Exceptions::Object::BadValue', 'Enum truncation without object throws BadValue exception';

    $schema->storage->txn_rollback;
};

subtest 'schema_safe_do_method' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    # Test successful operation
    my $result = $schema->safe_do(
        sub {
            return "success";
        }
    );
    is( $result, "success", 'safe_do returns result on success' );

    # Test exception translation
    throws_ok {
        $schema->safe_do(
            sub {
                # Create a mock DBIx::Class::Exception
                my $exception = bless { msg => "Duplicate entry 'test' for key 'primary'" }, 'DBIx::Class::Exception';
                die $exception;
            }
        );
    }
    'Koha::Exceptions::Object::DuplicateID', 'safe_do translates exceptions properly';

    $schema->storage->txn_rollback;
};

1;
