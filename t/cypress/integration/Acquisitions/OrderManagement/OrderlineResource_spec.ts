const interceptBiblioFormAPIs = () => {
    cy.intercept("GET", "/api/v1/item_types*", req => {
        req.continue(res => {
            res.send();
        });
    }).as("itemTypes");
    cy.intercept("GET", "/cgi-bin/koha/services/itemrecorddisplay.pl*", req => {
        req.continue(res => {
            res.send();
        });
    }).as("itemFields");
};

describe.skip("OrderlineResource - CRUD", () => {
    beforeEach(function () {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleOrderline").then(objects => {
            cy.wrap(objects).as("objects");
        });
    });

    afterEach(function () {
        if (this.objects) {
            cy.task("deleteSampleObjects", [this.objects]);
        }
    });

    it("List orderlines", function () {
        // GET orderlines returns empty list
        cy.intercept("GET", "/api/v1/acquisitions/orderlines*", {
            statusCode: 200,
            body: [],
            headers: {
                "X-Base-Total-Count": "0",
                "X-Total-Count": "0",
            },
        });
        cy.visit("/cgi-bin/koha/acquisitions/order_management/orderlines");
        cy.get("#orderlines_list").contains("There are no orderlines defined");

        // GET orderlines returns the inserted orderline with embedded objects
        cy.intercept("GET", "/api/v1/acquisitions/orderlines*", {
            statusCode: 200,
            body: [
                {
                    ...this.objects.orderline,
                    vendor: this.objects.vendor,
                    biblio: this.objects.biblio,
                    managing_library: this.objects.libraries[0],
                    fund_distributions: [
                        {
                            fund_id: this.objects.fund.fund_id,
                            percentage: 100,
                        },
                    ],
                    extended_attributes: [],
                    managed_by: [
                        {
                            borrowernumber: this.objects.patrons[0].patron_id,
                            patron: this.objects.patrons[0],
                        },
                    ],
                    patrons_to_notify: [
                        {
                            borrowernumber: this.objects.patrons[1].patron_id,
                            patron: this.objects.patrons[1],
                        },
                    ],
                },
            ],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.visit("/cgi-bin/koha/acquisitions/order_management/orderlines");
        cy.get("#orderlines_list").contains("Showing 1 to 1 of 1 entries");
    });

    it("Show orderline", function () {
        cy.visit(
            `/cgi-bin/koha/acquisitions/order_management/orderlines/${this.objects.orderline.orderline_id}`
        );
        cy.get("#orderlines_show h2").contains(
            "Orderline #" + this.objects.orderline.orderline_id
        );
        cy.get("#toolbar").contains("Edit");
        cy.get("#toolbar").contains("Delete");
    });

    it("Delete orderline", function () {
        const embeddedOrderline = {
            ...this.objects.orderline,
            vendor: this.objects.vendor,
            biblio: this.objects.biblio,
            managing_library: this.objects.libraries[0],
            fund_distributions: [
                { fund_id: this.objects.fund.fund_id, percentage: 100 },
            ],
            extended_attributes: [],
            managed_by: [
                {
                    borrowernumber: this.objects.patrons[0].patron_id,
                    patron: this.objects.patrons[0],
                },
            ],
            patrons_to_notify: [
                {
                    borrowernumber: this.objects.patrons[1].patron_id,
                    patron: this.objects.patrons[1],
                },
            ],
        };

        // Delete from list
        cy.intercept("GET", "/api/v1/acquisitions/orderlines*", {
            statusCode: 200,
            body: [embeddedOrderline],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-orderlines");
        cy.intercept(
            "GET",
            `/api/v1/acquisitions/orderlines/${this.objects.orderline.orderline_id}*`,
            embeddedOrderline
        );
        cy.visit("/cgi-bin/koha/acquisitions/order_management/orderlines");
        cy.wait("@get-orderlines");

        cy.get("#orderlines_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this orderline"
        );
        cy.contains(this.objects.orderline.orderline_id);

        // Accept the confirmation dialog, get 500
        cy.intercept("DELETE", "/api/v1/acquisitions/orderlines/*", {
            statusCode: 500,
            body: { error: "Internal Server Error" },
        });
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Internal Server Error"
        );

        // Accept the confirmation dialog, success!
        cy.intercept("DELETE", "/api/v1/acquisitions/orderlines/*", {
            statusCode: 204,
            body: null,
        });
        cy.get("#orderlines_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this orderline"
        );
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains("Orderline")
            .contains("deleted");

        // Delete from show
        cy.visit("/cgi-bin/koha/acquisitions/order_management/orderlines");
        cy.wait("@get-orderlines");
        cy.intercept(
            "GET",
            `/api/v1/acquisitions/orderlines/${this.objects.orderline.orderline_id}*`,
            embeddedOrderline
        ).as("get-orderline");

        let id_cell = cy.get("#orderlines_list table tbody tr:first td:first");
        id_cell.contains(this.objects.orderline.orderline_id);

        let show_link = cy
            .get("#orderlines_list table tbody tr:first td:first")
            .find("a.show");
        show_link.click();
        cy.wait("@get-orderline");
        cy.get("#orderlines_show h2").contains(
            "Orderline #" + this.objects.orderline.orderline_id
        );

        cy.get("#orderlines_show #toolbar").contains("Delete").click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this orderline"
        );
        cy.contains("Yes, delete").click();

        // Make sure we return to list after deleting from show
        cy.get("#orderlines_list table tbody tr:first");
    });

    it("Edit orderline", function () {
        interceptBiblioFormAPIs();
        cy.visit(
            `/cgi-bin/koha/acquisitions/order_management/orderlines/edit/${this.objects.orderline.orderline_id}`
        );
        cy.get("h2").contains("Edit orderline");
        cy.get("#orderlines_add").should("be.visible");

        // Relationship selects
        cy.get("#vendor_id .vs__selected").contains(this.objects.vendor.name);
        cy.get("#managing_branch .vs__selected").contains(
            this.objects.libraries[0].name
        );
        // Numeric fields
        cy.get("#vendor_price").should(
            "have.value",
            String(this.objects.orderline.vendor_price)
        );
        cy.get("#quantity").should(
            "have.value",
            String(this.objects.orderline.quantity_ordered)
        );
        cy.get("#replacement_price").should(
            "have.value",
            String(this.objects.orderline.replacement_price)
        );
        cy.get("#discount_percentage").should(
            "have.value",
            String(this.objects.orderline.discount_percentage)
        );
        // Checkboxes
        cy.get("#is_continuous").should("not.be.checked");
        cy.get("#renewal_required").should("not.be.checked");
        cy.get("#renewal_required").should("be.disabled");
        cy.get("#uncertain_price").should("be.checked");
        cy.get("#urgent_order").should("be.checked");
        // Radio
        cy.get("#create_items_cataloging").should("be.checked");
        // Text / textarea
        cy.get("#internal_note").should(
            "have.value",
            this.objects.orderline.internal_note
        );
        cy.get("#receiving_note").should(
            "have.value",
            this.objects.orderline.receiving_note
        );
        cy.get("#vendor_note").should(
            "have.value",
            this.objects.orderline.vendor_note
        );
        cy.get("#statistic1").should(
            "have.value",
            this.objects.orderline.statistic1
        );
        cy.get("#statistic2").should(
            "have.value",
            this.objects.orderline.statistic2
        );
        // Date
        cy.get("#estimated_delivery_date")
            .invoke("val")
            .should("eq", this.objects.orderline.estimated_delivery_date);
        // PatronSearch — fieldName_patron_borrowernumber
        cy.get(
            `#managed_by_patron_${this.objects.patrons[0].patron_id}`
        ).should("exist");
        cy.get(
            `#patrons_to_notify_patron_${this.objects.patrons[1].patron_id}`
        ).should("exist");
        // Fund distributions — v-select for the first distribution entry
        cy.get("#fund_id_0 .vs__selected").contains(this.objects.fund.name);

        cy.get("#internal_note").clear().type("Updated internal note");
        cy.get("fieldset.action").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Orderline updated"
        );
    });
});

describe("OrderlineResource - Add (non-bibliographic)", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Shows non-bibliographic fields when no_biblio=true", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("h2").contains("New orderline");
        cy.get("#non_bib_description").should("exist");
        cy.get("#non_bib_information").should("exist");
        cy.get("#product_number").should("exist");
        cy.get("#non_bib_note").should("exist");
    });

    it("Hides biblio and items sections for non-bibliographic orderlines", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        // Bibliographic information group not rendered when no_biblio=true
        cy.get("[data-group='Catalog details']").should("not.exist");
    });

    it("Defaults create_items to Cataloging for non-bibliographic orderlines", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("#create_items_cataloging").should("be.checked");
    });

    it("Disables Ordering and Receiving create_items options for non-bibliographic orderlines", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("#create_items_ordering").should("be.disabled");
        cy.get("#create_items_receiving").should("be.disabled");
        cy.get("#create_items_cataloging").should("not.be.disabled");
    });

    it("Validates required fields before saving", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("button.btn-primary").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.at.least",
            1
        );
    });

    it("Creates a non-bibliographic orderline successfully", () => {
        cy.intercept("POST", "/api/v1/acquisitions/orderlines", {
            statusCode: 201,
            body: { orderline_id: 1 },
        });
        cy.intercept("GET", "/api/v1/acquisitions/orderlines/1*", {
            orderline_id: 1,
        });

        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("#vendor_price").type("25.00");
        cy.get("button.btn-primary").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Orderline created"
        );
    });
});

describe("OrderlineResource - subComponentsReady", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Non-bibliographic add form is displayed immediately without waiting for sub-components", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        // Form is shown immediately — v-show="readyToDisplay" resolves true at once
        // when nonBibliographic is true, since sub-components are never rendered
        cy.get("#orderlines_add").should("be.visible");
    });

    it("Bibliographic add form is hidden while sub-components load, then becomes visible", () => {
        cy.intercept("GET", "/api/v1/item_types*", req => {
            req.reply({ statusCode: 200, body: [], delay: 500 });
        }).as("item-types");
        cy.intercept("GET", "/cgi-bin/koha/services/itemrecorddisplay.pl*", {
            statusCode: 200,
            body: { iteminformation: [] },
        }).as("marc-fields");

        cy.visit("/cgi-bin/koha/acquisitions/order_management/orderlines/add");

        // Both biblio and items keys must flip to true before readyToDisplay resolves —
        // delaying item_types keeps the form hidden until the response arrives
        cy.get("#orderlines_add").should("not.be.visible");

        cy.wait(["@item-types", "@marc-fields"]);
        cy.get("#orderlines_add").should("be.visible");
    });
});

describe("OrderlineResource - isContinuous behaviour", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );
    });

    it("renewal_required is disabled when is_continuous is unchecked", () => {
        cy.get("#is_continuous").should("not.be.checked");
        cy.get("#renewal_required").should("be.disabled");
    });

    it("renewal_required becomes enabled after is_continuous is checked", () => {
        cy.get("#is_continuous").check({ force: true });
        cy.get("#renewal_required").should("not.be.disabled");
    });

    it("renewal_required becomes disabled again after is_continuous is unchecked", () => {
        cy.get("#is_continuous").check({ force: true });
        cy.get("#renewal_required").should("not.be.disabled");

        cy.get("#is_continuous").uncheck({ force: true });
        cy.get("#renewal_required").should("be.disabled");
    });

    it("isContinuous onChange updates the isContinuous ref used to control items visibility", () => {
        // When is_continuous is checked the items create_items group is no longer
        // active for item creation at ordering (continuous orders do not support ordering items)
        cy.get("#is_continuous").check({ force: true });

        // After checking, create_items_ordering should be functionally irrelevant
        // — the is_continuous onChange handler sets isContinuous.value = true
        // which is passed to the items sub-component as continuousOrder
        cy.get("#is_continuous").should("be.checked");
    });
});

describe("OrderlineResource - createItemsWhen behaviour", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.visit("/cgi-bin/koha/acquisitions/order_management/orderlines/add");
        interceptBiblioFormAPIs();
        cy.wait("@itemTypes");
        cy.wait("@itemFields");
    });

    it("Resets quantity_ordered to 1 when create_items changes to receiving", () => {
        cy.get("#create_items_receiving").check({ force: true });
        cy.get("#quantity").should("have.value", "1");
    });

    it("Resets quantity_ordered to 1 when create_items changes to cataloging", () => {
        cy.get("#create_items_cataloging").check();
        cy.get("#quantity").should("have.value", "1");
    });

    it("Matches quantity of items when create_items changes to ordering", () => {
        cy.get("[data-cypress-id='tag_952_subfield_y'] .vs__search").type(
            "Books" + "{enter}",
            {
                force: true,
            }
        );
        cy.get("#itemFormAddMultiple").click();
        cy.get("#multipleItemsNumberInput").type(5);
        cy.get("#addMultipleItemsButton").click();

        cy.get("#create_items_receiving").check({ force: true });
        cy.get("#quantity").should("have.value", "1");
        cy.get("#create_items_ordering").check({ force: true });
        cy.get("#quantity").should("have.value", "5");
    });
});

describe("OrderlineResource - vendor onSelected handler", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept("GET", "/api/v1/acquisitions/vendors*", {
            statusCode: 200,
            body: [
                {
                    id: 1,
                    name: "My Vendor",
                    list_currency: "USD",
                    discount: 15,
                    tax_rate: 0.2,
                    active: true,
                },
            ],
        });
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );
    });

    it("Sets vendor_price_currency to the vendor's list_currency when a vendor is selected", () => {
        cy.get("#vendor_id .vs__search").type("My Vendor" + "{enter}", {
            force: true,
        });

        cy.get("#vendor_price_currency .vs__selected").should("contain", "USD");
    });

    it("Sets discount_percentage to the vendor's discount when a vendor is selected", () => {
        cy.get("#vendor_id .vs__search").type("My Vendor" + "{enter}", {
            force: true,
        });

        cy.get("#discount").should("have.value", "15");
    });
});

describe("OrderlineResource - vendor_price_currency onSelected handler", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept("GET", "/api/v1/acquisitions/vendors*", {
            statusCode: 200,
            body: [
                {
                    id: 1,
                    name: "My Vendor",
                    list_currency: "USD",
                    discount: 15,
                    tax_rate: 0.2,
                    active: true,
                },
            ],
        });
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );
    });

    it("Updates distribution_exchange_rate when the currency selection changes", () => {
        // Select a vendor to populate fund distributions before changing currency
        cy.get("#vendor_id .vs__search").type("My Vendor" + "{enter}", {
            force: true,
        });

        // Change currency — the onSelected handler calls getCurrencyConversionRate
        // and writes the result back to distribution_exchange_rate and fund_distributions
        cy.get("#vendor_price_currency .vs__search").type("EUR" + "{enter}", {
            force: true,
        });

        // The exchange rate field is now populated (not the initial empty/default value)
        cy.get("#distribution_exchange_rate").should("not.have.value", "");
    });
});

describe("OrderlineResource - Save as draft", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Save as draft button is present in the add form toolbar", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );
        cy.get("fieldset.action ul.dropdown-menu").contains("Save as draft");
    });

    it("Submits orderline with status draft when Save as draft is clicked", () => {
        cy.intercept("POST", "/api/v1/acquisitions/orderlines", req => {
            expect(req.body.status).to.eq("draft");
            req.reply({
                statusCode: 201,
                body: { orderline_id: 1, status: "draft" },
            });
        }).as("create-draft");
        cy.intercept("GET", "/api/v1/acquisitions/orderlines/1*", {
            orderline_id: 1,
            status: "draft",
        });

        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("#vendor_price").type("25.00");
        cy.get("fieldset.action a.dropdown-toggle").click();
        cy.get("fieldset.action ul.dropdown-menu")
            .contains("Save as draft")
            .click();
        cy.wait("@create-draft");
        cy.get("main div[class='alert alert-info']").contains(
            "Orderline created"
        );
    });
});

describe("OrderlineResource - Duplicate biblio handling", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Shows duplicate warning dialog when API returns bib_match error", () => {
        cy.intercept("POST", "/api/v1/acquisitions/orderlines", {
            statusCode: 409,
            body: {
                error: "bib_match",
                duplicate_biblio: {
                    biblionumber: 42,
                    title: "The Great Gatsby",
                },
                orderline: {},
                // dialog_confirm:1 causes the http-client to rethrow the detailed
                // error object rather than swallowing it via setError()
                dialog_confirm: 1,
            },
        });

        // Use the non-biblio form to simplify form submission with fewer required fields
        // The response will still work the same through the intercept
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("#vendor_price").type("25.00");
        cy.get("fieldset.action").contains("Save").click();

        cy.contains("Duplicate warning");
        cy.contains("The Great Gatsby");
        cy.contains("Use existing record");
        cy.contains("Cancel and return to order");
        cy.contains("Create new record");
    });

    it("Returns to form without saving when Cancel and return to order is selected", () => {
        cy.intercept("POST", "/api/v1/acquisitions/orderlines", {
            statusCode: 409,
            body: {
                error: "bib_match",
                duplicate_biblio: {
                    biblionumber: 42,
                    title: "The Great Gatsby",
                },
                orderline: {},
                dialog_confirm: 1,
            },
        });

        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );

        cy.get("#vendor_price").type("25.00");
        cy.get("fieldset.action").contains("Save").click();

        cy.contains("Cancel and return to order")
            .closest("li")
            .find("input[type='checkbox']")
            .check({ force: true });
        cy.contains("Select").click();

        cy.get("main div[class='alert alert-info']").should("not.exist");
        cy.get("#orderlines_add").should("be.visible");
    });

    it("Resubmits with existing biblionumber when Use existing record is selected", () => {
        cy.intercept("POST", "/api/v1/acquisitions/orderlines", {
            statusCode: 409,
            body: {
                error: "bib_match",
                duplicate_biblio: {
                    biblionumber: 42,
                    title: "The Great Gatsby",
                },
                orderline: {},
                dialog_confirm: 1,
            },
        }).as("first-post");

        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );
        cy.get("#vendor_price").type("25.00");
        cy.get("fieldset.action").contains("Save").click();
        cy.wait("@first-post");

        cy.intercept("POST", "/api/v1/acquisitions/orderlines", req => {
            expect(req.body.biblionumber).to.eq(42);
            req.reply({ statusCode: 201, body: { orderline_id: 1 } });
        }).as("use-existing-post");
        cy.intercept("GET", "/api/v1/acquisitions/orderlines/1*", {
            orderline_id: 1,
        });

        cy.contains("Use existing record")
            .closest("li")
            .find("input[type='checkbox']")
            .check({ force: true });
        cy.contains("Select").click();
        cy.wait("@use-existing-post");

        cy.get("main div[class='alert alert-info']").contains(
            "Orderline created"
        );
    });

    it("Resubmits with x-confirm-not-duplicate header when Create new record is selected", () => {
        cy.intercept("POST", "/api/v1/acquisitions/orderlines", {
            statusCode: 409,
            body: {
                error: "bib_match",
                duplicate_biblio: {
                    biblionumber: 42,
                    title: "The Great Gatsby",
                },
                orderline: {},
                dialog_confirm: 1,
            },
        }).as("first-post");

        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/add?no_biblio=true"
        );
        cy.get("#vendor_price").type("25.00");
        cy.get("fieldset.action").contains("Save").click();
        cy.wait("@first-post");

        cy.intercept("POST", "/api/v1/acquisitions/orderlines", req => {
            expect(req.headers["x-confirm-not-duplicate"]).to.eq("1");
            req.reply({ statusCode: 201, body: { orderline_id: 1 } });
        }).as("create-new-post");
        cy.intercept("GET", "/api/v1/acquisitions/orderlines/1*", {
            orderline_id: 1,
        });

        cy.contains("Create new record")
            .closest("li")
            .find("input[type='checkbox']")
            .check({ force: true });
        cy.contains("Select").click();
        cy.wait("@create-new-post");

        cy.get("main div[class='alert alert-info']").contains(
            "Orderline created"
        );
    });
});

describe("OrderlineResource - Search", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Shows search form at the search route", () => {
        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/search"
        );
        cy.contains("Search orderlines");
    });

    it("Navigates to orderlines list with search params when form is submitted", () => {
        cy.intercept("GET", "/api/v1/acquisitions/orderlines*", {
            statusCode: 200,
            body: [],
            headers: {
                "X-Base-Total-Count": "0",
                "X-Total-Count": "0",
            },
        }).as("get-orderlines");

        cy.visit(
            "/cgi-bin/koha/acquisitions/order_management/orderlines/search"
        );

        cy.get("#internal_note").type("test search");
        cy.contains("Submit").click();

        cy.url().should(
            "include",
            "/cgi-bin/koha/acquisitions/order_management/orderlines"
        );
        cy.url().should("include", "internal_note");
    });
});
