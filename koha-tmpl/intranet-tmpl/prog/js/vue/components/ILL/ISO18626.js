import { $__ } from "@koha-vue/i18n";

export function ISO18626() {
    const getCodesForElement = element => {
        const codes = [
            {
                element: "courierName",
                values: [
                    {
                        value: "DB Schenker",
                        description: $__("DB Schenker"),
                    },
                    {
                        value: "DHL",
                        description: $__("DHL"),
                    },
                    {
                        value: "Fedex",
                        description: $__("Fedex"),
                    },
                    {
                        value: "PostNord AB",
                        description: $__("PostNord AB"),
                    },
                    {
                        value: "UPS",
                        description: $__("UPS"),
                    },
                ],
            },
            {
                element: "deliveryMethod",
                values: [
                    {
                        value: "ArticleExchange",
                        description: $__("Article Exchange"),
                    },
                    {
                        value: "Courier",
                        description: $__("Courier"),
                    },
                    {
                        value: "Email",
                        description: $__("Email"),
                    },
                    {
                        value: "FTP",
                        description: $__("FTP – File Transfer Protocol"),
                    },
                    {
                        value: "Mail",
                        description: $__("Mail"),
                    },
                    {
                        value: "Odyssey",
                        description: $__("Odyssey"),
                    },
                    {
                        value: "URL",
                        description: $__("Website to download from"),
                    },
                ],
            },
            {
                element: "itemFormat",
                values: [
                    {
                        value: "CassetteTape",
                        description: $__("Cassette tape"),
                    },
                    {
                        value: "CD",
                        description: $__("CD"),
                    },
                    {
                        value: "CD-ROM",
                        description: $__("CD-ROM"),
                    },
                    {
                        value: "Daisy-ROM",
                        description: $__("Daisy-ROM"),
                    },
                    {
                        value: "DVD",
                        description: $__("DVD"),
                    },
                    {
                        value: "EPUB",
                        description: $__("EPUB"),
                    },
                    {
                        value: "EPUB2",
                        description: $__("EPUB2"),
                    },
                    {
                        value: "EPUB3",
                        description: $__("EPUB3"),
                    },
                    {
                        value: "JPEG",
                        description: $__("JPEG"),
                    },
                    {
                        value: "LargePrint",
                        description: $__("Large print"),
                    },
                    {
                        value: "LP",
                        description: $__("LP"),
                    },
                    {
                        value: "Microform",
                        description: $__("Microform"),
                    },
                    {
                        value: "MP3",
                        description: $__("MP3"),
                    },
                    {
                        value: "Multimedia",
                        description: $__("Multimedia"),
                    },
                    {
                        value: "PaperCopy",
                        description: $__("Paper copy"),
                    },
                    {
                        value: "PDF",
                        description: $__("PDF"),
                    },
                    {
                        value: "Printed",
                        description: $__("Printed"),
                    },
                    {
                        value: "Tape",
                        description: $__("Tape"),
                    },
                    {
                        value: "TIFF",
                        description: $__("TIFF"),
                    },
                    {
                        value: "UltraHD",
                        description: $__("Ultra HD"),
                    },
                    {
                        value: "VHS",
                        description: $__("VHS"),
                    },
                ],
            },
            {
                element: "loanCondition",
                values: [
                    {
                        value: "LibraryUseOnly",
                        description: $__("Use in library only"),
                    },
                    {
                        value: "WatchLibraryUseOnly",
                        description: $__("Supervised use in library only"),
                    },
                    {
                        value: "NoReproduction",
                        description: $__("No reproduction"),
                    },
                    {
                        value: "SignatureRequired",
                        description: $__("Signature required"),
                    },
                    {
                        value: "SpecCollSupervReq",
                        description: $__(
                            "Special collections supervision required"
                        ),
                    },
                ],
            },
            {
                element: "paymentMethod",
                values: [
                    {
                        value: "BankTransfer",
                        description: $__("Bank transfer"),
                    },
                    {
                        value: "CreditCard",
                        description: $__("Credit card"),
                    },
                    {
                        value: "DebitCard",
                        description: $__("Debit card"),
                    },
                    {
                        value: "EFTS",
                        description: $__("Electronic Fund Transfer System"),
                    },
                    {
                        value: "IBS",
                        description: $__(
                            "Interloan Billing System (New Zealand)"
                        ),
                    },
                    {
                        value: "IIBS",
                        description: $__(
                            "International Interloan Billing System (New Zealand)"
                        ),
                    },
                    {
                        value: "IFLAVoucher",
                        description: $__("IFLA Voucher"),
                    },
                    {
                        value: "IFM",
                        description: $__("OCLC fee management system"),
                    },
                    {
                        value: "LAPS",
                        description: $__("Libraries Australia Payment Service"),
                    },
                    {
                        value: "Paypal",
                        description: $__("Paypal"),
                    },
                ],
            },
            {
                element: "reasonRetry",
                values: [
                    {
                        value: "AtBindery",
                        description: $__("At bindery"),
                    },
                    {
                        value: "CostExceedsMaxCost",
                        description: $__("Cost exceeds max cost"),
                    },
                    {
                        value: "CourierNotSupp",
                        description: $__("Courier not supported"),
                    },
                    {
                        value: "MultiVolAvail",
                        description: $__(
                            "More than one volume can fulfil the request"
                        ),
                    },
                    {
                        value: "MustMeetLoanCondition",
                        description: $__("Loan condition shall be met"),
                    },
                    {
                        value: "NotCurrentAvailableForILL",
                        description: $__("Not currently available for ILL"),
                    },
                    {
                        value: "NotFoundAsCited",
                        description: $__("Not found as cited"),
                    },
                    {
                        value: "OnLoan",
                        description: $__("On loan"),
                    },
                    {
                        value: "OnOrder",
                        description: $__("On order"),
                    },
                    {
                        value: "ReqDelDateNotPossible",
                        description: $__(
                            "Requested delivery date not possible"
                        ),
                    },
                    {
                        value: "ReqDelMethodNotSupp",
                        description: $__(
                            "Requested delivery method not supported"
                        ),
                    },
                    {
                        value: "ReqEditionNotPossible",
                        description: $__(
                            "Requested edition cannot be provided"
                        ),
                    },
                    {
                        value: "ReqFormatNotPossible",
                        description: $__("Requested format not possible"),
                    },
                    {
                        value: "ReqPayMethodNotSupported",
                        description: $__(
                            "Requested payment method not supported"
                        ),
                    },
                    {
                        value: "ReqServLevelNotSupp",
                        description: $__(
                            "Requested service level not supported"
                        ),
                    },
                    {
                        value: "ReqServTypeNotPossible",
                        description: $__("Requested service type not possible"),
                    },
                ],
            },
            {
                element: "reasonUnfilled",
                values: [
                    {
                        value: "NonCirculating",
                        description: $__("Non-circulating (e.g. handbook)"),
                    },
                    {
                        value: "NotAvailableForILL",
                        description: $__("Not available for ILL"),
                    },
                    {
                        value: "NotHeld",
                        description: $__("Not held"),
                    },
                    {
                        value: "NotOnShelf",
                        description: $__("Not on shelf"),
                    },
                    {
                        value: "PolicyProblem",
                        description: $__("Policy problem"),
                    },
                    {
                        value: "PoorCondition",
                        description: $__("Poor condition"),
                    },
                ],
            },
            {
                element: "serviceLevel",
                values: [
                    {
                        value: "Express",
                        description: $__("Express (Australia)"),
                    },
                    {
                        value: "Normal",
                        description: $__("Normal (Prioritaire A)"),
                    },
                    {
                        value: "Rush",
                        description: $__("Rush (Australia)"),
                    },
                    {
                        value: "SecondaryMail",
                        description: $__("Secondary mail (Prioritaire B)"),
                    },
                    {
                        value: "Standard",
                        description: $__("Standard (Australia)"),
                    },
                    {
                        value: "Urgent",
                        description: $__("Urgent"),
                    },
                ],
            },
        ];

        return codes.find(code => code.element === element).values;
    };

    return {
        getCodesForElement,
    };
}
