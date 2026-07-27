use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "8214",
    description => "Add a bound with functionality",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('item_biblio_links') ) {
            $dbh->do(
                q{
                CREATE TABLE `item_biblio_links` (
                  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'id for the item/biblio link',
                  `itemnumber` int(11) NOT NULL COMMENT 'link to the item',
                  `biblionumber` int(11) NOT NULL COMMENT 'link to the bibliographic record',
                  `link_type` varchar(80) NOT NULL COMMENT 'type of link, from authorised value category ITEM_BIBLIO_LINK_TYPE (e.g. binding, analytic)',
                  `display_order` int(11) DEFAULT NULL COMMENT 'optional explicit ordering among links, NULL means no explicit order',
                  `created_on` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'time and date the link was created',
                  PRIMARY KEY (`id`),
                  UNIQUE KEY `item_biblio_links_uniq_1` (`itemnumber`,`biblionumber`),
                  KEY `item_biblio_links_ibfk_2` (`biblionumber`),
                  CONSTRAINT `item_biblio_links_ibfk_1` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `item_biblio_links_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );
            say_success( $out, "Added new table 'item_biblio_links'" );
        }

        $dbh->do(
            q{
            INSERT IGNORE INTO authorised_value_categories (category_name, is_system)
            VALUES ('ITEM_BIBLIO_LINK_TYPE', 1)
        }
        );
        say_success( $out, "Added new authorised value category 'ITEM_BIBLIO_LINK_TYPE'" );

        $dbh->do(
            q{
            INSERT IGNORE INTO authorised_values (category, authorised_value, lib, lib_opac)
            VALUES
                ('ITEM_BIBLIO_LINK_TYPE', 'binding', 'Bound-with', 'Bound-with'),
                ('ITEM_BIBLIO_LINK_TYPE', 'analytic', 'Analytic', 'Analytic')
        }
        );
        say_success( $out, "Added authorised values 'binding' and 'analytic' to category 'ITEM_BIBLIO_LINK_TYPE'" );
    },
};
