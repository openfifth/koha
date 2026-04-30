const dayjs = require("dayjs"); /* Cannot use our calendar JS code, it's in an include file (!)
                                   Also note that moment.js is deprecated */

const config_response = {
    settings: {
        IntranetBiblioDefaultView: "detail",
        ClaimReturnedLostValue: null,
        viewMARC: true,
        viewLabelledMARC: true,
        viewISBD: true,
        marcflavour: "marc21",
        "item-level_itypes": true,
    },
};

const item_types = [
    { item_type_id: "BK", description: "Book" },
    { item_type_id: "DVD", description: "DVD" },
];

const av_categories = [
    {
        category_name: "LOC",
        authorised_values: [
            { value: "GEN", description: "General" },
            { value: "REF", description: "Reference" },
        ],
    },
];

const av_categories_with_ccode = [
    ...av_categories,
    {
        category_name: "CCODE",
        authorised_values: [
            { value: "FIC", description: "Fiction" },
            { value: "NFIC", description: "Non-fiction" },
        ],
    },
];

const overdue_record = {
    issue_id: 1,
    patron_id: 1,
    checkout_date: "2025-01-01T10:00:00+00:00",
    due_date: "2025-01-15T23:59:00+00:00",
    library_id: "CPL",
    patron: {
        patron_id: 1,
        firstname: "John",
        surname: "Doe",
        cardnumber: "001",
        other_name: null,
        preferred_name: null,
        email: "john@test.com",
        phone: "555-0001",
        mobile: null,
        secondary_phone: null,
        library_id: "CPL",
        debarred: null,
        incorrect_address: null,
        patron_card_lost: null,
        category: { name: "Adult" },
        library: { name: "Centerville" },
    },
    item: {
        item_id: 1,
        biblio_id: 1,
        item_type_id: "BK",
        external_id: "BC001",
        callnumber: "QA123.456",
        replacement_price: "10.00",
        internal_notes: "Test note",
        location: "GEN",
        serial_issue_number: null,
        return_claim: null,
        biblio: {
            biblio_id: 1,
            title: "Test Book Title",
            author: "Test Author",
            medium: null,
            subtitles: null,
            part_number: null,
            part_name: null,
        },
        biblioitem: { itemtype: "BK" },
        home_library: { name: "Centerville" },
        holding_library: { name: "Centerville" },
    },
    library: { name: "Centerville" },
};

const test_patron_attrs = [
    {
        code: "TEXT_ATTR",
        description: "My Text Attribute",
        staff_searchable: 1,
        authorised_value_category: null,
        is_date: false,
        repeatable: false,
    },
    {
        code: "AV_ATTR",
        description: "My AV Attribute",
        staff_searchable: 1,
        authorised_value_category: "CCODE",
        is_date: false,
        repeatable: false,
    },
    {
        code: "DATE_ATTR",
        description: "My Date Attribute",
        staff_searchable: 1,
        authorised_value_category: null,
        is_date: true,
        repeatable: false,
    },
    {
        code: "REPEAT_ATTR",
        description: "My Repeatable Attribute",
        staff_searchable: 1,
        authorised_value_category: null,
        is_date: false,
        repeatable: true,
    },
];

/**
 * Register all always-needed intercepts before cy.visit().
 * patronAttrsToInject: when provided, replaces the server-rendered `const patronAttrs`
 * global in the page HTML. Both modifications (table_settings + optional patronAttrs)
 * are done in a single req.continue handler to avoid Cypress intercept-chain issues.
 */
function setup_common_intercepts(
    checkouts_body = [],
    total = 0,
    avCategories = av_categories,
    configSettingsOverride = {},
    patronAttrsToInject = null
) {
    cy.intercept("GET", /\/cgi-bin\/koha\/circulation\/overdues/, req => {
        req.continue(res => {
            res.body = res.body.replace(
                /const table_settings = [\s\S]*?;/,
                "const table_settings = { columns: []};"
            );
            if (patronAttrsToInject) {
                res.body = res.body.replace(
                    /const patronAttrs = \[[\s\S]*?\];/,
                    `const patronAttrs = ${JSON.stringify(patronAttrsToInject)};`
                );
            }
        });
    });
    cy.intercept("GET", "/api/v1/overdues/config", {
        statusCode: 200,
        body: {
            settings: {
                ...config_response.settings,
                ...configSettingsOverride,
            },
        },
    }).as("config");
    cy.intercept("GET", "/api/v1/item_types*", {
        statusCode: 200,
        body: item_types,
        headers: { "X-Total-Count": String(item_types.length) },
    }).as("item-types");
    cy.intercept("GET", /\/api\/v1\/authorised_value_categories/, {
        statusCode: 200,
        body: avCategories,
        headers: { "X-Total-Count": String(avCategories.length) },
    }).as("av-categories");
    cy.intercept("GET", "/api/v1/checkouts*", {
        statusCode: 200,
        body: checkouts_body,
        headers: { "X-Total-Count": String(total) },
    }).as("checkouts");
    // Intercept sidebar relationshipSelect requests
    cy.intercept("GET", /\/api\/v1\/libraries/, {
        statusCode: 200,
        body: [{ library_id: "CPL", name: "Centerville" }],
        headers: { "X-Total-Count": "1" },
    }).as("libraries");
    cy.intercept("GET", /\/api\/v1\/patron_categories/, {
        statusCode: 200,
        body: [{ patron_category_id: "A", name: "Adult" }],
        headers: { "X-Total-Count": "1" },
    }).as("patron-categories");
}

/**
 * Wait for a checkouts intercept and return its decoded `q` parameter.
 */
function wait_and_get_query(alias = "outs") {
    cy.wait(alias); // discard count request
    return cy.wait(alias).then(interception => {
        const urlStr = interception.request.url;
        const url = new URL(
            urlStr.startsWith("http") ? urlStr : "http://localhost" + urlStr
        );
        return JSON.parse(url.searchParams.get("q") || "{}");
    });
}

describe("Overdues", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    describe("Page load", () => {
        it("shows an empty message when there are no overdues", () => {
            setup_common_intercepts([], 0);
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@config");
            cy.wait("@checkouts");
            // Empty state is rendered in a dialog/alert, not inside a <table>
            cy.contains("There are no overdues");
        });

        it("renders all expected table columns", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues");
            // Wait for count probe, then let the table render
            cy.wait("@checkouts");

            const expected_columns = [
                "Due date",
                "Patron",
                "Patron category",
                "Patron library",
                "Title",
                "Home library",
                "Holding library",
                "Shelving location",
                "Checked out on",
                "Barcode",
                "Call number",
                "Item type",
                "Price",
                "Non-public note",
            ];
            // cy.get retries until the table appears (DataTables renders after data response)
            expected_columns.forEach(col => {
                cy.get("table thead th").contains(col);
            });
            // Return claims absent when ClaimReturnedLostValue is null
            cy.get("table thead th")
                .contains("Return claims")
                .should("not.exist");
        });

        it("displays overdue records in the table", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@checkouts");

            cy.get("table tbody tr").should("have.length.gte", 1);
            cy.get("table tbody a[href*='borrowernumber=1']").should("exist");
            cy.get("table tbody a.title").contains("Test Book Title");
            cy.get("table tbody tr").contains("BC001");
            cy.get("table tbody tr").contains("Book");
            cy.get("table tbody tr").contains("General");
        });

        it("shows the Return claims column when ClaimReturnedLostValue is set", () => {
            setup_common_intercepts([overdue_record], 1, av_categories, {
                ClaimReturnedLostValue: "2025-01-01",
            });
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@checkouts");
            cy.get("table thead th").contains("Return claims");
        });
    });

    describe("Filter sidebar", () => {
        it("displays all standard filter fields", () => {
            setup_common_intercepts([], 0);
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@checkouts");

            cy.get("aside").within(() => {
                cy.contains("Date due");
                cy.contains("Show any items currently checked out");
                cy.contains("From");
                cy.contains("To");
                cy.contains("Name or card number");
                cy.contains("Patron category");
                cy.contains("Patron flags");
                cy.contains("Item type");
                cy.contains("Item home library");
                cy.contains("Item holding library");
                cy.contains("Library of the patron");
                cy.contains("Apply filter");
            });

            // No patron attribute fields when patronAttrs is empty
            cy.get("aside").contains("My Text Attribute").should("not.exist");
            cy.get("aside").contains("My AV Attribute").should("not.exist");
            cy.get("aside").contains("My Date Attribute").should("not.exist");
            cy.get("aside")
                .contains("My Repeatable Attribute")
                .should("not.exist");
        });

        it("displays patron attribute fields when configured", () => {
            setup_common_intercepts(
                [],
                0,
                av_categories_with_ccode,
                {},
                test_patron_attrs
            );
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@checkouts");

            cy.get("aside").within(() => {
                // Text attribute → plain text input; FormElement binds :id not name
                cy.contains("My Text Attribute");
                cy.get("#TEXT_ATTR").should("exist");

                // AV attribute → v-select with id
                cy.contains("My AV Attribute");
                cy.get("#AV_ATTR").should("exist");

                // Date attribute → flatpickr input with id
                cy.contains("My Date Attribute");
                cy.get("#DATE_ATTR").should("exist");

                // Repeatable attribute → input with id plus New (+) clone button
                cy.contains("My Repeatable Attribute");
                cy.get("#REPEAT_ATTR").should("exist");
                cy.get(".clone_attribute").should("exist");
            });
        });
    });

    describe("Filtering", () => {
        // With total=1 there are two checkouts requests: count (q={}) then DataTables data
        // (q=<filtered>). wait_and_get_query with skip_count=true discards the count first.

        it("filters by patron name (URL param)", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues?patron_name=John");
            wait_and_get_query("@checkouts").then(q => {
                expect(q["-or"]).to.be.an("array").with.length(3);
                expect(q["-or"][0]).to.deep.equal({
                    "patron.firstname": { "-like": "John%" },
                });
                expect(q["-or"][1]).to.deep.equal({
                    "patron.surname": { "-like": "John%" },
                });
                expect(q["-or"][2]).to.deep.equal({
                    "patron.cardnumber": { "-like": "John%" },
                });
            });
        });

        it("filters by patron name (form submission)", () => {
            setup_common_intercepts([], 0);
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@checkouts");

            cy.get("#patron_name").type("Smith");
            cy.get("aside form").submit();

            // The filter form pushes a new URL — verify the query param is set correctly
            cy.url().should("include", "patron_name=Smith");
        });

        it("filters by patron flag: gone_no_address", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?patron_flag=gone_no_address"
            );
            wait_and_get_query("@checkouts").then(q => {
                expect(q["patron.incorrect_address"]).to.deep.equal({
                    "!=": 0,
                });
            });
        });

        it("filters by patron flag: debarred", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues?patron_flag=debarred");
            wait_and_get_query("@checkouts").then(q => {
                expect(q["patron.debarred"]).to.have.key(">=");
                expect(new Date(q["patron.debarred"][">="])).to.be.instanceOf(
                    Date
                );
            });
        });

        it("filters by patron flag: lost card", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues?patron_flag=lost");
            wait_and_get_query("@checkouts").then(q => {
                expect(q["patron.patron_card_lost"]).to.deep.equal({ "!=": 0 });
            });
        });

        it("filters by item type", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues?item_type=BK");
            wait_and_get_query("@checkouts").then(q => {
                // item-level_itypes is true in the fixture → uses item.itype
                expect(q["item.itype"]).to.equal("BK");
            });
        });

        it("filters by item home library", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?item_home_library=CPL"
            );
            wait_and_get_query("@checkouts").then(q => {
                expect(q["item.home_library_id"]).to.equal("CPL");
            });
        });

        it("filters by item holding library", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?item_holding_library=CPL"
            );
            wait_and_get_query("@checkouts").then(q => {
                expect(q["item.holding_library_id"]).to.equal("CPL");
            });
        });

        it("filters by patron library", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues?patron_library=CPL");
            wait_and_get_query("@checkouts").then(q => {
                expect(q["patron.library_id"]).to.equal("CPL");
            });
        });

        it("filters by patron category", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit("/cgi-bin/koha/circulation/overdues?category=A");
            wait_and_get_query("@checkouts").then(q => {
                expect(q["patron.categorycode"]).to.equal("A");
            });
        });

        it("filters by date range (from and to)", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?due_date_from=2025-01-01&due_date_to=2025-01-31"
            );
            wait_and_get_query("@checkouts").then(q => {
                expect(q["due_date"]["-between"])
                    .to.be.an("array")
                    .with.length(2);
                // Range is expanded one day either side
                const start = new Date(q["due_date"]["-between"][0]);
                const end = new Date(q["due_date"]["-between"][1]);
                expect(start.toISOString().startsWith("2024-12-31")).to.be.true;
                expect(end.toISOString().startsWith("2025-02-01")).to.be.true;
            });
        });

        it("filters by due_date_from only", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?due_date_from=2025-01-01"
            );
            wait_and_get_query("@checkouts").then(q => {
                expect(q["due_date"]).to.have.key(">=");
            });
        });

        it("does not apply the overdue date filter when due_date_to is also set", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?showall=false&due_date_to=2025-01-31"
            );
            wait_and_get_query("@checkouts").then(q => {
                // due_date_to alone: due_date <= 2025-01-31 (end of day)
                expect(q["due_date"]).to.have.key("<=");
                // The "< today" past-due filter must NOT be present
                expect(q["due_date"]).not.to.have.key("<");
            });
        });

        it("combines multiple filters", () => {
            setup_common_intercepts([overdue_record], 1);
            cy.visit(
                "/cgi-bin/koha/circulation/overdues?patron_name=Jane&item_type=DVD&patron_library=CPL"
            );
            wait_and_get_query("@checkouts").then(q => {
                expect(q["item.itype"]).to.equal("DVD");
                expect(q["patron.library_id"]).to.equal("CPL");
                expect(q["-or"]).to.be.an("array").with.length(3);
                expect(q["-or"][0]["patron.firstname"]["-like"]).to.equal(
                    "Jane%"
                );
            });
        });

        describe("Patron attribute filters", () => {
            beforeEach(() => {
                setup_common_intercepts(
                    [overdue_record],
                    1,
                    av_categories_with_ccode,
                    {},
                    test_patron_attrs
                );
            });

            it("filters by a text patron attribute", () => {
                cy.visit(
                    "/cgi-bin/koha/circulation/overdues?TEXT_ATTR=some+value"
                );
                wait_and_get_query("@checkouts").then(q => {
                    expect(q["-and"]).to.be.an("array").with.length(1);
                    expect(q["-and"][0]).to.deep.equal({
                        "patron.extended_attributes.code": "TEXT_ATTR",
                        "patron.extended_attributes.attribute": "some value",
                    });
                });
            });

            it("filters by a date patron attribute", () => {
                cy.visit(
                    "/cgi-bin/koha/circulation/overdues?DATE_ATTR=2025-06-01"
                );
                wait_and_get_query("@checkouts").then(q => {
                    expect(q["-and"]).to.be.an("array").with.length(1);
                    expect(q["-and"][0]).to.deep.equal({
                        "patron.extended_attributes.code": "DATE_ATTR",
                        "patron.extended_attributes.attribute": "2025-06-01",
                    });
                });
            });

            it("filters by a repeatable patron attribute with a single value", () => {
                cy.visit(
                    "/cgi-bin/koha/circulation/overdues?REPEAT_ATTR=hello"
                );
                wait_and_get_query("@checkouts").then(q => {
                    expect(q["-and"]).to.be.an("array").with.length(1);
                    expect(q["-and"][0]).to.deep.equal({
                        "patron.extended_attributes.code": "REPEAT_ATTR",
                        "patron.extended_attributes.attribute": "hello",
                    });
                });
            });

            it("filters by a repeatable patron attribute with multiple values", () => {
                // Vue Router parses repeated query keys as an array
                cy.visit(
                    "/cgi-bin/koha/circulation/overdues?REPEAT_ATTR=hello&REPEAT_ATTR=world"
                );
                wait_and_get_query("@checkouts").then(q => {
                    expect(q["-and"]).to.be.an("array").with.length(2);
                    expect(q["-and"][0]).to.deep.equal({
                        "patron.extended_attributes.code": "REPEAT_ATTR",
                        "patron.extended_attributes.attribute": "hello",
                    });
                    expect(q["-and"][1]).to.deep.equal({
                        "patron.extended_attributes.code": "REPEAT_ATTR",
                        "patron.extended_attributes.attribute": "world",
                    });
                });
            });
        });
    });

    describe("FilterBeforeOverdueReport preference", () => {
        it("shows a prompt when preference is on and no filter is applied", () => {
            setup_common_intercepts([], 0, av_categories, {
                FilterBeforeOverdueReport: 1,
            });
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@config");

            cy.contains("Please choose one or more filters to proceed.");
            cy.get("table").should("not.exist");
        });

        it("shows the table when preference is on and a filter is applied", () => {
            setup_common_intercepts([overdue_record], 1, av_categories, {
                FilterBeforeOverdueReport: 1,
            });
            cy.visit("/cgi-bin/koha/circulation/overdues?patron_name=John");
            cy.wait("@checkouts");

            cy.get("table").should("exist");
            cy.contains("Please choose one or more filters to proceed.").should(
                "not.exist"
            );
        });

        it("shows the table normally when preference is off", () => {
            setup_common_intercepts([overdue_record], 1, av_categories, {
                FilterBeforeOverdueReport: 0,
            });
            cy.visit("/cgi-bin/koha/circulation/overdues");
            cy.wait("@checkouts");

            cy.get("table").should("exist");
            cy.contains("Please choose one or more filters to proceed.").should(
                "not.exist"
            );
        });
    });
});
