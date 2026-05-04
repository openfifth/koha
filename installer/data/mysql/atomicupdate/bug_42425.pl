use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "42425",
    description => "Add checkin_id FK to accountlines",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'accountlines', 'checkin_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE `accountlines`
                    ADD COLUMN `checkin_id` int(11) DEFAULT NULL
                        COMMENT 'foreign key from the checkins table if this accountline was created during a checkin'
                        AFTER `branchcode`,
                    ADD KEY `accountlines_ibfk_checkins` (`checkin_id`),
                    ADD CONSTRAINT `accountlines_ibfk_checkins`
                        FOREIGN KEY (`checkin_id`) REFERENCES `checkins` (`checkin_id`)
                        ON DELETE SET NULL ON UPDATE CASCADE
            }
            );

            say $out "Added checkin_id column to accountlines";
        }

        # Link accountlines that reference old_issues to their checkin
        my $linked = $dbh->do(
            q{
            UPDATE accountlines al
              JOIN checkins c ON c.checkout_id = al.old_issue_id
            SET al.checkin_id = c.checkin_id
            WHERE al.old_issue_id IS NOT NULL
              AND al.checkin_id IS NULL
        }
        );

        say $out "Linked $linked accountlines to checkin records" if $linked > 0;
    },
};
