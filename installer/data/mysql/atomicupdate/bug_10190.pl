use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "10190",
    description => "Migrate overduerules to circulation_rules",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # This script pulls data from these tables then drops them.
        # Skip silently if they no longer exist (e.g. fresh install or already migrated).
        if ( !TableExists('overduerules_transport_types') || !TableExists('overduerules') ) {
            say_info( $out, "Tables overduerules / overduerules_transport_types not found, skipping migration" );
            return;
        }

        # Remove the tools sub-permission for notice triggers; access is now
        # controlled by parameters/manage_circ_rules instead.
        # user_permissions rows are cleaned up automatically via ON DELETE CASCADE.
        $dbh->do(q|DELETE FROM permissions WHERE code = 'edit_notice_status_triggers'|);
        say_success( $out, "Removed deprecated permission 'edit_notice_status_triggers'" );

        # Fetch all explicit overdue rules with their transport types.
        # No phantom rows are added - only rules that were explicitly configured are migrated.
        my $rules = $dbh->selectall_arrayref(
            q|
            SELECT
                o.branchcode,
                o.categorycode,
                o.delay1,
                o.letter1,
                o.debarred1,
                o.delay2,
                o.letter2,
                o.debarred2,
                o.delay3,
                o.letter3,
                o.debarred3,
                GROUP_CONCAT(
                    CASE WHEN ott.letternumber = 1 THEN ott.message_transport_type END
                    ORDER BY ott.message_transport_type ASC
                ) AS mtt_1,
                GROUP_CONCAT(
                    CASE WHEN ott.letternumber = 2 THEN ott.message_transport_type END
                    ORDER BY ott.message_transport_type ASC
                ) AS mtt_2,
                GROUP_CONCAT(
                    CASE WHEN ott.letternumber = 3 THEN ott.message_transport_type END
                    ORDER BY ott.message_transport_type ASC
                ) AS mtt_3
            FROM
                overduerules o
            LEFT JOIN
                overduerules_transport_types ott ON o.overduerules_id = ott.overduerules_id
            GROUP BY
                o.overduerules_id,
                o.branchcode,
                o.categorycode,
                o.delay1,
                o.letter1,
                o.debarred1,
                o.delay2,
                o.letter2,
                o.debarred2,
                o.delay3,
                o.letter3,
                o.debarred3
            |,
            { Slice => {} }
        );

        my $insert = $dbh->prepare(
            "INSERT IGNORE INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value) VALUES (?, ?, ?, ?, ?)"
        );

        my $migrated = 0;

        for my $rule ( @{$rules} ) {

            # In the old system branchcode='' is the global/default library.
            # In circulation_rules this is represented as branchcode=NULL.
            my $branchcode   = $rule->{branchcode}   || undef;
            my $categorycode = $rule->{categorycode} || undef;
            my $itemtype     = undef;

            my $context_label = ( $branchcode // '*' ) . ':' . ( $categorycode // '*' );

            foreach my $i ( 1 .. 3 ) {
                my $delay    = $rule->{"delay$i"};
                my $notice   = $rule->{"letter$i"};
                my $mtt      = $rule->{"mtt_$i"};
                my $restrict = $rule->{"debarred$i"};

                # A zero or null delay means this trigger was not configured in the old system.
                # Only migrate explicitly configured triggers.
                next unless defined $delay && $delay > 0;

                say $out "Migrating trigger $i for $context_label (delay=$delay)";

                $insert->execute( $branchcode, $categorycode, $itemtype, "overdue_${i}_delay", $delay );

                if ($notice) {
                    $insert->execute( $branchcode, $categorycode, $itemtype, "overdue_${i}_notice", $notice );
                }

                if ($mtt) {
                    $insert->execute( $branchcode, $categorycode, $itemtype, "overdue_${i}_mtt", $mtt );
                }

                # Only insert restrict when explicitly enabled (=1); absence defaults to no restriction.
                if ($restrict) {
                    $insert->execute( $branchcode, $categorycode, $itemtype, "overdue_${i}_restrict", $restrict );
                }

                $migrated++;
            }
        }

        say_success( $out, "Migrated $migrated trigger(s) from overduerules to circulation_rules" );

        $dbh->do(q|DROP TABLE overduerules_transport_types|);
        $dbh->do(q|DROP TABLE overduerules|);
    }
};
