use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "31642",
    description => "Add three AV categories and values for HTML blocks",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
INSERT IGNORE INTO authorised_value_categories (category_name, is_system) VALUES
    ('ADD_CONT_HTML_OPAC_SYSTEM', 1),
    ('ADD_CONT_HTML_STAFF_SYSTEM', 1),
    ('ADD_CONT_HTML_CUSTOM', 0);
}
        );

        foreach my $block_location (
            'OpacNavRight',                  'opacheader',       'OpacCustomSearch', 'OpacMainUserBlock', 'opaccredits',
            'OpacLoginInstructions',         'OpacNav',          'OpacNavBottom',     'OpacSuggestionInstructions',
            'ArticleRequestsDisclaimerText', 'OpacMoreSearches', 'OpacMySummaryNote', 'OpacLibraryInfo',
            'OpacMaintenanceNotice',         'OPACResultsSidebar',   'OpacSuppressionMessage', 'SCOMainUserBlock',
            'SelfCheckInMainUserBlock',      'SelfCheckHelpMessage', 'CatalogConcernHelp',     'CatalogConcernTemplate',
            'CookieConsentBar',              'CookieConsentPopup',   'PatronSelfRegistrationAdditionalInstructions',
            'ILLModuleCopyrightClearance'
            )
        {
            $dbh->do(
                qq{
INSERT IGNORE INTO authorised_values ( category, authorised_value, lib, lib_opac )
VALUES ( 'ADD_CONT_HTML_OPAC_SYSTEM', '$block_location', '$block_location', '$block_location' )
            }
            );
        }

        foreach my $block_location (
            'IntranetmainUserblock', 'RoutingListNote',      'StaffAcquisitionsHome',
            'StaffAuthoritiesHome',  'StaffCataloguingHome', 'StaffListsHome', 'StaffLoginInstructions',
            'StaffPatronsHome',      'StaffPOSHome',         'StaffSerialsHome'
            )
        {
            $dbh->do(
                qq{
INSERT IGNORE INTO authorised_values ( category, authorised_value, lib, lib_opac )
VALUES ( 'ADD_CONT_HTML_STAFF_SYSTEM', '$block_location', '$block_location', '$block_location' )
            }
            );
        }
    },
};
