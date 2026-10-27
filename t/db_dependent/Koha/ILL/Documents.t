#!/usr/bin/perl

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

use Test::NoWarnings;
use Test::More tests => 4;
use Test::Exception;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::ILL::Documents;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'filter_by_purgeable_supplied() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    Koha::ILL::Documents->search->delete;

    my $old_received = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::Requests',
            value => { status => 'CopyCompleted', received_on => dt_from_string->subtract( days => 60 ) }
        }
    );
    my $recent_received = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::Requests',
            value => { status => 'CopyCompleted', received_on => dt_from_string->subtract( days => 10 ) }
        }
    );
    my $not_received = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::Requests',
            value => { status => 'CopyCompleted', received_on => undef }
        }
    );
    my $other_status = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::Requests',
            value => { status => 'Loaned', received_on => dt_from_string->subtract( days => 60 ) }
        }
    );

    my $old_document = $old_received->add_document( { file_name => 'old.pdf', file_content => 'PDF bytes' } );
    $_->add_document( { file_name => 'article.pdf', file_content => 'PDF bytes' } )
        for ( $recent_received, $not_received, $other_status );

    my $purgeable = Koha::ILL::Documents->filter_by_purgeable_supplied( { days => 30 } );
    is( $purgeable->count,    1,                 'Only the document received more than 30 days ago is purgeable' );
    is( $purgeable->next->id, $old_document->id, 'Correct document identified' );

    $purgeable = Koha::ILL::Documents->filter_by_purgeable_supplied( { days => 5 } );
    is( $purgeable->count, 2, 'Documents not received or of other statuses are never purgeable' );

    $purgeable->delete;
    is( Koha::ILL::Documents->search->count, 2, 'Only the purgeable documents are deleted' );

    throws_ok { Koha::ILL::Documents->filter_by_purgeable_supplied( {} ) }
    'Koha::Exceptions::MissingParameter', 'Throws without days';

    $schema->storage->txn_rollback;
};

subtest 'filter_by_purgeable_patron() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    Koha::ILL::Documents->search->delete;

    my $request = $builder->build_object( { class => 'Koha::ILL::Requests' } );
    my $add     = sub {
        my ( $uploaded_days_ago, $downloaded_days_ago ) = @_;
        my $document = $request->add_document( { file_name => 'article.pdf', file_content => 'PDF bytes' } );
        $document->set(
            {
                uploaded_on   => dt_from_string->subtract( days => $uploaded_days_ago ),
                downloaded_on => defined $downloaded_days_ago
                ? dt_from_string->subtract( days => $downloaded_days_ago )
                : undef,
            }
        )->store;
        return $document;
    };

    my $old_download     = $add->( 60, 40 );
    my $recent_download  = $add->( 60, 10 );
    my $old_undownloaded = $add->( 40, undef );
    $add->( 10, undef );

    my $supplied = $builder->build_object(
        {
            class => 'Koha::ILL::ISO18626::Requests',
            value => { status => 'CopyCompleted', received_on => dt_from_string->subtract( days => 60 ) }
        }
    );
    my $supplied_document = $supplied->add_document( { file_name => 'supplied.pdf', file_content => 'PDF bytes' } );
    $supplied_document->uploaded_on( dt_from_string->subtract( days => 60 ) )->store;

    my $purgeable = Koha::ILL::Documents->filter_by_purgeable_patron( { days => 30 } );
    is( $purgeable->count, 2, 'Two patron documents are purgeable after 30 days' );
    is_deeply(
        [ sort { $a <=> $b } $purgeable->get_column('ill_document_id') ],
        [ sort { $a <=> $b } ( $old_download->id, $old_undownloaded->id ) ],
        'Documents downloaded, or uploaded and never downloaded, more than 30 days ago are purgeable'
    );

    $purgeable = Koha::ILL::Documents->filter_by_purgeable_patron( { days => 50 } );
    is( $purgeable->count, 0, 'A document downloaded recently is kept although it was uploaded long ago' );

    $purgeable = Koha::ILL::Documents->filter_by_purgeable_patron( { days => 5 } );
    is( $purgeable->count, 4, 'Documents supplied to other libraries are never purgeable' );

    $purgeable->delete;
    is_deeply(
        [ Koha::ILL::Documents->search->get_column('ill_document_id') ],
        [ $supplied_document->id ], 'Only the purgeable documents are deleted'
    );

    throws_ok { Koha::ILL::Documents->filter_by_purgeable_patron( {} ) }
    'Koha::Exceptions::MissingParameter', 'Throws without days';

    $schema->storage->txn_rollback;
};

subtest 'record_download() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $request  = $builder->build_object( { class     => 'Koha::ILL::Requests' } );
    my $document = $request->add_document( { file_name => 'article.pdf', file_content => 'PDF bytes' } );
    $document->discard_changes;

    is( $document->download_count, 0,     'download_count starts at 0' );
    is( $document->downloaded_on,  undef, 'downloaded_on starts empty' );

    $document->record_download;
    $document->discard_changes;
    is( $document->download_count, 1, 'download_count is incremented' );
    ok( $document->downloaded_on, 'downloaded_on is set on the first download' );

    $document->downloaded_on('2026-01-01 10:00:00')->store;
    $document->record_download;
    $document->discard_changes;
    is( $document->downloaded_on, '2026-01-01 10:00:00', 'downloaded_on keeps the first download' );

    $schema->storage->txn_rollback;
};
