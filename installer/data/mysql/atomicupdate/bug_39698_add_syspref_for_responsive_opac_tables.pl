use Modern::Perl;

return {
    bug_number  => "xxxxx",
    description => "Add system preferences for responsive OPAC tables",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)
                VALUES ('OPACTableColExpandedByDefault', '0', NULL, 'Determines whether or not table rows are expanded by default on mobile', 'YesNo');
            }
        );
        say $out "Added OPACTableColExpandedByDefault syspref";

    }
};
