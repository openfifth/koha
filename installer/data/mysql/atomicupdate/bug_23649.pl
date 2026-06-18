use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "23649",
    description => "Add search_field_value_boost table for per-value relevance weights",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
            CREATE TABLE IF NOT EXISTS `search_field_value_boost` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `search_field_id` int(11) NOT NULL COMMENT 'FK to search_field',
              `value` varchar(255) NOT NULL COMMENT 'the field value to boost',
              `weight` decimal(5,2) NOT NULL DEFAULT 1.00 COMMENT 'relevance multiplier applied when a document matches this value',
              PRIMARY KEY (`id`),
              UNIQUE KEY `search_field_value` (`search_field_id`,`value`(191)),
              CONSTRAINT `sfvb_ibfk_1` FOREIGN KEY (`search_field_id`) REFERENCES `search_field` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        }
        );

        say_success( $out, "Added new table 'search_field_value_boost'" );
    },
};
