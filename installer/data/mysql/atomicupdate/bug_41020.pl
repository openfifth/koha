use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41020",
    description => "Add file_transport_id to marc_order_accounts",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'marc_order_accounts', 'file_transport_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE `marc_order_accounts`
                  ADD COLUMN `file_transport_id` int(11) DEFAULT NULL AFTER `basket_name_field`,
                  ADD KEY `marc_order_accounts_file_transport_id` (`file_transport_id`),
                  ADD CONSTRAINT `marc_order_accounts_ibfk_file_transport`
                    FOREIGN KEY (`file_transport_id`)
                    REFERENCES `file_transports` (`file_transport_id`)
                    ON DELETE SET NULL
                    ON UPDATE CASCADE;
            }
            ) == 1 && say_success( $out, "Added column 'marc_order_accounts.file_transport_id'" );
        }

    },
};
