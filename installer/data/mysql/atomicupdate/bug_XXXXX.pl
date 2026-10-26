use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "XXXXX",
    description => "Add ill_documents table and iso18626_requests.received_on",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('ill_documents') ) {
            $dbh->do(
                q{
                CREATE TABLE `ill_documents` (
                  `ill_document_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Internal document number',
                  `iso18626_request_id` int(11) DEFAULT NULL COMMENT 'Associated ISO18626 request, for documents supplied to other libraries',
                  `illrequest_id` bigint(20) unsigned DEFAULT NULL COMMENT 'Associated ILL request, for documents delivered to patrons',
                  `file_name` varchar(255) NOT NULL COMMENT 'File name',
                  `file_type` varchar(255) NOT NULL COMMENT 'MIME type of the file',
                  `file_content` longblob NOT NULL COMMENT 'File content',
                  `token` varchar(36) NOT NULL COMMENT 'Unique token used to download the document without authentication',
                  `uploaded_on` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Date and time the document was uploaded',
                  `downloaded_on` datetime DEFAULT NULL COMMENT 'Date and time the document was first downloaded by the patron',
                  `download_count` int(11) NOT NULL DEFAULT 0 COMMENT 'Number of times the document was downloaded by the patron',
                  PRIMARY KEY (`ill_document_id`),
                  UNIQUE KEY `token` (`token`),
                  KEY `ill_documents_iso18626_request_fk` (`iso18626_request_id`),
                  KEY `ill_documents_illrequest_fk` (`illrequest_id`),
                  CONSTRAINT `ill_documents_iso18626_request_fk` FOREIGN KEY (`iso18626_request_id`) REFERENCES `iso18626_requests` (`iso18626_request_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `ill_documents_illrequest_fk` FOREIGN KEY (`illrequest_id`) REFERENCES `illrequests` (`illrequest_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            }
            );
            say $out "Added new table 'ill_documents'";
        }

        unless ( column_exists( 'iso18626_requests', 'received_on' ) ) {
            $dbh->do(
                q{
                ALTER TABLE iso18626_requests
                ADD COLUMN `received_on` datetime DEFAULT NULL COMMENT 'Date and time the requesting agency confirmed receipt'
                AFTER `pending_requesting_agency_action`
            }
            );
            say $out "Added column 'iso18626_requests.received_on'";
        }
    },
};
