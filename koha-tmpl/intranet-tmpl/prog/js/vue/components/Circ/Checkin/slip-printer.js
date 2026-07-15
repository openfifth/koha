/**
 * Utility functions for printing slips from the Vue checkin UI.
 * Each function opens a popup window pointing to the appropriate Koha slip endpoint.
 */

const SLIP_WINDOW_OPTIONS =
    "width=750,height=500,toolbar=no,location=no,status=no,menubar=no,scrollbars=yes,resizable=yes";

export function printHoldSlip(reserveId) {
    window.open(
        `/cgi-bin/koha/circ/hold-transfer-slip.pl?reserve_id=${reserveId}`,
        "slip_window",
        SLIP_WINDOW_OPTIONS
    );
}

export function printTransferSlip(itemId, branchcode) {
    window.open(
        `/cgi-bin/koha/circ/transfer-slip.pl?transferitem=${itemId}&branchcode=${branchcode}&op=slip`,
        "slip_window",
        SLIP_WINDOW_OPTIONS
    );
}

export function printCheckinSlip(borrowernumber) {
    window.open(
        `/cgi-bin/koha/circ/circulation.pl?borrowernumber=${borrowernumber}&print=qslip`,
        "slip_window",
        SLIP_WINDOW_OPTIONS
    );
}
