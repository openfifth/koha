use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "37762",
    description => "Add tables for ISO18626 ILL support",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !TableExists('iso18626_requesting_agencies') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `iso18626_requesting_agencies` (
                  `iso18626_requesting_agency_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal requesting agency number',
                  `name` varchar(80) DEFAULT NULL COMMENT 'Requesting agency name',
                  `borrowernumber` int(11) NOT NULL COMMENT 'foreign key, linking this to the borrowers table (ILL partner patron)',
                  `type` enum('DNUCNI','ICOLC','ISIL') NOT NULL COMMENT 'ISO18626 agency type',
                  `account_id` varchar(80) NOT NULL COMMENT 'Authentication: Requesting agency account ID',
                  `securityCode` varchar(80) NOT NULL COMMENT 'Authentication: Requesting agency security code',
                  `callback_endpoint` mediumtext NOT NULL COMMENT 'Callback endpoint to send messages back to',
                  PRIMARY KEY (`iso18626_requesting_agency_id`),
                  UNIQUE KEY `uniq_borrowernumber` (`borrowernumber`),
                  UNIQUE KEY `uniq_account_id` (`account_id`),
                  KEY `iso18626_requesting_agencies_bnfk` (`borrowernumber`),
                  CONSTRAINT `iso18626_requesting_agencies_bnfk` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            say_success( $out, "Added new table 'iso18626_requesting_agencies'" );
        }

        if ( !TableExists('iso18626_requests') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `iso18626_requests` (
                  `iso18626_request_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal request number',
                  `supplyingAgencyId` varchar(80) DEFAULT NULL COMMENT 'Supplying agency ID',
                  `iso18626_requesting_agency_id` int(11) NOT NULL COMMENT 'Associated ISO18626 requesting agency',
                  `created_on` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Date and time the request was created',
                  `updated_on` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Date and time the request was last updated',
                  `requestingAgencyRequestId` varchar(80) DEFAULT NULL COMMENT 'Requesting agency request ID or number',
                  `status` enum('RequestReceived','ExpectToSupply','WillSupply','Loaned', 'Overdue', 'Recalled', 'RetryPossible', 'Unfilled', 'HoldReturn', 'ReleaseHoldReturn', 'CopyCompleted', 'LoanCompleted', 'CompletedWithoutReturn', 'Cancelled') DEFAULT 'RequestReceived' COMMENT 'Current ISO18626 status of request',
                  `service_type` enum('Copy','Loan','CopyOrLoan') NOT NULL COMMENT 'ISO18626 service type',
                  `pending_requesting_agency_action` enum('Cancel','Renew') DEFAULT NULL COMMENT 'ISO18626 Requesting Agency action that requires a manual response (yes or no)',
                  `hold_id` int(11) DEFAULT NULL COMMENT 'ID of the hold related to this ISO18626 request',
                  `issue_id` int(11) DEFAULT NULL COMMENT 'ID of the checkout related to this ISO18626 request',
                  `biblio_id` int(11) DEFAULT NULL COMMENT 'ID of the biblio related to this ISO18626 request',
                  PRIMARY KEY (`iso18626_request_id`),
                  UNIQUE KEY `uniq_reserve_id` (`hold_id`),
                  UNIQUE KEY `uniq_issue_id` (`issue_id`),
                  KEY `iso18626_bibfk` (`biblio_id`),
                  KEY `iso18626_rafk` (`iso18626_requesting_agency_id`),
                  CONSTRAINT `uniq_reserve_id` FOREIGN KEY (`hold_id`) REFERENCES `reserves` (`reserve_id`) ON DELETE SET NULL ON UPDATE CASCADE,
                  CONSTRAINT `uniq_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `issues` (`issue_id`) ON DELETE SET NULL ON UPDATE CASCADE,
                  CONSTRAINT `iso18626_bibfk` FOREIGN KEY (`biblio_id`) REFERENCES `biblio` (`biblionumber`) ON DELETE SET NULL ON UPDATE CASCADE,
                  CONSTRAINT `iso18626_rafk` FOREIGN KEY (`iso18626_requesting_agency_id`) REFERENCES `iso18626_requesting_agencies` (`iso18626_requesting_agency_id`) ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            say_success( $out, "Added new table 'iso18626_requests'" );
        }

        if ( !TableExists('iso18626_messages') ) {
            $dbh->do(
                q{
                CREATE TABLE IF NOT EXISTS `iso18626_messages` (
                  `iso18626_message_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal message number',
                  `iso18626_request_id` int(11) NOT NULL COMMENT 'Associated ISO18626 request',
                  `content` mediumtext NOT NULL COMMENT 'Message content (XML)',
                  `type` enum('request','requestConfirmation','supplyingAgencyMessage','supplyingAgencyMessageConfirmation','requestingAgencyMessage','requestingAgencyMessageConfirmation') NOT NULL COMMENT 'ISO18626 message type',
                  `timestamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                  PRIMARY KEY (`iso18626_message_id`),
                  KEY `iso18626_messages_rfk` (`iso18626_request_id`),
                  CONSTRAINT `iso18626_messages_rfk` FOREIGN KEY (`iso18626_request_id`) REFERENCES `iso18626_requests` (`iso18626_request_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            say_success( $out, "Added new table 'iso18626_messages'" );
        }

    },
};
