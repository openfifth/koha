use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "36506",
    description => "Move itemtype processing fees to the circulation rules",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( column_exists( 'itemtypes', 'processfee' ) ) {
            my $existing_fees = $dbh->selectall_arrayref(
                q|SELECT itemtype, processfee FROM itemtypes WHERE processfee IS NOT NULL|,
                { Slice => {} }
            );
            foreach my $existing_fee ( @{$existing_fees} ) {
                my $itemtype      = $existing_fee->{itemtype};
                my $fee           = $existing_fee->{processfee};
                my $existing_rule = $dbh->selectall_arrayref(
                    q|SELECT * FROM circulation_rules WHERE branchcode IS NULL AND categorycode IS NULL
                    AND rule_name = "lost_item_processing_fee" AND itemtype = ?|, undef, $itemtype
                );
                if ( @{$existing_rule} ) {
                    say_warning( $out, "Existing default rule for $itemtype found, not moving value from itemtypes" );
                    next;
                }
                $dbh->do(
                    q{
                    INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value )
                    VALUES ( NULL, NULL, ?, "lost_item_processing_fee", ? )
                }, undef, $itemtype, $fee
                );
            }
            say $out "Moved existing processing fees from itemtypes to circulation rules";

            $dbh->do('ALTER TABLE itemtypes DROP COLUMN processfee');
            say $out "Removed existing processfee column from itemtypes";
        }

    },
};
