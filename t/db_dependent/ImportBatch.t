#!/usr/bin/perl

use Modern::Perl;
use Test::MockModule;
use Test::NoWarnings;
use Test::More tests => 25;
use utf8;
use File::Basename;
use File::Temp qw/tempfile/;

use MARC::Field;
use MARC::Record;

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Biblios;
use Koha::Database;
use Koha::Exceptions::Metadata;
use Koha::Import::Records;

BEGIN {
    # Mock pluginsdir before loading Plugins module
    my $path = dirname(__FILE__) . '/../lib/plugins';
    t::lib::Mocks::mock_config( 'pluginsdir', $path );

    use_ok('Koha::Plugins');
    use_ok(
        'C4::ImportBatch',
        qw( AddImportBatch GetImportBatch AddBiblioToBatch AddItemsToImportBiblio SetMatchedBiblionumber GetImportBiblios GetItemNumbersFromImportBatch CleanBatch DeleteBatch RecordsFromMarcPlugin BatchCommitRecords )
    );
}

# Start transaction
my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

# clear
$dbh->do('DELETE FROM import_batches');

my $sample_import_batch1 = {
    matcher_id     => 1,
    template_id    => 1,
    branchcode     => 'QRT',
    overlay_action => 'create_new',
    nomatch_action => 'create_new',
    item_action    => 'always_add',
    import_status  => 'staged',
    batch_type     => 'z3950',
    file_name      => 'test.mrc',
    comments       => 'test',
    record_type    => 'auth',
};

my $sample_import_batch2 = {
    matcher_id     => 2,
    template_id    => 2,
    branchcode     => 'QRZ',
    overlay_action => 'create_new',
    nomatch_action => 'create_new',
    item_action    => 'always_add',
    import_status  => 'staged',
    batch_type     => 'z3950',
    file_name      => 'test.mrc',
    comments       => 'test',
    record_type    => 'auth',
};

my $id_import_batch1 = C4::ImportBatch::AddImportBatch($sample_import_batch1);
my $id_import_batch2 = C4::ImportBatch::AddImportBatch($sample_import_batch2);

like( $id_import_batch1, '/^\d+$/', "AddImportBatch for sample_import_batch1 return an id" );
like( $id_import_batch2, '/^\d+$/', "AddImportBatch for sample_import_batch2 return an id" );

#Test GetImportBatch
my $importbatch2 = C4::ImportBatch::GetImportBatch($id_import_batch2);
delete $importbatch2->{upload_timestamp};
delete $importbatch2->{import_batch_id};
delete $importbatch2->{num_records};
delete $importbatch2->{num_items};
delete $importbatch2->{profile_id};
delete $importbatch2->{profile};

is_deeply(
    $importbatch2, $sample_import_batch2,
    "GetImportBatch returns the right information about $sample_import_batch2"
);

my $importbatch1 = C4::ImportBatch::GetImportBatch($id_import_batch1);
delete $importbatch1->{upload_timestamp};
delete $importbatch1->{import_batch_id};
delete $importbatch1->{num_records};
delete $importbatch1->{num_items};
delete $importbatch1->{profile_id};
delete $importbatch1->{profile};

is_deeply(
    $importbatch1, $sample_import_batch1,
    "GetImportBatch returns the right information about $sample_import_batch1"
);

my $record          = MARC::Record->new;
my $original_record = MARC::Record->new;
$record->leader('03174nam a2200445 a 4500');
$original_record->leader('03174nam a2200445 a 4500');
my ( $item_tag, $item_subfield ) = C4::Biblio::GetMarcFromKohaField('items.itemnumber');
my @fields;
if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {
    @fields = (
        MARC::Field->new(
            100, ' ', ' ',
            a => '20220520d        u||y0frey50      ba',
        ),
        MARC::Field->new(
            700, ' ', ' ',
            a => 'Knuth, Donald Ervin',
            f => '1938',
        ),
        MARC::Field->new(
            200, ' ', ' ',
            a => 'The art of computer programming',
            f => 'Donald E. Knuth.',
        ),
        MARC::Field->new(
            650, ' ', '0',
            a => 'Computer programming.',
            9 => '462',
        ),
        MARC::Field->new(
            $item_tag, ' ', ' ',
            e => 'my edition ❤',
            i => 'my item part',
        ),
        MARC::Field->new(
            $item_tag, ' ', ' ',
            e => 'my edition 2',
            i => 'my item part 2',
        ),
    );
} else {
    @fields = (
        MARC::Field->new(
            100, '1', ' ',
            a => 'Knuth, Donald Ervin',
            d => '1938',
        ),
        MARC::Field->new(
            245, '1', '4',
            a => 'The art of computer programming',
            c => 'Donald E. Knuth.',
        ),
        MARC::Field->new(
            650, ' ', '0',
            a => 'Computer programming.',
            9 => '462',
        ),
        MARC::Field->new(
            $item_tag, ' ', ' ',
            e => 'my edition ❤',
            i => 'my item part',
        ),
        MARC::Field->new(
            $item_tag, ' ', ' ',
            e => 'my edition 2',
            i => 'my item part 2',
        ),
    );
}
$record->append_fields(@fields);
$original_record->append_fields(@fields);
my $import_record_id = AddBiblioToBatch( $id_import_batch1, 0, $record, 'utf8', 0 );
AddItemsToImportBiblio( $id_import_batch1, $import_record_id, $record, 0 );

my $import_record             = Koha::Import::Records->find($import_record_id);
my $record_from_import_biblio = $import_record->get_marc_record();

$original_record->leader( $record_from_import_biblio->leader() );
is_deeply(
    $record_from_import_biblio, $original_record,
    'Koha::Import::Record::get_marc_record should return the record in original state'
);
my $utf8_field = $record_from_import_biblio->subfield( $item_tag, 'e' );
is( $utf8_field, 'my edition ❤' );

my $another_biblio = $builder->build_sample_biblio;
C4::ImportBatch::SetMatchedBiblionumber( $import_record_id, $another_biblio->biblionumber );
my $import_biblios = GetImportBiblios($import_record_id);
is(
    $import_biblios->[0]->{matched_biblionumber}, $another_biblio->biblionumber,
    'SetMatchedBiblionumber  should set the correct biblionumber'
);

# Add a few tests for GetItemNumbersFromImportBatch
my @a = GetItemNumbersFromImportBatch($id_import_batch1);
is( @a, 0, 'No item numbers expected since we did not commit' );
my $itemno = $builder->build_sample_item->itemnumber;

# Link this item to the import item to fool GetItemNumbersFromImportBatch
my $sql = "UPDATE import_items SET itemnumber=? WHERE import_record_id=?";
$dbh->do( $sql, undef, $itemno, $import_record_id );
@a = GetItemNumbersFromImportBatch($id_import_batch1);
is( @a,    2,       'Expecting two items now' );
is( $a[0], $itemno, 'Check the first returned itemnumber' );

# Now delete the item and check again
$dbh->do( "DELETE FROM items WHERE itemnumber=?", undef, $itemno );
@a = GetItemNumbersFromImportBatch($id_import_batch1);
is( @a, 0, 'No item numbers expected since we deleted the item' );
$dbh->do( $sql, undef, undef, $import_record_id );    # remove link again

# fresh data
my $sample_import_batch3 = {
    matcher_id     => 3,
    template_id    => 3,
    branchcode     => 'QRT',
    overlay_action => 'create_new',
    nomatch_action => 'create_new',
    item_action    => 'always_add',
    import_status  => 'staged',
    batch_type     => 'z3950',
    file_name      => 'test.mrc',
    comments       => 'test',
    record_type    => 'auth',
};

my $id_import_batch3 = C4::ImportBatch::AddImportBatch($sample_import_batch3);

# Test CleanBatch
C4::ImportBatch::CleanBatch($id_import_batch3);
$import_record = get_import_record($id_import_batch3);
is( $import_record, "0E0", "Batch 3 has been cleaned" );

# Test DeleteBatch
C4::ImportBatch::DeleteBatch($id_import_batch3);
my $import_batch = C4::ImportBatch::GetImportBatch($id_import_batch3);
is( $import_batch, undef, "Batch 3 has been deleted" );

subtest "_batchCommitItems" => sub {
    plan tests => 3;

    my $exist_item  = $builder->build_sample_item;
    my $import_item = $builder->build_object(
        {
            class => 'Koha::Import::Record::Items',
            value => {
                marcxml => q{<?xml version="1.0" encoding="UTF-8"?>
<collection
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
  xmlns="http://www.loc.gov/MARC21/slim">

<record>
  <leader>00000    a              </leader>
  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="a">CPL</subfield>
    <subfield code="b">CPL</subfield>
    <subfield code="c">GEN</subfield>
    <subfield code="p">} . $exist_item->barcode . q{</subfield>
    <subfield code="y">BK</subfield>
  </datafield>
</record>
</collection>
        },
            }
        }
    );

    my ( $num_items_added, $num_items_replaced, $num_items_errored ) =
        C4::ImportBatch::_batchCommitItems( $import_item->import_record_id, 32, 'always_add', 64 );
    is( $num_items_errored, 1, "Item with duplicate barcode fails when action always_add" );
    $import_item->discard_changes();
    is( $import_item->status, 'error', "Import item marked as error when duplicate barcode and action always_add" );
    is(
        $import_item->import_error, 'duplicate item barcode',
        'Error correctly set when import item has duplicate barcode and action always_add'
    );
};

subtest "_batchCommitItems reports items whose MARCXML cannot be decoded" => sub {
    plan tests => 3;

    my $import_item = $builder->build_object(
        {
            class => 'Koha::Import::Record::Items',
            value => { marcxml => 'this is not valid MARCXML' },
        }
    );

    my ( $num_items_added, $num_items_replaced, $num_items_errored ) =
        C4::ImportBatch::_batchCommitItems( $import_item->import_record_id, 32, 'always_add', 64 );
    is( $num_items_errored, 1, "Item with undecodable MARCXML is reported as errored, not fatal" );
    $import_item->discard_changes();
    is( $import_item->status, 'error', "Import item marked as error when its MARCXML cannot be decoded" );
    ok( $import_item->import_error, 'The decoding error is recorded for the user to see' );
};

subtest "RecordsFromMarcPlugin" => sub {
    plan tests => 5;

    # Create a test file
    my ( $fh, $name ) = tempfile();
    if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {
        print $fh q{
003 = NLAmRIJ
100,a = 20220520d        u||y0frey50      ba
700,a = Author
200,ind2 = 0
200,a = Silence in the library
500 , a= Some note

700,a = Another
245,a = Noise in the library};
        close $fh;
    } else {
        print $fh q|
003 = NLAmRIJ
100,a = Author
245,ind2 = 0
245,a = Silence in the library
500 , a= Some note

100,a = Another
245,a = Noise in the library|;
        close $fh;
    }

    t::lib::Mocks::mock_config( 'enable_plugins', 1 );

    my $plugins = Koha::Plugins->new;
    $plugins->InstallPlugins;
    my ($plugin) = $plugins->GetPlugins( { all => 1, metadata => { name => 'MarcFieldValues' } } );
    isnt( $plugin, undef, "Plugin found" );
    $plugin->enable();
    my $records = C4::ImportBatch::RecordsFromMarcPlugin( $name, ref $plugin, 'UTF-8' );
    is( @$records,         2,              'Two results returned' );
    is( ref $records->[0], 'MARC::Record', 'Returned MARC::Record object' );

    if ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {
        is(
            $records->[0]->subfield( '200', 'a' ), 'Silence in the library',
            'Checked one field in first record'
        );
        is(
            $records->[1]->subfield( '700', 'a' ), 'Another',
            'Checked one field in second record'
        );
    } else {
        is(
            $records->[0]->subfield( '245', 'a' ), 'Silence in the library',
            'Checked one field in first record'
        );
        is(
            $records->[1]->subfield( '100', 'a' ), 'Another',
            'Checked one field in second record'
        );
    }
};

subtest "_get_commit_action" => sub {
    plan tests => 24;
    my $mock_import = Test::MockModule->new("C4::ImportBatch");

    $mock_import->mock( GetBestRecordMatch => sub { return 5; } );
    foreach my $record_type ( ( 'biblio', 'authority' ) ) {
        foreach my $match_action ( ( 'replace', 'create_new', 'ignore' ) ) {
            foreach my $no_match_action ( ( 'create_new', 'ignore' ) ) {
                my ( $result, $match, $item_result ) = C4::ImportBatch::_get_commit_action(
                    $match_action, $no_match_action, 'always_add', 'auto_match',
                    42, $record_type
                );
                is(
                    $result, $match_action,
                    "When match found amd chosen we return the match_action for $record_type records with match action $match_action and no match action $no_match_action"
                );
            }
        }
    }

    $mock_import->mock( GetBestRecordMatch => sub { my $matches = undef; return $matches; } );
    foreach my $record_type ( ( 'biblio', 'authority' ) ) {
        foreach my $match_action ( ( 'replace', 'create_new', 'ignore' ) ) {
            foreach my $no_match_action ( ( 'create_new', 'ignore' ) ) {
                my ( $result, $match, $item_result ) = C4::ImportBatch::_get_commit_action(
                    $match_action, $no_match_action, 'always_add', 'auto_match',
                    42, $record_type
                );
                is(
                    $result, $no_match_action,
                    "When no match found or chosen we return the match_action for $record_type records with match action $match_action and no match action $no_match_action"
                );
            }
        }
    }

};

subtest "BatchCommitRecords overlay into framework" => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'enable_plugins', 0 );
    my $mock_import = Test::MockModule->new("C4::ImportBatch");
    my $biblio      = $builder->build_sample_biblio;
    $mock_import->mock( _get_commit_action => sub { return ( 'replace', 'ignore', $biblio->biblionumber ); } );

    my $import_batch = {
        matcher_id     => 2,
        template_id    => 2,
        branchcode     => 'QRZ',
        overlay_action => 'replace',
        nomatch_action => 'ignore',
        item_action    => 'ignore',
        import_status  => 'staged',
        batch_type     => 'z3950',
        file_name      => 'test.mrc',
        comments       => 'test',
        record_type    => 'auth',
    };
    my $id_import_batch  = C4::ImportBatch::AddImportBatch($import_batch);
    my $import_record_id = AddBiblioToBatch( $id_import_batch, 0, $biblio->metadata->record, 'utf8', 0 );

    BatchCommitRecords(
        {
            batch_id          => $id_import_batch,
            framework         => "",
            overlay_framework => "QQ",
        }
    );
    $biblio->discard_changes;
    is( $biblio->frameworkcode, "QQ", "Framework set on overlay" );
};

subtest "BatchCommitRecords reports invalid metadata without aborting the batch" => sub {
    plan tests => 5;

    my $good_record = MARC::Record->new();
    $good_record->leader('00000nam a2200000uu 4500');
    $good_record->append_fields( MARC::Field->new( '245', '', '', 'a' => 'A good record' ) );

    my $bad_record = MARC::Record->new();
    $bad_record->leader('00000nam a2200000uu 4500');
    $bad_record->append_fields( MARC::Field->new( '245', '', '', 'a' => 'A bad record' ) );

    my $import_batch = {
        matcher_id     => 3,
        template_id    => 3,
        branchcode     => 'QRT',
        overlay_action => 'create_new',
        nomatch_action => 'create_new',
        item_action    => 'ignore',
        import_status  => 'staged',
        batch_type     => 'batch',
        file_name      => 'test.mrc',
        comments       => 'test',
        record_type    => 'biblio',
    };
    my $id_import_batch       = C4::ImportBatch::AddImportBatch($import_batch);
    my $good_import_record_id = AddBiblioToBatch( $id_import_batch, 0, $good_record, 'utf8', 0 );
    my $bad_import_record_id  = AddBiblioToBatch( $id_import_batch, 1, $bad_record,  'utf8', 0 );

    my $mock_import = Test::MockModule->new("C4::ImportBatch");
    $mock_import->mock(
        AddBiblio => sub {
            my ( $record, $framework, $options ) = @_;
            if ( $record->subfield( '245', 'a' ) eq 'A bad record' ) {
                Koha::Exceptions::Metadata::Invalid->throw(
                    id             => undef,
                    biblionumber   => undef,
                    format         => 'marcxml',
                    schema         => 'MARC21',
                    decoding_error => 'Field 942 must have at least one subfield',
                );
            }
            return $mock_import->original('AddBiblio')->( $record, $framework, $options );
        }
    );

    my (
        $num_added, $num_updated, $num_items_added, $num_items_replaced, $num_items_errored, $num_ignored,
        $num_errored
    ) = BatchCommitRecords( { batch_id => $id_import_batch, framework => '' } );

    is( $num_added,   1, 'The valid record was added despite the other record failing' );
    is( $num_errored, 1, 'The invalid record is reported as errored rather than aborting the batch' );

    my $bad_import_record = Koha::Import::Records->find($bad_import_record_id);
    is( $bad_import_record->status, 'error', 'The bad import record is flagged with an error status' );
    like(
        $bad_import_record->import_error,
        qr/Field 942 must have at least one subfield/,
        'The decoding error is recorded so it can be shown to the user'
    );

    my $good_import_record = Koha::Import::Records->find($good_import_record_id);
    is( $good_import_record->status, 'imported', 'The good import record was still imported successfully' );
};

subtest "BatchRevertRecords reports records whose marcxml_old cannot be decoded" => sub {
    plan tests => 4;

    my $import_batch = {
        matcher_id     => 4,
        template_id    => 4,
        branchcode     => 'QRT',
        overlay_action => 'replace',
        nomatch_action => 'create_new',
        item_action    => 'ignore',
        import_status  => 'imported',
        batch_type     => 'batch',
        file_name      => 'test.mrc',
        comments       => 'test',
        record_type    => 'biblio',
    };
    my $id_import_batch = C4::ImportBatch::AddImportBatch($import_batch);

    my $import_record = $builder->build_object(
        {
            class => 'Koha::Import::Records',
            value => {
                import_batch_id => $id_import_batch,
                record_type     => 'biblio',
                status          => 'imported',
                overlay_status  => 'match_applied',
                marcxml_old     => 'this is not valid MARCXML',
                encoding        => 'UTF-8',
            }
        }
    );

    my ( $num_deleted, $num_errors, $num_reverted, $num_items_deleted, $num_ignored ) =
        C4::ImportBatch::BatchRevertRecords($id_import_batch);

    is( $num_reverted, 0, 'The record was not counted as reverted since it could not be decoded' );
    is( $num_errors,   1, 'The record with undecodable marcxml_old is reported as errored, not fatal to the batch' );

    $import_record->discard_changes;
    is( $import_record->status, 'error', 'The import record is flagged with an error status' );
    ok( $import_record->import_error, 'The decoding error is recorded for the user to see' );
};

subtest "BatchRevertRecords isolates a record that fails to restore without aborting the whole batch" => sub {
    plan tests => 6;

    my $import_batch = {
        matcher_id     => 5,
        template_id    => 5,
        branchcode     => 'QRT',
        overlay_action => 'replace',
        nomatch_action => 'create_new',
        item_action    => 'ignore',
        import_status  => 'imported',
        batch_type     => 'batch',
        file_name      => 'test.mrc',
        comments       => 'test',
        record_type    => 'biblio',
    };
    my $id_import_batch = C4::ImportBatch::AddImportBatch($import_batch);

    my $good_biblio = $builder->build_sample_biblio;
    my $bad_biblio  = $builder->build_sample_biblio;

    my $good_marc = MARC::Record->new;
    $good_marc->append_fields( MARC::Field->new( '245', '', '', 'a' => 'Good restored title' ) );
    my $bad_marc = MARC::Record->new;
    $bad_marc->append_fields( MARC::Field->new( '245', '', '', 'a' => 'Bad restored title' ) );

    my $good_import_record_id = AddBiblioToBatch( $id_import_batch, 0, $good_marc, 'UTF-8', 0 );
    my $bad_import_record_id  = AddBiblioToBatch( $id_import_batch, 1, $bad_marc,  'UTF-8', 0 );
    C4::ImportBatch::SetMatchedBiblionumber( $good_import_record_id, $good_biblio->biblionumber );
    C4::ImportBatch::SetMatchedBiblionumber( $bad_import_record_id,  $bad_biblio->biblionumber );

    my $good_import_record = Koha::Import::Records->find($good_import_record_id);
    $good_import_record->update(
        {
            status         => 'imported',
            overlay_status => 'match_applied',
            marcxml_old    => $good_marc->as_xml_record('MARC21'),
            encoding       => 'UTF-8',
        }
    );
    my $bad_import_record = Koha::Import::Records->find($bad_import_record_id);
    $bad_import_record->update(
        {
            status         => 'imported',
            overlay_status => 'match_applied',
            marcxml_old    => $bad_marc->as_xml_record('MARC21'),
            encoding       => 'UTF-8',
        }
    );

    my $mock_import = Test::MockModule->new("C4::ImportBatch");
    $mock_import->mock(
        ModBiblio => sub {
            my ( $record, $biblionumber, $frameworkcode, $options ) = @_;
            if ( $biblionumber == $bad_biblio->biblionumber ) {
                Koha::Exceptions::Metadata::Invalid->throw(
                    id             => undef,
                    biblionumber   => $biblionumber,
                    format         => 'marcxml',
                    schema         => 'MARC21',
                    decoding_error => 'Simulated unrecoverable metadata on restore',
                );
            }
            return $mock_import->original('ModBiblio')->( $record, $biblionumber, $frameworkcode, $options );
        }
    );

    my ( $num_deleted, $num_errors, $num_reverted, $num_items_deleted, $num_ignored ) =
        C4::ImportBatch::BatchRevertRecords($id_import_batch);

    is( $num_reverted, 1, 'Only the good record is counted as reverted' );
    is( $num_errors,   1, 'The record that failed to restore is reported as errored, not fatal to the batch' );

    $bad_import_record->discard_changes;
    is( $bad_import_record->status, 'error', 'The bad import record is flagged with an error status' );
    like(
        $bad_import_record->import_error,
        qr/Simulated unrecoverable metadata on restore/,
        'The decoding error is recorded so it can be shown to the user'
    );

    $good_import_record->discard_changes;
    is(
        $good_import_record->status, 'reverted',
        'The good import record in the same batch was still reverted despite the other one failing'
    );
    is(
        Koha::Biblios->find( $good_biblio->biblionumber )->metadata->record->subfield( '245', 'a' ),
        'Good restored title',
        'The good biblio was actually restored to its old metadata'
    );
};

subtest "Do not adjust biblionumber when replacing items during import" => sub {
    plan tests => 7;

    my $item1                     = $builder->build_sample_item;
    my $original_biblionumber     = $item1->biblionumber;
    my $original_biblioitemnumber = $item1->biblioitemnumber;
    my $item2                     = $builder->build_sample_item;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    my $import_item = $builder->build_object(
        {
            class => 'Koha::Import::Record::Items',
            value => {
                marcxml => qq{<?xml version="1.0" encoding="UTF-8"?>
<collection
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.loc.gov/MARC21/slim http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd"
  xmlns="http://www.loc.gov/MARC21/slim">

<record>
  <leader>00000    a              </leader>
  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="a">${\($library->branchcode)}</subfield>
    <subfield code="b">${\($library->branchcode)}</subfield>
    <subfield code="c">GEN</subfield>
    <subfield code="p">${\($item1->barcode)}</subfield>
    <subfield code="y">BK</subfield>
  </datafield>
</record>
</collection>
        },
            }
        }
    );

    isnt(
        $item1->homebranch, $library->branchcode,
        "Item's homebranch is currently not the same as our created branch's branchcode"
    );

    my ( $num_items_added, $num_items_replaced, $num_items_errored ) =
        C4::ImportBatch::_batchCommitItems( $import_item->import_record_id, $item2->biblionumber, 'replace' );

    $item1->discard_changes();

    is( $num_items_errored, 0, 'Item was replaced' );
    $import_item->discard_changes();
    is( $import_item->status,       'imported', 'Import was successful' );
    is( $import_item->import_error, undef,      'No error was reported' );

    is( $item1->biblionumber,     $original_biblionumber,     "Item's biblionumber has not changed" );
    is( $item1->biblioitemnumber, $original_biblioitemnumber, "Item's biblioitemnumber has not changed" );
    is( $item1->homebranch,       $library->branchcode,       "Item was overlaid successfully" );
};

sub get_import_record {
    my $id_import_batch = shift;
    return $dbh->do( 'SELECT * FROM import_records WHERE import_batch_id = ?', undef, $id_import_batch );
}

$schema->storage->txn_rollback;
