use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "37671",
    description => "Add PAYOUT notice template for POS refund receipts",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Add new PAYOUT letter template for POS
        $dbh->do(
            q{
            INSERT INTO letter (module, code, branchcode, name, is_html, title, content, message_transport_type, lang, updated_on)
            VALUES (
                'pos', 'PAYOUT', '', 'Point of sale payout receipt', 1, 'Payout receipt',
                '[% USE KohaDates %]
[% USE Branches %]
[% USE Price %]
[% USE AuthorisedValues %]
[% PROCESS "accounts.inc" %]
<table>
[% IF ( LibraryName ) %]
 <tr>
    <th colspan="2" class="centerednames">
        <h3>[% LibraryName | html %]</h3>
    </th>
 </tr>
[% END %]
 <tr>
    <th colspan="2" class="centerednames">
        <h2>[% Branches.GetName( debit.branchcode ) | html %]</h2>
    </th>
 </tr>
<tr>
    <th colspan="2" class="centerednames">
        <h3>[% debit.date | $KohaDates %]</h3>
</tr>
<tr>
  <td>Transaction ID: </td>
  <td>[% debit.accountlines_id %]</td>
</tr>
<tr>
  <td>Operator ID: </td>
  <td>[% debit.manager_id %]</td>
</tr>
<tr>
  <td>Payout type: </td>
  <td>[% AuthorisedValues.GetByCode( "PAYMENT_TYPE", debit.payment_type ) | html %]</td>
</tr>
 <tr></tr>
 <tr>
    <th colspan="2" class="centerednames">
        <h2><u>Refund Payout Receipt</u></h2>
    </th>
 </tr>
 <tr></tr>
 <tr>
    <th>Refund details</th>
    <th>Amount</th>
  </tr>

  [% FOREACH credit IN debit.credits %]
    <tr>
        <td>[% PROCESS account_type_description account=credit %]</td>
        <td>[% credit.amount * -1 | $Price %]</td>
    </tr>
    [% FOREACH offset IN credit.debit_offsets %]
      [% IF offset.debit %]
        <tr>
            <td>&nbsp;&nbsp;Refund for: [% PROCESS account_type_description account=offset.debit %] [% IF offset.debit.description %]([% offset.debit.description | html %])[% END %] [% IF offset.debit.itemnumber %]([% offset.debit.item.biblio.title | html %])[% END %]</td>
            <td>[% offset.amount | $Price %]</td>
        </tr>
      [% END %]
    [% END %]
  [% END %]

<tfoot>
  <tr class="highlight">
    <td>Total payout: </td>
    <td>[% debit.amount | $Price %]</td>
  </tr>
</tfoot>
</table>',
                'print', 'default', NOW()
            )
        }
        );

        say_success( $out, "Added new PAYOUT letter template for POS refunds" );
    },
};
