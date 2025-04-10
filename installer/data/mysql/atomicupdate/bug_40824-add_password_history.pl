use Modern::Perl;

return {
    bug_number  => "40824",
    description => "Add password history feature",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Create password history table and add system preference if the table doesn't exist
        unless ( TableExists('borrower_password_history') ) {

            # Create the table
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS borrower_password_history (
                    id int(11) NOT NULL AUTO_INCREMENT,
                    borrowernumber int(11) NOT NULL,
                    password varchar(128) NOT NULL,
                    created_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    KEY borrowernumber (borrowernumber),
                    CONSTRAINT borrower_password_history_ibfk_1 FOREIGN KEY (borrowernumber) REFERENCES borrowers(borrowernumber) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );
            say $out "Created borrower_password_history table";

            # Add system preference
            $dbh->do(
                q{
                INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)
                VALUES ('PasswordHistoryCount','0','Number of previous passwords to check against when changing password','','Integer')
            }
            );
            say $out "Added new system preference 'PasswordHistoryCount'";
        }

        # Add password_history_count column to categories table if it doesn't exist
        unless ( column_exists( 'categories', 'password_history_count' ) ) {
            $dbh->do(
                q{
                ALTER TABLE categories
                ADD COLUMN password_history_count smallint(6) NULL DEFAULT NULL
                COMMENT 'Number of previous passwords to check against when changing password for this patron type'
            }
            );
            say $out "Added password_history_count column to categories table";
        }
    },
};
