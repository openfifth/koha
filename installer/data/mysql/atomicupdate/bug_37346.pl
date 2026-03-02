use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "37346",
    description => "The VirtualShelf object should have an 'owner' accessor to return the related owner Koha::Patron",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'virtualshelves', 'owner_id' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE virtualshelves
                    RENAME COLUMN owner TO owner_id
                }
            );

            say_success $out, 'Renamed owner column to owner_id in virtualshelves table';
        }

        if ( foreign_key_exists( 'virtualshelves', 'virtualshelves_ibfk_1' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE virtualshelves
                    DROP FOREIGN KEY virtualshelves_ibfk_1
                }
            );
            $dbh->do(
                q{
                    ALTER TABLE virtualshelves
                    ADD CONSTRAINT virtualshelves_ibfk_1
                    FOREIGN KEY (`owner_id`)
                    REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE SET NULL
                    ON UPDATE SET NULL
                }
            );

            say_success $out, 'Dropped and recreated owner_id foreign key in virtualshelves';
        }
    },
};
