use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41091",
    description => "Add ISO18626 supplying agencies and log ISO18626 messages for ILL requests",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('iso18626_supplying_agencies') ) {
            $dbh->do(
                q{
                CREATE TABLE `iso18626_supplying_agencies` (
                  `iso18626_supplying_agency_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal supplying agency number',
                  `name` varchar(80) DEFAULT NULL COMMENT 'Supplying agency name',
                  `type` enum('DNUCNI','ICOLC','ISIL') NOT NULL COMMENT 'ISO18626 agency ID type',
                  `agency_id` varchar(80) NOT NULL COMMENT 'ISO18626 agency ID of the supplying agency',
                  `account_id` varchar(80) NOT NULL COMMENT 'Authentication: account ID this Koha uses with the supplying agency',
                  `securityCode` varchar(80) NOT NULL COMMENT 'Authentication: security code this Koha uses with the supplying agency',
                  `endpoint` mediumtext NOT NULL COMMENT 'ISO18626 endpoint of the supplying agency',
                  PRIMARY KEY (`iso18626_supplying_agency_id`),
                  UNIQUE KEY `uniq_agency_id` (`type`,`agency_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say $out "Added new table 'iso18626_supplying_agencies'";
        }

        unless ( column_exists( 'iso18626_messages', 'illrequest_id' ) ) {
            $dbh->do(
                q{
                ALTER TABLE iso18626_messages
                    MODIFY COLUMN `iso18626_request_id` int(11) DEFAULT NULL COMMENT 'Associated ISO18626 request (when this Koha is the supplying agency)',
                    ADD COLUMN `illrequest_id` bigint(20) unsigned DEFAULT NULL COMMENT 'Associated ILL request (when this Koha is the requesting agency)' AFTER `iso18626_request_id`,
                    ADD KEY `iso18626_messages_illfk` (`illrequest_id`),
                    ADD CONSTRAINT `iso18626_messages_illfk` FOREIGN KEY (`illrequest_id`) REFERENCES `illrequests` (`illrequest_id`) ON DELETE CASCADE ON UPDATE CASCADE
            }
            );

            say $out "Added column 'iso18626_messages.illrequest_id'";
            say $out "Updated column 'iso18626_messages.iso18626_request_id' to allow NULL";
        }
    },
};
