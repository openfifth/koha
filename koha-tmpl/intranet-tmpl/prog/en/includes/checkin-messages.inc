[% FOREACH code IN messages.keys %]
    [% IF code == 'WasTransfered' %]
        <div class="alert alert-info">Item transferred to [% messages.TransferTo %]</div>
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
        <div class="alert alert-info">Transfer arrived from [% messages.TransferArrived %]</div>
    [% ELSIF code == 'TransferredRecall' %]
        <div class="alert alert-info">Recalled item has been transferred</div>
    [% ELSIF code == 'WrongTransfer' %]
        <div class="alert alert-warning">This item is still on transfer to [% messages.WrongTransfer %]</div>
    [% ELSIF code == 'Wrongbranch' %]
        <div class="alert alert-warning">This item cannot be returned to this branch</div>
    [% ELSIF code == 'UpdateLastSeenError' %]
        <div class="alert alert-warning">Error: Patron's last seen date could not be updated; see system logs.</div>
    [% ELSIF code.match('Transfer(To|Trigger)|WrongTransferItem|WasReturned|LostItem.+|ProcessingFeeRefunded') # ignore %]

    [% ELSIF code.match('ClaimAutoResolved|ReturnClaims') # ignored too for now %]

    [% ELSIF code == 'InBundle' # TODO %]

    [% ELSE # unexpected codes %]
        <div class="alert alert-warning">Received code [% code %] from AddReturn. Contact support.</div>
    [% END %]
[% END %]
