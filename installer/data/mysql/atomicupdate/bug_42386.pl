use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "42386",
    description => "Update club_holds_to_patron_holds.error_code ENUM to snake_case",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Step 1: Expand ENUM to accept both old and new values
        $dbh->do(
            q{
            ALTER TABLE club_holds_to_patron_holds
            MODIFY COLUMN error_code
            ENUM(
                'damaged',
                'ageRestricted','age_restricted',
                'itemAlreadyOnHold','item_already_on_hold',
                'tooManyHoldsForThisRecord','too_many_holds_for_this_record',
                'tooManyReservesToday','too_many_reserves_today',
                'tooManyReserves','too_many_reserves',
                'notReservable','not_reservable',
                'cannotReserveFromOtherBranches','cannot_reserve_from_other_branches',
                'libraryNotFound','library_not_found',
                'libraryNotPickupLocation','library_not_pickup_location',
                'cannotBeTransferred','cannot_be_transferred',
                'noReservesAllowed','no_reserves_allowed'
            ) DEFAULT NULL
        }
        );

        # Step 2: Migrate existing data
        my %map = (
            ageRestricted                  => 'age_restricted',
            itemAlreadyOnHold              => 'item_already_on_hold',
            tooManyHoldsForThisRecord      => 'too_many_holds_for_this_record',
            tooManyReservesToday           => 'too_many_reserves_today',
            tooManyReserves                => 'too_many_reserves',
            notReservable                  => 'not_reservable',
            cannotReserveFromOtherBranches => 'cannot_reserve_from_other_branches',
            libraryNotFound                => 'library_not_found',
            libraryNotPickupLocation       => 'library_not_pickup_location',
            cannotBeTransferred            => 'cannot_be_transferred',
            noReservesAllowed              => 'no_reserves_allowed',
        );

        my $sth = $dbh->prepare(
            q{
            UPDATE club_holds_to_patron_holds SET error_code = ? WHERE error_code = ?
        }
        );
        for my $old ( keys %map ) {
            $sth->execute( $map{$old}, $old );
        }

        # Step 3: Shrink ENUM to only snake_case values
        $dbh->do(
            q{
            ALTER TABLE club_holds_to_patron_holds
            MODIFY COLUMN error_code
            ENUM(
                'damaged',
                'age_restricted',
                'item_already_on_hold',
                'too_many_holds_for_this_record',
                'too_many_reserves_today',
                'too_many_reserves',
                'not_reservable',
                'cannot_reserve_from_other_branches',
                'library_not_found',
                'library_not_pickup_location',
                'cannot_be_transferred',
                'no_reserves_allowed'
            ) DEFAULT NULL
        }
        );

        say_success( $out, "Updated column 'club_holds_to_patron_holds.error_code' to snake_case values" );
    },
};
