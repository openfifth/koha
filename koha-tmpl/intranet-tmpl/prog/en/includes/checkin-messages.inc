[% FOREACH code IN messages.keys %]
    [% IF code == 'WasTransfered' %]
        <div class="alert alert-info">Item transferred to [% messages.TransferTo | html %]</div>
    [% ELSIF code == 'NeedsTransfer' %]
        <div class="alert alert-warning">Item needs transfer</div>
    [% ELSIF code == 'RecallNeedsTransfer' %]
        <div class="alert alert-warning">Recall needs transfer</div>
    [% ELSIF code == 'NotIssued' %]
        <div class="alert alert-warning notissued">Item was not checked out</div>
    [% ELSIF code == 'WasLost' %]
        <div class="alert alert-info">Item was lost, now found</div>
    [% ELSIF code == 'withdrawn' %]
        <div class="alert alert-warning">Item is withdrawn</div>
    [% ELSIF code.match('Debarred|ForeverDebarred|PrevDebarred') %]
        <div class="alert alert-danger">Patron is restricted</div>
    [% ELSIF code == 'ResFound' %]
        <div class="alert alert-warning">Hold found</div>
    [% ELSIF code == 'RecallFound' %]
        <div class="alert alert-warning">Recall found</div>
    [% ELSIF code == 'BadBarcode' %]
        <div class="alert alert-warning">Bad barcode</div>
    [% ELSIF code == 'TransferArrived' %]
        <div class="alert alert-info">Transfer arrived from [% messages.TransferArrived | html %]</div>
    [% ELSIF code == 'TransferredRecall' %]
        <div class="alert alert-info">Recalled item has been transferred</div>
    [% ELSIF code == 'WrongTransfer' %]
        <div class="alert alert-warning">This item is still on transfer to [% messages.WrongTransfer | html %]</div>
    [% ELSIF code == 'Wrongbranch' %]
        <div class="alert alert-warning">This item cannot be returned to this branch</div>
    [% ELSIF code == 'UpdateLastSeenError' %]
        <div class="alert alert-warning">Error: Patron's last seen date could not be updated; see system logs.</div>
    [% ELSIF code == 'LostItemFeeRefunded' %]
        <div class="alert alert-info">Lost item fee refunded to the borrowing patron's account.</div>
    [% ELSIF code == 'LostItemFeeCharged' %]
        <div class="alert alert-info">Lost item fee refunded; a new overdue charge has been calculated and applied.</div>
    [% ELSIF code == 'LostItemFeeRestored' %]
        <div class="alert alert-info">Lost item fee refunded; a previously forgiven overdue fine has been reverted.</div>
    [% ELSIF code == 'LostItemPaymentNotRefunded' %]
        <div class="alert alert-warning">No refund was applied to the patron's account for the previously paid lost item fee as it was paid more than [% Koha.Preference('NoRefundOnLostFinesPaidAge') | html %] days ago.</div>
    [% ELSIF code == 'ProcessingFeeRefunded' %]
        <div class="alert alert-info">Lost item processing fee refunded to the borrowing patron's account.</div>
    [% ELSIF code == 'ClaimAutoResolved' %]
        <div class="alert alert-warning resolved-claim">The previously claimed returned item has been found, automatically resolving the associated claim.</div>
    [% ELSIF code == 'ReturnClaims' %]
        <div class="alert alert-warning return-claim">This item has been claimed as returned; please review the item's return claims tab.</div>
    [% ELSIF code == 'InBundle' %]
        <div class="alert alert-warning">
            Item belongs in bundle: [% IF messages.InBundle.biblio %][% messages.InBundle.biblio.title | html %][% END %]
            [% IF messages.InBundle.barcode %]([% messages.InBundle.barcode | html %])[% END %]
        </div>
    [% ELSIF code.match('Transfer(To|Trigger)|WrongTransferItem|WasReturned') # ignore %]

    [% ELSE # unexpected codes %]
        <div class="alert alert-warning">Received code [% code | html %] from AddReturn. Contact support.</div>
    [% END %]
[% END %]
