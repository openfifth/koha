use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "todo",
    description => "Anonymous catalog concerns",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(q{INSERT IGNORE INTO systempreferences (variable,value) VALUES ('OpacAnonCatalogConcerns', '0')});
        $dbh->do(q{INSERT IGNORE INTO systempreferences (variable,value) VALUES ('OpacAnonCatalogConcernsEmail', '')});

        say_success( $out, "Added OpacAnonCatalogConcerns system preference" );

        $dbh->do(
            q{
ALTER TABLE tickets
MODIFY COLUMN `reporter_id` int(11) DEFAULT NULL COMMENT 'id of the patron who reported the ticket'
}
        );

        unless ( column_exists( 'tickets', 'reporter_email' ) ) {
            $dbh->do(
                q{
ALTER TABLE tickets
ADD COLUMN `reporter_email` LONGTEXT DEFAULT NULL COMMENT 'the reporter''s email address for anonymous tickets' AFTER `reporter_id`
}
            );
        }

        unless ( column_exists( 'tickets', 'verify_uuid' ) ) {
            $dbh->do(
                q{
ALTER TABLE tickets
ADD COLUMN `verify_uuid` varchar(128) NULL COMMENT 'a unique string for verifying an anonymous ticket',
ADD UNIQUE KEY `ticket_uuid_uniq` (`verify_uuid`)
}
            );

        }

        $dbh->do(
            q{INSERT IGNORE INTO letter(module, code, branchcode, name, is_html, title, content, message_transport_type, lang) VALUES ('catalogue', 'TICKET_VERIFY', '', 'Concern requires verification', 0, 'Catalog concern requires verification', "[%- PROCESS 'html_helpers.inc' -%]\nDear user,<br>\n<br>\nA concern reported against [%- INCLUDE 'biblio-title.inc' biblio=ticket.biblio link = 0 -%] requires verification.<br>\nIf you reported this concern, please verify it at the following address:<br>\n[% ticket_verification_link %]<br>\n<br>\nThank you", 'email', 'default');}
        );
    },
};
