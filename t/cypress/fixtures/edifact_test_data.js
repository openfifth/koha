// Comprehensive EDIFACT test data for Cypress tests
// Based on real EDIFACT structure but with sanitized/synthetic data

export const edifactTestData = {
    // Test data with multiple messages for focus testing
    multipleMessages: {
        header: "UNB+UNOC:3+TEST_SUPPLIER:14+TEST_LIBRARY:14+20250721:1234+1++1++1'",
        messages: [
            {
                id: 1,
                header: "UNH+1+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+BASKET001+9'",
                        elements: ["220", "BASKET001", "9"],
                        description: "Beginning of Message - Order",
                    },
                    {
                        tag: "DTM",
                        raw: "DTM+137:20250721:102'",
                        elements: ["137", "20250721", "102"],
                        description: "Date/Time - Order Date",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:LibraryBasket001'",
                        elements: ["ON", "LibraryBasket001"],
                        description: "Reference - Order Number",
                    },
                    {
                        tag: "NAD",
                        raw: "NAD+BY+1234567890123::91++Test Library System+123 Library Street+Booktown+12345+US'",
                        elements: [
                            "BY",
                            "1234567890123",
                            "",
                            "91",
                            "",
                            "Test Library System",
                            "123 Library Street",
                            "Booktown",
                            "12345",
                            "US",
                        ],
                        description: "Name and Address - Buyer",
                    },
                    {
                        tag: "LIN",
                        raw: "LIN+1++9781234567890:IB'",
                        elements: ["1", "", "9781234567890", "IB"],
                        description: "Line Item",
                    },
                    {
                        tag: "PIA",
                        raw: "PIA+5+BOOK001:SA'",
                        elements: ["5", "BOOK001", "SA"],
                        description: "Product Identification",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+009+:::Test Author'",
                        elements: ["L", "009", "", "", "", "Test Author"],
                        description: "Item Description - Author",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Introduction to Library Science'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Introduction to Library Science",
                        ],
                        description: "Item Description - Title",
                    },
                    {
                        tag: "QTY",
                        raw: "QTY+21:3'",
                        elements: ["21", "3"],
                        description: "Quantity",
                    },
                    {
                        tag: "PRI",
                        raw: "PRI+AAE:29.95:CA'",
                        elements: ["AAE", "29.95", "CA"],
                        description: "Price",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+LI:ORDER001'",
                        elements: ["LI", "ORDER001"],
                        description: "Reference - Line Item",
                    },
                ],
                trailer: "UNT+12+1'",
            },
            {
                id: 2,
                header: "UNH+2+INVOIC:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+380+INV002+9'",
                        elements: ["380", "INV002", "9"],
                        description: "Beginning of Message - Invoice",
                    },
                    {
                        tag: "DTM",
                        raw: "DTM+137:20250720:102'",
                        elements: ["137", "20250720", "102"],
                        description: "Date/Time - Invoice Date",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+IV:INVOICE002'",
                        elements: ["IV", "INVOICE002"],
                        description: "Reference - Invoice Number",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:LibraryBasket002'",
                        elements: ["ON", "LibraryBasket002"],
                        description: "Reference - Order Number",
                    },
                    {
                        tag: "NAD",
                        raw: "NAD+SU+9876543210987::91++Test Book Supplier+456 Publisher Ave+Bookville+54321+US'",
                        elements: [
                            "SU",
                            "9876543210987",
                            "",
                            "91",
                            "",
                            "Test Book Supplier",
                            "456 Publisher Ave",
                            "Bookville",
                            "54321",
                            "US",
                        ],
                        description: "Name and Address - Supplier",
                    },
                    {
                        tag: "LIN",
                        raw: "LIN+1++9789876543210:IB'",
                        elements: ["1", "", "9789876543210", "IB"],
                        description: "Line Item",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+009+:::Sample Author'",
                        elements: ["L", "009", "", "", "", "Sample Author"],
                        description: "Item Description - Author",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Advanced Library Management'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Advanced Library Management",
                        ],
                        description: "Item Description - Title",
                    },
                    {
                        tag: "QTY",
                        raw: "QTY+47:2'",
                        elements: ["47", "2"],
                        description: "Quantity Invoiced",
                    },
                    {
                        tag: "PRI",
                        raw: "PRI+AAA:45.00:CA'",
                        elements: ["AAA", "45.00", "CA"],
                        description: "Unit Price",
                    },
                    {
                        tag: "MOA",
                        raw: "MOA+203:90.00:USD'",
                        elements: ["203", "90.00", "USD"],
                        description: "Monetary Amount - Line Total",
                    },
                ],
                trailer: "UNT+13+2'",
            },
            {
                id: 3,
                header: "UNH+3+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+BASKET002+9'",
                        elements: ["220", "BASKET002", "9"],
                        description: "Beginning of Message - Order",
                    },
                    {
                        tag: "DTM",
                        raw: "DTM+137:20250719:102'",
                        elements: ["137", "20250719", "102"],
                        description: "Date/Time - Order Date",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:SpecialOrder123'",
                        elements: ["ON", "SpecialOrder123"],
                        description: "Reference - Order Number",
                    },
                    {
                        tag: "LIN",
                        raw: "LIN+1++9781111222333:IB'",
                        elements: ["1", "", "9781111222333", "IB"],
                        description: "Line Item",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Digital Archives and Preservation'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Digital Archives and Preservation",
                        ],
                        description: "Item Description - Title",
                    },
                    {
                        tag: "QTY",
                        raw: "QTY+21:1'",
                        elements: ["21", "1"],
                        description: "Quantity",
                    },
                    {
                        tag: "PRI",
                        raw: "PRI+AAE:125.00:CA'",
                        elements: ["AAE", "125.00", "CA"],
                        description: "Price",
                    },
                ],
                trailer: "UNT+8+3'",
            },
        ],
        trailer: "UNZ+3+1'",
    },

    // Test data for search functionality
    searchableContent: {
        header: "UNB+UNOC:3+SEARCH_SUPPLIER:14+SEARCH_LIBRARY:14+20250721:1500+3++1++1'",
        messages: [
            {
                id: 1,
                header: "UNH+1+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+SEARCH_BASKET+9'",
                        elements: ["220", "SEARCH_BASKET", "9"],
                        description: "Beginning of Message - Order",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+009+:::JavaScript Programming Guide'",
                        elements: [
                            "L",
                            "009",
                            "",
                            "",
                            "",
                            "JavaScript Programming Guide",
                        ],
                        description: "Item Description - Title",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Learn modern JavaScript programming techniques'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Learn modern JavaScript programming techniques",
                        ],
                        description: "Item Description - Description",
                    },
                    {
                        tag: "PIA",
                        raw: "PIA+5+JS001:SA+9781234567890:IB'",
                        elements: ["5", "JS001", "SA", "9781234567890", "IB"],
                        description: "Product Identification",
                    },
                    {
                        tag: "FTX",
                        raw: "FTX+LIN+++Essential reading for web developers learning JavaScript'",
                        elements: [
                            "LIN",
                            "",
                            "",
                            "Essential reading for web developers learning JavaScript",
                        ],
                        description: "Free Text",
                    },
                ],
                trailer: "UNT+6+1'",
            },
            {
                id: 2,
                header: "UNH+2+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+ORDER_BASKET_002+9'",
                        elements: ["220", "ORDER_BASKET_002", "9"],
                        description: "Beginning of Message - Order",
                    },
                    {
                        tag: "DTM",
                        raw: "DTM+137:20250721:102'",
                        elements: ["137", "20250721", "102"],
                        description: "Date/Time - Order Date",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:ORDER12345'",
                        elements: ["ON", "ORDER12345"],
                        description: "Reference - Order Number",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+009+:::Advanced JavaScript Concepts'",
                        elements: [
                            "L",
                            "009",
                            "",
                            "",
                            "",
                            "Advanced JavaScript Concepts",
                        ],
                        description: "Item Description - Title",
                    },
                    {
                        tag: "FTX",
                        raw: "FTX+LIN+++Comprehensive guide to ORDER processing and JavaScript'",
                        elements: [
                            "LIN",
                            "",
                            "",
                            "Comprehensive guide to ORDER processing and JavaScript",
                        ],
                        description: "Free Text",
                    },
                ],
                trailer: "UNT+6+2'",
            },
            {
                id: 3,
                header: "UNH+3+INVOIC:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+380+INV_BASKET_003+9'",
                        elements: ["380", "INV_BASKET_003", "9"],
                        description: "Beginning of Message - Invoice",
                    },
                    {
                        tag: "DTM",
                        raw: "DTM+137:20250720:102'",
                        elements: ["137", "20250720", "102"],
                        description: "Date/Time - Invoice Date",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+IV:220+ORDER67890'",
                        elements: ["IV", "220+ORDER67890"],
                        description: "Reference - Invoice with ORDER reference",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+009+:::JavaScript Testing Framework'",
                        elements: [
                            "L",
                            "009",
                            "",
                            "",
                            "",
                            "JavaScript Testing Framework",
                        ],
                        description: "Item Description - Title",
                    },
                    {
                        tag: "MOA",
                        raw: "MOA+203:125.00:USD'",
                        elements: ["203", "125.00", "USD"],
                        description: "Monetary Amount - Total",
                    },
                ],
                trailer: "UNT+6+3'",
            },
        ],
        trailer: "UNZ+3+3'",
    },

    // Test data for focus highlighting
    focusTestData: {
        header: "UNB+UNOC:3+FOCUS_SUPPLIER:14+FOCUS_LIBRARY:14+20250721:1600+3++1++1'",
        messages: [
            {
                id: 1,
                header: "UNH+1+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+00000012345+9'",
                        elements: ["220", "00000012345", "9"],
                        description:
                            "Beginning of Message - Order (basketno: 00000012345, matches numeric 12345)",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:TestBasket001'",
                        elements: ["ON", "TestBasket001"],
                        description:
                            "Reference - Order Number (basketname: TestBasket001)",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Focus Test Book One'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Focus Test Book One",
                        ],
                        description: "Item Description - Title",
                    },
                ],
                trailer: "UNT+4+1'",
            },
            {
                id: 2,
                header: "UNH+2+INVOIC:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+380+00000067890+9'",
                        elements: ["380", "00000067890", "9"],
                        description:
                            "Beginning of Message - Invoice (basketno: 00000067890, matches numeric 67890)",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+IV:TEST_INVOICE_001'",
                        elements: ["IV", "TEST_INVOICE_001"],
                        description:
                            "Reference - Invoice Number (invoicenumber: TEST_INVOICE_001)",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:FocusBasket002'",
                        elements: ["ON", "FocusBasket002"],
                        description:
                            "Reference - Order Number (basketname: FocusBasket002)",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Focus Test Book Two'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Focus Test Book Two",
                        ],
                        description: "Item Description - Title",
                    },
                ],
                trailer: "UNT+5+2'",
            },
            {
                id: 3,
                header: "UNH+3+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+BASKET_TEXT_001+9'",
                        elements: ["220", "BASKET_TEXT_001", "9"],
                        description:
                            "Beginning of Message - Order (basketno: BASKET_TEXT_001, text shouldn't be padded)",
                    },
                    {
                        tag: "RFF",
                        raw: "RFF+ON:NonNumericBasket'",
                        elements: ["ON", "NonNumericBasket"],
                        description:
                            "Reference - Order Number (basketname: NonNumericBasket)",
                    },
                    {
                        tag: "IMD",
                        raw: "IMD+L+050+:::Focus Test Book Three'",
                        elements: [
                            "L",
                            "050",
                            "",
                            "",
                            "",
                            "Focus Test Book Three",
                        ],
                        description: "Item Description - Title",
                    },
                ],
                trailer: "UNT+4+3'",
            },
        ],
        trailer: "UNZ+3+3'",
    },

    // Test data for error handling
    errorTestData: {
        header: "UNB+UNOC:3+ERROR_SUPPLIER:14+ERROR_LIBRARY:14+20250721:1700+4++1++1'",
        messages: [
            {
                id: 1,
                header: "UNH+1+ORDERS:D:96A:UN:EAN008'",
                segments: [
                    {
                        tag: "BGM",
                        raw: "BGM+220+ERROR_TEST+9'",
                        elements: ["220", "ERROR_TEST", "9"],
                        description: "Beginning of Message - Order",
                    },
                ],
                trailer: "UNT+2+1'",
            },
        ],
        trailer: "UNZ+1+4'",
        errors: [
            {
                section: "BGM+220+ERROR_TEST+9'",
                details:
                    "Test error: Invalid document function code in BGM segment.",
            },
        ],
    },

    // Empty test data for edge cases
    emptyData: {
        header: "",
        messages: [],
        trailer: "",
    },

    // Malformed JSON for error testing
    malformedData: "{ invalid json structure",

    // Large dataset for performance testing
    largeDataset: {
        header: "UNB+UNOC:3+LARGE_SUPPLIER:14+LARGE_LIBRARY:14+20250721:1800+5++1++1'",
        messages: Array.from({ length: 50 }, (_, i) => ({
            id: i + 1,
            header: `UNH+${i + 1}+ORDERS:D:96A:UN:EAN008'`,
            segments: [
                {
                    tag: "BGM",
                    raw: `BGM+220+BULK_${String(i + 1).padStart(3, "0")}+9'`,
                    elements: [
                        "220",
                        `BULK_${String(i + 1).padStart(3, "0")}`,
                        "9",
                    ],
                    description: `Beginning of Message - Bulk Order ${i + 1}`,
                },
                {
                    tag: "IMD",
                    raw: `IMD+L+050+:::Bulk Order Book ${i + 1}'`,
                    elements: [
                        "L",
                        "050",
                        "",
                        "",
                        "",
                        `Bulk Order Book ${i + 1}`,
                    ],
                    description: `Item Description - Title ${i + 1}`,
                },
            ],
            trailer: `UNT+3+${i + 1}'`,
        })),
        trailer: "UNZ+50+5'",
    },
};

// Utility functions for test data manipulation
export const testDataUtils = {
    // Get test data by focus type
    getFocusData(focusType, focusValue) {
        const data = { ...edifactTestData.focusTestData };

        // Filter messages based on focus criteria
        data.messages = data.messages.filter(message => {
            return message.segments.some(segment => {
                if (focusType === "basketno" && segment.tag === "BGM") {
                    const bgmValue = segment.elements[1];
                    let basketnoToMatch = String(focusValue);

                    // Apply same padding logic as the main code
                    if (
                        /^\d+$/.test(basketnoToMatch) &&
                        basketnoToMatch.length < 11
                    ) {
                        basketnoToMatch = basketnoToMatch.padStart(11, "0");
                    }

                    return bgmValue === basketnoToMatch;
                }
                if (
                    focusType === "basketname" &&
                    segment.tag === "RFF" &&
                    segment.elements[0] === "ON"
                ) {
                    return segment.elements[1] === focusValue;
                }
                if (
                    focusType === "invoicenumber" &&
                    segment.tag === "RFF" &&
                    (segment.elements[0] === "IV" ||
                        segment.elements[0] === "VN")
                ) {
                    return segment.elements[1] === focusValue;
                }
                return false;
            });
        });

        return data;
    },

    // Get searchable data with specific content
    getSearchData(searchTerm) {
        const data = { ...edifactTestData.searchableContent };

        if (!searchTerm) return data;

        // Filter content based on search term
        data.messages = data.messages.map(message => ({
            ...message,
            segments: message.segments.map(segment => ({
                ...segment,
                highlighted:
                    segment.raw
                        .toLowerCase()
                        .includes(searchTerm.toLowerCase()) ||
                    segment.description
                        .toLowerCase()
                        .includes(searchTerm.toLowerCase()),
            })),
        }));

        return data;
    },

    // Create mock response for cy.intercept
    createMockResponse(data, status = 200) {
        return {
            statusCode: status,
            body: data,
        };
    },
};

export default edifactTestData;
