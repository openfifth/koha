describe("Ledger CRUD operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleLedger").then(objects => {
            cy.wrap(objects).as("objects");
        });
    });

    afterEach(function () {
        cy.task("deleteSampleObjects", [this.objects]);
    });

    it("List ledgers", function () {
        // Returns 500 — intercept fires once only
        cy.intercept(
            { method: "GET", url: "/api/v1/acquisitions/ledgers*", times: 1 },
            { statusCode: 500 }
        );
        cy.visit("/cgi-bin/koha/acquisitions/finances/ledgers");
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // Real data — ledger from beforeEach appears in the list
        cy.visit("/cgi-bin/koha/acquisitions/finances/ledgers");
        cy.get("#ledgers_list").contains(this.objects.ledger.name);
    });

    it("Add ledger", function () {
        const fp_id = this.objects.fiscal_period.fiscal_period_id;

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/ledgers/add?fiscal_period_id=${fp_id}`
        );
        cy.get("h2").contains("New ledger");

        // Required field validation triggers before any API call
        cy.get("#ledgers_add").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.at.least",
            1
        );

        // Fill in required fields
        cy.get("#name").type("Test ledger");
        cy.get("#description").type("A test ledger");
        cy.get("#external_id").type("LED-TEST");
        cy.get("#ledger_amount").type("10000");
        cy.get("#status .vs__search").type("Active{enter}", { force: true });

        // Submit — success (use the real ledger from beforeEach as the "created" response)
        const ledger = this.objects.ledger;
        cy.intercept("POST", "/api/v1/acquisitions/ledgers", {
            statusCode: 201,
            body: ledger,
        });
        cy.get("#ledgers_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains("Ledger created");
    });

    it("Edit ledger", function () {
        const ledger = this.objects.ledger;
        const ledger_id = ledger.ledger_id;

        cy.visit("/cgi-bin/koha/acquisitions/finances/ledgers");
        cy.get("#ledgers_list table tbody")
            .contains("tr", ledger.name)
            .contains("Edit")
            .click();

        cy.get("#name").should("have.value", ledger.name);
        cy.get("#description").should("have.value", ledger.description);

        cy.get("#name").clear().type("Updated ledger name");

        // Submit — success
        cy.get("#ledgers_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains("Ledger updated");
    });

    it("Delete ledger", function () {
        const ledger = this.objects.ledger;

        cy.visit("/cgi-bin/koha/acquisitions/finances/ledgers");
        cy.get("#ledgers_list table tbody")
            .contains("tr", ledger.name)
            .contains("Delete")
            .click();

        cy.get(".alert-warning.confirmation h1").contains("remove this ledger");
        cy.contains(ledger.name);

        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains(ledger.name)
            .contains("deleted");
    });

    it("Show ledger with funds and allocations", function () {
        const ledger = this.objects.ledger;

        cy.task("insertSampleFund", { ledger }).then(fundObjects => {
            cy.task("insertSampleAllocation", {
                ledger,
            }).then(allocObjects => {
                this.objects = {
                    ...this.objects,
                    ...fundObjects,
                    ...allocObjects,
                };

                cy.visit(
                    `/cgi-bin/koha/acquisitions/finances/ledgers/${ledger.ledger_id}`
                );

                cy.contains(ledger.name);
                cy.contains(ledger.description);

                // Add fund button shown for active, unlocked ledger
                cy.contains("Add fund");

                // Allocation buttons shown for active ledger
                cy.contains("Increase ledger amount");
                cy.contains("Decrease ledger amount");
                cy.contains("Transfer ledger amount");

                // Funds and allocations sections shown
                cy.contains("Funds");
                cy.contains(fundObjects.fund.name);
                cy.contains("Allocations");
                cy.contains(allocObjects.allocation.reference);
            });
        });
    });

    it("Add fund and allocation buttons hidden for inactive ledger", function () {
        const ledger = this.objects.ledger;

        cy.intercept(
            "GET",
            `/api/v1/acquisitions/ledgers/${ledger.ledger_id}*`,
            req => {
                req.continue(res => {
                    res.body.status = false;
                });
            }
        );

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/ledgers/${ledger.ledger_id}`
        );

        cy.contains(ledger.name);
        cy.contains("Add fund").should("not.exist");
        cy.contains("Increase ledger amount").should("not.exist");
    });

    it("Add fund button hidden for locked ledger", function () {
        const ledger = this.objects.ledger;

        cy.intercept(
            "GET",
            `/api/v1/acquisitions/ledgers/${ledger.ledger_id}*`,
            req => {
                req.continue(res => {
                    res.body.locked = true;
                });
            }
        );

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/ledgers/${ledger.ledger_id}`
        );

        cy.contains(ledger.name);
        cy.contains("Add fund").should("not.exist");
    });
});
