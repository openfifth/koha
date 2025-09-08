use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "3492",
    description => "Migrate reservefee from categories to circulation rules",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( column_exists( 'categories', 'reservefee' ) ) {

            # Check if we have any existing reservefees to migrate
            my $existing_fees = $dbh->selectall_arrayref(
                q{
                SELECT categorycode, reservefee
                FROM categories
                WHERE reservefee IS NOT NULL AND reservefee > 0
            }, { Slice => {} }
            );

            if (@$existing_fees) {
                say_info(
                    $out,
                    "Migrating "
                        . scalar(@$existing_fees)
                        . " existing hold fees from categories to circulation rules..."
                );

                # Migrate existing reservefee values to circulation_rules
                my $insert_rule = $dbh->prepare(
                    q{
                    INSERT IGNORE INTO circulation_rules
                    (branchcode, categorycode, itemtype, rule_name, rule_value)
                    VALUES (NULL, ?, NULL, 'hold_fee', ?)
                }
                );

                my $migrated = 0;
                for my $fee (@$existing_fees) {
                    $insert_rule->execute( $fee->{categorycode}, $fee->{reservefee} );
                    if ( $insert_rule->rows ) {
                        $migrated++;
                    }
                }

                say_success( $out, "Successfully migrated $migrated hold fee rules to circulation_rules table." );

                if ( $migrated < @$existing_fees ) {
                    say_warning( $out, "Some rules may have already existed and were not overwritten." );
                }
            } else {
                say_info( $out, "No existing hold fees found in categories table to migrate." );
            }

            # Remove the deprecated reservefee column
            say_info( $out, "Removing deprecated reservefee column from categories table..." );
            $dbh->do(q{ALTER TABLE categories DROP COLUMN reservefee});
            say_success( $out, "Successfully removed reservefee column from categories table." );

        } else {
            say_info( $out, "The reservefee column has already been removed from the categories table." );
        }

        # Add the new system preference
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type) VALUES
            ('TitleHoldFeeStrategy', 'highest', 'highest|lowest|most_common', 'Strategy for calculating fees on title-level holds when items have different fees: highest = charge maximum fee, lowest = charge minimum fee, most_common = charge most frequently occurring fee', 'Choice')
        }
        );
        say_success( $out, "Added TitleHoldFeeStrategy system preference" );
        say_info( $out, "Hold fees can now be configured in Administration > Circulation and fine rules." );
        say_success( $out, "Migration complete: Hold fees are now fully managed through circulation rules." );
    },
};
