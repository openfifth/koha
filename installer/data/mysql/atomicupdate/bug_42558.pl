use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
return {
    bug_number  => "42558",
    description => "Update reservedate to datetime",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
            ALTER TABLE reserves MODIFY COLUMN reservedate DATETIME DEFAULT NULL COMMENT 'the date the hold was placed'
        }
        );
        say_success( $out, "Updated reserves.reservedate to datetime" );

        $dbh->do(
            q{
            ALTER TABLE old_reserves MODIFY COLUMN reservedate DATETIME DEFAULT NULL COMMENT 'the date the hold was placed'
        }
        );
        say_success( $out, "Updated old_reserves.reservedate to datetime" );

        $dbh->do(
            q{
            ALTER TABLE tmp_holdsqueue MODIFY COLUMN reservedate DATETIME DEFAULT NULL
        }
        );
        say_success( $out, "Updated tmp_holdsqueue.reservedate to datetime" );
    },
};
