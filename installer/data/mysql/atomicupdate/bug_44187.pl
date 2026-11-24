use Modern::Perl;
use Koha::Installer::Output qw(say_success say_failure);

return {
    bug_number  => "44187",
    description => "Handle holds, items and notifications when a supplier cancels an order line by EDIFACT",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'EdifactCancelledItemNotForLoanValue',
                '',
                NULL,
                'Not for loan status given to an on-order item that cannot be deleted when a supplier cancels the order line by EDIFACT ORDRSP',
                'Choice'
            )
        }
        );

        say_success( $out, "Added new system preference 'EdifactCancelledItemNotForLoanValue'" );

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'EdifactOrdrspHoldCancellationReasons',
                '',
                NULL,
                'YAML mapping from the supplier reason code of an EDIFACT ORDRSP cancellation (for example 8B:OP) to the HOLD_CANCELLATION reason used to cancel the holds, with default for any other code',
                'Textarea'
            )
        }
        );
        say_success( $out, "Added new system preference 'EdifactOrdrspHoldCancellationReasons'" );

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'EdifactOrdrspCancelEmailNotice',
                '0',
                '0|AcquisitionsDefaultEmailAddress|EdifactOrdrspCancelEmailAddresses|KohaAdminEmailAddress',
                'Send a notification using the EDI_ORDRSP_CANCEL notice template when a supplier order response cancels order lines, or a cancellation cannot be applied, to the selected address',
                'Choice'
            )
        }
        );
        say_success( $out, "Added system preference 'EdifactOrdrspCancelEmailNotice'" );

        $dbh->do(
            q{
            INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
            VALUES (
                'EdifactOrdrspCancelEmailAddresses',
                '',
                NULL,
                'Comma-separated email addresses notified of order response cancellations when EdifactOrdrspCancelEmailNotice is set to specific email addresses',
                'Textarea'
            )
        }
        );
        say_success( $out, "Added system preference 'EdifactOrdrspCancelEmailAddresses'" );

        my $content = <<'END_LETTER';
[%- USE Koha -%]The supplier's order response [% filename %] has been processed.

Vendor: [% bookseller.name %] (ID: [% vendor_id %])
Order lines cancelled by the supplier: [% cancelled_count %]

[% FOREACH c IN cancellations -%]
* Order [% c.ordernumber %], basket [% c.basketname %]: [% c.title %] ([% c.reason %])
[%- IF c.holds_cancelled %]
    Holds cancelled: [% c.holds_cancelled %]
[%- END %]
[%- FOREACH n IN c.notes %]
    ! [% n %]
[%- END %]
[% END -%]
[% IF attention.size -%]
Needs your attention:
[% FOREACH a IN attention -%]
* [% a %]
[% END -%]
[% END -%]

View EDI message: [% Koha.Preference('staffClientBaseURL') %]/cgi-bin/koha/acqui/edimsg.pl?id=[% message_id | uri %]

This is an automated notification from your Koha system.
END_LETTER
        chomp $content;

        my $ok = $dbh->do(
            q{
            INSERT IGNORE INTO letter (module, code, branchcode, name, is_html, title, content, message_transport_type, lang)
            VALUES ('acquisition', 'EDI_ORDRSP_CANCEL', '', ?, 0, ?, ?, 'email', 'default')
        }, undef,
            'EDIFACT order response - order lines cancelled by the supplier',
            'EDIFACT order response: [% IF cancelled_count %][% cancelled_count %] order line(s) cancelled[% ELSE %]cancellation needs attention[% END %]',
            $content
        );
        if ($ok) {
            say_success( $out, "Added letter template 'EDI_ORDRSP_CANCEL'" );
        } else {
            say_failure( $out, "Failed to add letter template 'EDI_ORDRSP_CANCEL': " . $dbh->errstr );
        }
    },
};
