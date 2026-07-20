use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "43141",
    description => "Add ill_type_disclaimer_prompts table and ill_disclaimer messaging preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('ill_type_disclaimer_prompts') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS ill_type_disclaimer_prompts (
                  `uuid` varchar(128) NOT NULL COMMENT 'a unique token for this prompt',
                  `patron_id` int(11) NOT NULL COMMENT 'Patron this disclaimer prompt is for',
                  `illrequest_id` bigint(20) unsigned NOT NULL COMMENT 'ILL request this disclaimer prompt is for',
                  `date_prompted` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'when this prompt was created',
                  `date_replied` timestamp DEFAULT NULL COMMENT 'if non-null, when this prompt was replied to',
                  `valid_until` timestamp NOT NULL COMMENT 'when this prompt expires',

                  PRIMARY KEY (`uuid`),
                  UNIQUE KEY `ill_type_disclaimer_uniq` (`patron_id`, `illrequest_id`),
                  CONSTRAINT `ill_type_disclaimer_prompts_fk_patron_id` FOREIGN KEY (`patron_id`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `ill_type_disclaimer_prompts_fk_illrequest_id` FOREIGN KEY (`illrequest_id`) REFERENCES `illrequests` (`illrequest_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );
            say_success( $out, 'Created ill_type_disclaimer_prompts table' );
        }
    },
};
