describe("Fund CRUD operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleFund").then(objects => {
            cy.wrap(objects).as("objects");
        });
    });

    afterEach(function () {
        if (this.objects?.sub_fund_objects)
            cy.task("deleteSampleObjects", [this.objects.sub_fund_objects]);
        cy.task("deleteSampleObjects", [this.objects]);
    });

    it("List funds", function () {
        // Returns 500 — intercept fires once only
        cy.intercept(
            { method: "GET", url: "/api/v1/acquisitions/funds*", times: 1 },
            { statusCode: 500 }
        );
        cy.visit("/cgi-bin/koha/acquisitions/finances/funds");
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // Real data — fund from beforeEach appears in the list
        cy.visit("/cgi-bin/koha/acquisitions/finances/funds");
        cy.get("#funds_list").contains(this.objects.fund.name);
    });

    it("Add fund", function () {
        const ledger = this.objects.ledger;
        const fp = this.objects.fiscal_period;

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/funds/add?ledger_id=${ledger.ledger_id}&fiscal_period_id=${fp.fiscal_period_id}`
        );
        cy.get("h2").contains("New fund");

        // Required field validation triggers before any API call
        cy.get("#funds_add").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.at.least",
            1
        );

        // Fill in required fields
        cy.get("#name").type("Test fund");
        cy.get("#code").type("TEST");
        cy.get("#description").type("A test fund");
        cy.get("#fund_amount").type("5000");
        cy.get("#status .vs__search").type("Active{enter}", { force: true });

        // Submit — success (use the real fund from beforeEach as the "created" response)
        const fund = this.objects.fund;
        cy.intercept("POST", "/api/v1/acquisitions/funds", {
            statusCode: 201,
            body: fund,
        });
        cy.get("#funds_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains("Fund created");
    });

    it("Add sub-fund", function () {
        const fund = this.objects.fund;
        const ledger = this.objects.ledger;

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/funds/add?fund_id=${fund.fund_id}`
        );
        cy.get("h2").contains("New sub fund");

        cy.get("#name").type("Sub-fund for ebooks");
        cy.get("#code").type("EBOOKS");
        cy.get("#fund_amount").type("1000");
        cy.get("#status .vs__search").type("Active{enter}", { force: true });

        // Stub the POST to avoid creating a real sub-fund that needs separate cleanup
        const sub_fund = {
            ...fund,
            fund_id: fund.fund_id + 1,
            parent_fund_id: fund.fund_id,
            name: "Sub-fund for ebooks",
            code: "EBOOKS",
            fiscal_period: this.objects.fiscal_period,
            ledger: this.objects.ledger,
            child_object_managing_branches: [],
            sub_funds: [],
        };
        cy.intercept("POST", "/api/v1/acquisitions/funds", {
            statusCode: 201,
            body: sub_fund,
        });
        cy.intercept(
            "GET",
            `/api/v1/acquisitions/funds/${sub_fund.fund_id}*`,
            sub_fund
        );
        cy.get("#funds_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains("Fund created");
    });

    it("Edit fund", function () {
        const fund = this.objects.fund;
        const fund_id = fund.fund_id;

        cy.visit("/cgi-bin/koha/acquisitions/finances/funds");
        cy.get("#funds_list table tbody")
            .contains("tr", fund.name)
            .contains("Edit")
            .click();

        cy.get("#name").should("have.value", fund.name);
        cy.get("#code").should("have.value", fund.code);

        cy.get("#name").clear().type("Updated books fund");

        // Submit — success
        cy.get("#funds_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains("Fund updated");
    });

    it("Delete fund", function () {
        const fund = this.objects.fund;

        cy.visit("/cgi-bin/koha/acquisitions/finances/funds");
        cy.get("#funds_list table tbody")
            .contains("tr", fund.name)
            .contains("Delete")
            .click();

        cy.get(".alert-warning.confirmation h1").contains("remove this fund");
        cy.contains(fund.name);

        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains(fund.name)
            .contains("deleted");
    });

    it("Delete button hidden when fund has sub-funds", function () {
        const fund = this.objects.fund;

        // Stub the GET to return the fund with sub_funds populated
        const sub_fund = {
            fund_id: fund.fund_id + 1,
            parent_fund_id: fund.fund_id,
            name: "Sub-fund for ebooks",
        };
        cy.intercept(
            "GET",
            `/api/v1/acquisitions/funds/${fund.fund_id}*`,
            req => {
                req.continue(res => {
                    res.body.sub_funds = [sub_fund];
                });
            }
        );

        cy.visit(`/cgi-bin/koha/acquisitions/finances/funds/${fund.fund_id}`);

        cy.contains(fund.name);
        cy.contains("Delete").should("not.exist");
    });

    it("Show fund with sub-funds and allocations", function () {
        const fund = this.objects.fund;

        cy.task("insertSampleAllocation", { fund }).then(allocObjects => {
            this.objects = { ...this.objects, ...allocObjects };

            cy.task("insertSampleFund", {
                ledger: this.objects.ledger,
                fund: { parent_fund_id: fund.fund_id },
            }).then(subFundObjects => {
                this.objects = {
                    ...this.objects,
                    sub_fund_objects: subFundObjects,
                };
                const sub_fund = subFundObjects.fund;

                cy.visit(
                    `/cgi-bin/koha/acquisitions/finances/funds/${fund.fund_id}`
                );

                cy.contains(fund.name);
                cy.contains(fund.description);

                // Allocation buttons shown for active fund
                cy.contains("Increase fund amount");
                cy.contains("Decrease fund amount");
                cy.contains("Transfer fund amount");

                // Add sub-fund button shown for top-level, active, unlocked fund
                cy.contains("Add sub fund");

                // Sub-funds section shown
                cy.contains("Sub funds");
                cy.contains(sub_fund.name);

                // Allocations section shown
                cy.contains("Allocations");
                cy.contains(allocObjects.allocation.reference);
            });
        });
    });

    it("Add sub-fund and allocation buttons hidden for inactive fund", function () {
        const fund = this.objects.fund;

        cy.intercept(
            "GET",
            `/api/v1/acquisitions/funds/${fund.fund_id}*`,
            req => {
                req.continue(res => {
                    res.body.status = false;
                });
            }
        );

        cy.visit(`/cgi-bin/koha/acquisitions/finances/funds/${fund.fund_id}`);

        cy.contains(fund.name);
        cy.contains("Add sub fund").should("not.exist");
        cy.contains("Increase fund amount").should("not.exist");
    });
});
