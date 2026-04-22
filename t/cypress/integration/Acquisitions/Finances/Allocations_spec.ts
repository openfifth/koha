describe("Allocation operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSampleFund").then(objects => {
            cy.wrap(objects).as("objects");
        });
    });

    afterEach(function () {
        const toDelete = [];
        if (this.objects) toDelete.push(this.objects);
        if (this.dest_objects) toDelete.push(this.dest_objects);
        if (toDelete.length) cy.task("deleteSampleObjects", toDelete);
    });

    it("Increase fund amount", function () {
        const fund = this.objects.fund;

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/fund/${fund.fund_id}/allocate?action=increase`
        );

        cy.contains("Increase amount by");
        cy.contains("Increased fund amount");

        cy.get("#allocation_amount").clear().type("1000");
        cy.get("#reference").type("Q1 top-up");
        cy.get("#note").type("Quarterly increase");

        // Submit — success
        cy.get("#allocations_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Allocation created"
        );
    });

    it("Decrease fund amount", function () {
        const fund = this.objects.fund;

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/fund/${fund.fund_id}/allocate?action=decrease`
        );

        cy.contains("Decrease amount by");
        cy.contains("Decreased fund amount");

        cy.get("#allocation_amount").clear().type("500");
        cy.get("#reference").type("Cost saving");

        cy.get("#allocations_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Allocation created"
        );
    });

    it("Shows insufficient funds warning when allocation would go negative", function () {
        const fund = this.objects.fund;

        // Modify the fund GET response to return a low fund_amount
        cy.intercept(
            "GET",
            `/api/v1/acquisitions/funds/${fund.fund_id}*`,
            req => {
                req.continue(res => {
                    res.body.fund_amount = 100;
                });
            }
        );

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/fund/${fund.fund_id}/allocate?action=decrease`
        );

        // Enter an amount greater than the current fund amount
        cy.get("#allocation_amount").clear().type("200");
        cy.get("#allocations_add").contains("Save").click();

        cy.get("#warning").contains(
            "Insufficient funds to process this transaction"
        );
    });

    it("Transfer fund amount", function () {
        const source_fund = this.objects.fund;

        cy.task("insertSampleFund", { ledger: this.objects.ledger }).then(
            destObjects => {
                this.dest_objects = destObjects;
                const dest_fund = destObjects.fund;

                cy.visit(
                    `/cgi-bin/koha/acquisitions/finances/fund/${source_fund.fund_id}/allocate?action=transfer`
                );

                cy.contains("Amount being transferred");
                cy.contains("Destination fund");
                cy.contains("Remaining fund amount");

                cy.get("#allocation_amount").clear().type("1000");
                cy.get("#is_transferred_to .vs__search").type(
                    dest_fund.name + "{enter}",
                    { force: true }
                );
                cy.get("#reference").type("Transfer to journals");

                cy.get("#allocations_add").contains("Save").click();
                cy.get("main div[class='alert alert-info']").contains(
                    "Allocation created"
                );
            }
        );
    });

    it("Increase ledger amount", function () {
        const ledger = this.objects.ledger;

        cy.visit(
            `/cgi-bin/koha/acquisitions/finances/ledger/${ledger.ledger_id}/allocate?action=increase`
        );

        cy.contains("Increase amount by");
        cy.contains("Increased ledger amount");

        cy.get("#allocation_amount").clear().type("5000");
        cy.get("#reference").type("Supplementary budget");

        cy.get("#allocations_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Allocation created"
        );
    });
});
