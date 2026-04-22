describe("Fiscal period CRUD operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleFiscalPeriod").then(objects => {
            cy.wrap(objects).as("objects");
        });
    });

    afterEach(function () {
        cy.task("deleteSampleObjects", [this.objects]);
    });

    it("List fiscal periods", function () {
        // Returns 500 — intercept fires once only
        cy.intercept(
            {
                method: "GET",
                url: "/api/v1/acquisitions/fiscal_periods*",
                times: 1,
            },
            { statusCode: 500 }
        );
        cy.visit("/cgi-bin/koha/acquisitions/finances/fiscal_periods");
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // Real data — fiscal_period from beforeEach appears in the list
        cy.visit("/cgi-bin/koha/acquisitions/finances/fiscal_periods");
        cy.get("#fiscal_periods_list").contains(
            this.objects.fiscal_period.name
        );
    });

    it("Add fiscal period", function () {
        cy.visit("/cgi-bin/koha/acquisitions/finances/fiscal_periods");
        cy.contains("New fiscal period").click();
        cy.get("h2").contains("New fiscal period");

        // Required field validation triggers before any API call
        cy.get("#fiscal_periods_add").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.at.least",
            1
        );

        // Fill in required fields
        cy.get("#name").type("Test fiscal period");
        cy.get("#description").type("A test fiscal period");

        cy.get("#start_date+input").click();
        cy.get(".flatpickr-calendar")
            .eq(0)
            .find("span.today")
            .click({ force: true });

        cy.get("#end_date+input").click();
        cy.get(".flatpickr-calendar")
            .eq(1)
            .find("span.today")
            .next("span")
            .click();

        cy.get("#status .vs__search").type("Active{enter}", { force: true });

        // Submit — success (use the real fiscal_period from beforeEach as the "created" response)
        const fp = this.objects.fiscal_period;
        cy.intercept("POST", "/api/v1/acquisitions/fiscal_periods", {
            statusCode: 201,
            body: fp,
        });
        cy.get("#fiscal_periods_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Fiscal period created"
        );
    });

    it("Edit fiscal period", function () {
        const fp = this.objects.fiscal_period;
        const fp_id = fp.fiscal_period_id;

        cy.visit("/cgi-bin/koha/acquisitions/finances/fiscal_periods");
        cy.get("#fiscal_periods_list table tbody")
            .contains("tr", fp.name)
            .contains("Edit")
            .click();

        cy.get("#name").should("have.value", fp.name);
        cy.get("#description").should("have.value", fp.description);

        cy.get("#name").clear().type("Updated FY 2025");

        // Submit — success
        cy.get("#fiscal_periods_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Fiscal period updated"
        );
    });

    it("Delete fiscal period", function () {
        const fp = this.objects.fiscal_period;

        cy.visit("/cgi-bin/koha/acquisitions/finances/fiscal_periods");
        cy.get("#fiscal_periods_list table tbody")
            .contains("tr", fp.name)
            .contains("Delete")
            .click();

        cy.get(".alert-warning.confirmation h1").contains(
            "remove this fiscal period"
        );
        cy.contains(fp.name);

        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains(fp.name)
            .contains("deleted");
    });

    it("Show fiscal period", function () {
        const fp = this.objects.fiscal_period;

        cy.task("insertSampleLedger", { fiscal_period: fp }).then(
            ledgerObjects => {
                this.objects = { ...this.objects, ...ledgerObjects };

                cy.visit(
                    `/cgi-bin/koha/acquisitions/finances/fiscal_periods/${fp.fiscal_period_id}`
                );

                cy.contains(fp.name);
                cy.contains(fp.description);
                cy.contains("Add ledger");

                // Ledgers section is rendered
                cy.contains("Ledgers");
                cy.contains(ledgerObjects.ledger.name);
            }
        );
    });

    it("Add ledger button hidden for inactive fiscal period", function () {
        const fp = this.objects.fiscal_period;

        cy.intercept(
            "GET",
            `/api/v1/acquisitions/fiscal_periods/${fp.fiscal_period_id}*`,
            req => {
                req.continue(res => {
                    res.body.status = false;
                });
            }
        );

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/fiscal_periods/${fp.fiscal_period_id}`
        );

        cy.contains(fp.name);
        cy.contains("Add ledger").should("not.exist");
    });

    it("Active and Inactive filters show correct fiscal periods", function () {
        const fp = this.objects.fiscal_period;

        cy.visit("/cgi-bin/koha/acquisitions/finances/fiscal_periods");

        // The active fp appears in the unfiltered list
        cy.get("#fiscal_periods_list").contains(fp.name);

        cy.intercept("GET", "/api/v1/acquisitions/fiscal_periods*").as(
            "getFiltered"
        );

        // Active filter button restricts by status
        cy.intercept("GET", "/api/v1/acquisitions/fiscal_periods*").as(
            "getFilteredFiscalPeriods"
        );

        // Active filter — active fp is visible
        cy.get("fieldset.filters input[value='Active']").click();
        cy.wait("@getFiltered")
            .its("request.url")
            .should("include", "me.status");
        cy.get("#fiscal_periods_list").contains(fp.name);

        // Inactive filter — active fp is not visible
        cy.get("fieldset.filters input[value='Inactive']").click();
        cy.wait("@getFiltered")
            .its("request.url")
            .should("include", "me.status");
        cy.get("#fiscal_periods_list").should("not.contain", fp.name);

        // Clear — active fp is visible again
        cy.get("fieldset.filters input[value='Clear']").click();
        cy.wait("@getFiltered")
            .its("request.url")
            .should("not.include", "me.status");
        cy.get("#fiscal_periods_list").contains(fp.name);
    });
});
