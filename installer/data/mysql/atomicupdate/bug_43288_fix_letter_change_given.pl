use Modern::Perl;

return {
    bug_number  => "43288",
    description => "Fix stale 'change_given' variable references in stored notice templates",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Bug 43288 (community) fixes members/pay.tt, paycollect.tt, and
        # boraccount.tt to send change= instead of change_given= when opening
        # printfeercpt.pl, matching what printfeercpt.pl's substitute hash and
        # the default ACCOUNT_CREDIT/CREDIT_* notices have always used
        # ([% change | $Price %]). Any locally customised notice content that
        # was hand-edited to reference [% change_given %] - matching the
        # variable name used everywhere else in the pay/writeoff flow - would
        # already have been silently blank, since printfeercpt.pl never
        # populated that key. Normalize any such stored content to the
        # variable name printfeercpt.pl actually populates.
        #
        # Uses INSTR() rather than LIKE for detection: '_' is a LIKE wildcard
        # matching any single character, so LIKE '%change_given%' also
        # matches unrelated prose such as the "Change given:" label already
        # present in these notices. INSTR() does a literal substring search,
        # so it only matches the real [% change_given %] tag.
        #
        # Scans every letter code rather than a fixed list, since local
        # customisations may have added their own receipt/credit notices.
        my @patterns = (
            [ '[% change_given',       '[% change' ],
            [ '[%change_given',        '[%change' ],
            [ '[%  change_given',      '[%  change' ],
            [ 'change_given | $Price', 'change | $Price' ],
            [ 'change_given|$Price',   'change|$Price' ],
        );

        my $affected_codes =
            $dbh->selectcol_arrayref("SELECT DISTINCT code FROM letter WHERE INSTR(content, '[% change_given') > 0");

        my $total_updated = 0;

        foreach my $code (@$affected_codes) {
            my $code_updated = 0;

            foreach my $pattern (@patterns) {
                my ( $old, $new ) = @$pattern;

                my $sth = $dbh->prepare(
                    "UPDATE letter SET content = REPLACE(content, ?, ?) WHERE code = ? AND INSTR(content, ?) > 0");
                my $affected = $sth->execute( $old, $new, $code, $old );
                $code_updated += $affected if $affected && $affected > 0;
            }

            if ( $code_updated > 0 ) {
                say $out "Updated $code_updated '$code' notice template(s) to use 'change' instead of 'change_given'";
                $total_updated += $code_updated;
            }
        }

        if ( $total_updated == 0 ) {
            say $out "No stored notice templates referenced '[% change_given' - nothing to update";
        } else {
            say $out
                "Successfully converted all '[% change_given' references to '[% change' in stored notice templates";
        }
    },
};
