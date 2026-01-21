use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "39658",
    description => "Add patron account linking feature for multi-library patrons",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Create the patron_account_links table
        unless ( TableExists('patron_account_links') ) {
            $dbh->do(
                q{
                CREATE TABLE `patron_account_links` (
                    `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `link_group_id` int(11) NOT NULL COMMENT 'groups linked accounts together',
                    `borrowernumber` int(11) NOT NULL COMMENT 'foreign key to borrowers table',
                    `created_on` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'when the link was created',
                    PRIMARY KEY (`id`),
                    UNIQUE KEY `borrowernumber` (`borrowernumber`),
                    KEY `link_group_id` (`link_group_id`),
                    CONSTRAINT `patron_account_links_ibfk_1` FOREIGN KEY (`borrowernumber`)
                        REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );
            say_success( $out, "Added new table 'patron_account_links'" );
        }

        # Add system preferences
        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value)
            VALUES ('EnablePatronAccountLinking', '0')
        }
        );
        say_success( $out, "Added new system preference 'EnablePatronAccountLinking'" );

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value)
            VALUES ('NoIssuesChargeLinkedAccounts', '')
        }
        );
        say_success( $out, "Added new system preference 'NoIssuesChargeLinkedAccounts'" );

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value)
            VALUES ('AllowLinkedAccountHoldPickup', '0')
        }
        );
        say_success( $out, "Added new system preference 'AllowLinkedAccountHoldPickup'" );
    },
};
