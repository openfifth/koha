use Modern::Perl;
use Test::More tests => 4;
use Test::NoWarnings;

use t::lib::TestBuilder;
use File::Temp qw(tempfile);
use XML::Simple;

use C4::Installer qw( TableExists run_atomic_updates );
use Koha::Database;
use Koha::ShibbolethConfigs;
use Koha::ShibbolethFieldMappings;

my $schema = Koha::Database->new->schema;

subtest 'Migration from XML config' => sub {
    plan tests => 15;

    $schema->storage->txn_begin;

    my $dbh = C4::Context->dbh;

    Koha::ShibbolethConfigs->search()->delete;
    Koha::ShibbolethFieldMappings->search()->delete;
    $dbh->do(
        "DELETE FROM systempreferences WHERE variable IN ('ShibbolethAuthentication', 'staffShibOnly', 'OPACShibOnly')"
    );

    my $xml_content = <<'EOT';
<?xml version="1.0" encoding="UTF-8"?>
<yazgfs>
  <config>
    <useshibboleth>1</useshibboleth>
    <shibboleth>
      <autocreate>1</autocreate>
      <sync>1</sync>
      <welcome>1</welcome>
      <matchpoint>email</matchpoint>
      <mapping>
        <email is="mail"></email>
        <userid is="userid"></userid>
        <cardnumber is="id"></cardnumber>
        <firstname is="givenname"></firstname>
        <surname is="surname"></surname>
        <branchcode content="MAIN"></branchcode>
        <categorycode content="DEFAULT"></categorycode>
        <password is="digitalid"></password>
        <borrowernotes content="AUTOMATIC_USER"></borrowernotes>
      </mapping>
    </shibboleth>
  </config>
</yazgfs>
EOT

    my ( $fh, $filename ) = tempfile();
    print $fh $xml_content;
    close $fh;

    $schema->resultset('Systempreference')->update_or_create(
        {
            variable    => 'staffShibOnly',
            value       => 1,
            explanation => 'If ON enables shibboleth only authentication for the staff client',
            type        => 'YesNo'
        }
    );

    $schema->resultset('Systempreference')->update_or_create(
        {
            variable    => 'OPACShibOnly',
            value       => 1,
            explanation => 'If ON enables shibboleth only authentication for the opac',
            type        => 'YesNo'
        }
    );

    local $ENV{KOHA_CONF} = $filename;

    run_atomic_updates( ['bug_39224_add_shibboleth_tables.pl'] );

    ok( $dbh->selectrow_array(q{SHOW TABLES LIKE 'shibboleth_config'}), "shibboleth_config table exists" );
    ok(
        $dbh->selectrow_array(q{SHOW TABLES LIKE 'shibboleth_field_mappings'}),
        "shibboleth_field_mappings table exists"
    );

    my ($syspref_value) =
        $dbh->selectrow_array("SELECT value FROM systempreferences WHERE variable = 'ShibbolethAuthentication'");
    is( $syspref_value, 1, "ShibbolethAuthentication syspref created with correct value" );

    my $config = $dbh->selectrow_hashref("SELECT * FROM shibboleth_config");
    ok( $config, "Config row created" );
    is( $config->{force_opac_sso},  1, "OPACShibOnly migrated correctly" );
    is( $config->{force_staff_sso}, 1, "staffShibOnly migrated correctly" );
    is( $config->{autocreate},      1, "autocreate setting migrated" );
    is( $config->{sync},            1, "sync setting migrated" );
    is( $config->{welcome},         1, "welcome setting migrated" );

    my $old_prefs = $dbh->selectall_arrayref(
        "SELECT variable FROM systempreferences WHERE variable IN ('staffShibOnly','OPACShibOnly')");
    is( scalar @$old_prefs, 0, "Old sysprefs were removed" );

    my @mappings = Koha::ShibbolethFieldMappings->search()->as_list;
    is( scalar @mappings, 9, "All 9 field mappings migrated" );

    my $email_mapping = Koha::ShibbolethFieldMappings->find( { koha_field => 'email' } );
    is( $email_mapping->idp_field,     'mail', "email mapping IDP field correct" );
    is( $email_mapping->is_matchpoint, 1,      "email is matchpoint" );

    my $branchcode_mapping = Koha::ShibbolethFieldMappings->find( { koha_field => 'branchcode' } );
    is( $branchcode_mapping->default_content, 'MAIN', "branchcode default content correct" );
    is( $branchcode_mapping->idp_field,       undef,  "branchcode has no IDP field" );

    $schema->storage->txn_rollback;
};

subtest 'Idempotency - running migration twice' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $dbh = C4::Context->dbh;
    Koha::ShibbolethConfigs->search()->delete;
    Koha::ShibbolethFieldMappings->search()->delete;
    $dbh->do("DELETE FROM systempreferences WHERE variable = 'ShibbolethAuthentication'");

    my $xml_content = <<'EOT';
<?xml version="1.0" encoding="UTF-8"?>
<yazgfs>
  <config>
    <useshibboleth>1</useshibboleth>
    <shibboleth>
      <autocreate>1</autocreate>
      <sync>1</sync>
      <welcome>1</welcome>
      <matchpoint>email</matchpoint>
      <mapping>
        <email is="mail"></email>
        <userid is="userid"></userid>
      </mapping>
    </shibboleth>
  </config>
</yazgfs>
EOT

    my ( $fh, $filename ) = tempfile();
    print $fh $xml_content;
    close $fh;

    local $ENV{KOHA_CONF} = $filename;

    run_atomic_updates( ['bug_39224_add_shibboleth_tables.pl'] );

    my $config_count_before  = Koha::ShibbolethConfigs->count;
    my $mapping_count_before = Koha::ShibbolethFieldMappings->count;
    my ($syspref_count_before) =
        $dbh->selectrow_array("SELECT COUNT(*) FROM systempreferences WHERE variable = 'ShibbolethAuthentication'");

    run_atomic_updates( ['bug_39224_add_shibboleth_tables.pl'] );

    my $config_count_after  = Koha::ShibbolethConfigs->count;
    my $mapping_count_after = Koha::ShibbolethFieldMappings->count;
    my ($syspref_count_after) =
        $dbh->selectrow_array("SELECT COUNT(*) FROM systempreferences WHERE variable = 'ShibbolethAuthentication'");

    is( $config_count_after,  $config_count_before,  "Config row count unchanged after second run" );
    is( $mapping_count_after, $mapping_count_before, "Mapping row count unchanged after second run" );
    is( $syspref_count_after, $syspref_count_before, "Syspref count unchanged after second run" );

    my $config = Koha::ShibbolethConfigs->search()->single;
    ok( $config, "Config found after second run" );
    is( $config->autocreate, 1, "Config values still correct after second run" ) if $config;

    $schema->storage->txn_rollback;
};

subtest 'Migration without XML config or old sysprefs' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $dbh = C4::Context->dbh;
    Koha::ShibbolethConfigs->search()->delete;
    Koha::ShibbolethFieldMappings->search()->delete;
    $dbh->do(
        "DELETE FROM systempreferences WHERE variable IN ('ShibbolethAuthentication', 'staffShibOnly', 'OPACShibOnly')"
    );

    local $ENV{KOHA_CONF} = '/nonexistent/path.xml';

    run_atomic_updates( ['bug_39224_add_shibboleth_tables.pl'] );

    ok( $dbh->selectrow_array(q{SHOW TABLES LIKE 'shibboleth_config'}), "Tables created without XML" );

    my ($syspref_value) =
        $dbh->selectrow_array("SELECT value FROM systempreferences WHERE variable = 'ShibbolethAuthentication'");
    is( $syspref_value, 0, "ShibbolethAuthentication defaults to 0 without XML" );

    my $config_count = Koha::ShibbolethConfigs->count;
    is( $config_count, 0, "No config row created without XML or old sysprefs" );

    my $mapping_count = Koha::ShibbolethFieldMappings->count;
    is( $mapping_count, 0, "No field mappings created without XML" );

    $schema->storage->txn_rollback;
};
