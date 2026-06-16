use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "42626",
    description => "Add aqvendor_allocations table and AcqVendorAllocations system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !TableExists('aqvendor_allocations') ) {
            $dbh->do(q{
                CREATE TABLE `aqvendor_allocations` (
                  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                  `budget_period_id` int(11) NOT NULL COMMENT 'budget period this allocation applies to (aqbudgetperiods.budget_period_id)',
                  `booksellerid` int(11) NOT NULL COMMENT 'vendor this allocation applies to (aqbooksellers.id)',
                  `allocation_amount` decimal(28,6) NOT NULL DEFAULT 0.000000 COMMENT 'maximum spend allowed for this vendor in this budget period',
                  `warn_at_percentage` decimal(6,4) DEFAULT 0.0000 COMMENT 'warn when spend reaches this percentage of allocation_amount',
                  `warn_at_amount` decimal(28,6) DEFAULT 0.000000 COMMENT 'warn when spend reaches this fixed amount',
                  PRIMARY KEY (`id`),
                  UNIQUE KEY `uq_vendor_period` (`budget_period_id`, `booksellerid`),
                  KEY `booksellerid` (`booksellerid`),
                  CONSTRAINT `aqva_fk_period` FOREIGN KEY (`budget_period_id`)
                    REFERENCES `aqbudgetperiods` (`budget_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `aqva_fk_vendor` FOREIGN KEY (`booksellerid`)
                    REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            });
            say_success( $out, "Added table aqvendor_allocations" );
        } else {
            say_info( $out, "Table aqvendor_allocations already exists" );
        }

        $dbh->do(q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES ('AcqVendorAllocations', '0', '', 'If enabled, allows setting maximum spend allocations per vendor per budget period, with warnings at order time when limits are approached or exceeded.', 'YesNo')
        });
        say_success( $out, "Added system preference AcqVendorAllocations" );

        say_success( $out, "Done" );
    },
};
