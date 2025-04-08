use Modern::Perl;

return {
    bug_number  => "xxxxx",
    description => "Add system preferences for OPAC",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)
                VALUES ('OpacFacetAccordion', '1', NULL, 'Enable the accordion facets mode', 'YesNo');
            }
        );
        say $out "Added OpacFacetAccordion syspref";

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)
                VALUES ('OpacFacetAccordionExpandedByDefault', '0', NULL, 'Expand accordions in the facets by default', 'YesNo');
            }
        );
        say $out "Added OpacFacetAccordionExpandedByDefault syspref";

    }
};
