use Modern::Perl;
use Koha::Installer::Output qw(say_info);

return {
    bug_number  => "41872",
    description => "Add itype, ccode table column bookings-to-collect",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO columns_settings
                (module, page, tablename, columnname, cannot_be_toggled, is_hidden)
                VALUES
                ("circ", "bookings", "bookings-to-collect", "item_item_type_id", 0, 0),
                ("circ", "bookings", "bookings-to-collect", "item_collection", 0, 0)
            }
        );

        say_info( $out, 'Added item_item_type_id, item_collection columns to bookings-to-collect datatable' );
    },
};
