describe("Vue InputText / InputNumber clearable (bug 41151)", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    describe("InputText clearable", () => {
        beforeEach(() => {
            cy.intercept(
                "GET",
                "/api/v1/erm/config",
                '{"settings":{"ERMModule":"1","ERMProviders":["local"]}}'
            );
            cy.intercept("GET", "/api/v1/erm/agreements*", []);
            cy.intercept("GET", "/api/v1/erm/users*", []);
            cy.intercept("GET", "/api/v1/acquisitions/vendors*", []);
            cy.intercept("GET", "/api/v1/erm/documents*", []);
            cy.visit("/cgi-bin/koha/erm/agreements/add");
            cy.get("#agreements_add h2").contains("New agreement");
        });

        it("hides clear button when empty", () => {
            cy.get("#name")
                .should("have.value", "")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("not.exist");
        });

        it("shows clear button when value is non-empty and clears on click", () => {
            cy.get("#name").type("Acme Publishing");
            cy.get("#name")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("be.visible")
                .click();
            cy.get("#name").should("have.value", "");
            cy.get("#name")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("not.exist");
        });

        it('shows clear button when value is the string "0"', () => {
            cy.get("#name").type("0");
            cy.get("#name").should("have.value", "0");
            cy.get("#name")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("be.visible");
        });

        it("renders an fa-xmark icon (not an inline SVG)", () => {
            cy.get("#name").type("x");
            cy.get("#name")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button .fa-xmark")
                .should("exist");
            cy.get("#name")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button svg")
                .should("not.exist");
        });
    });

    describe("InputNumber clearable", () => {
        beforeEach(() => {
            cy.intercept("GET", "/api/v1/sip2/institutions**", {
                statusCode: 200,
                body: [],
            });
            cy.visit("/cgi-bin/koha/sip2/institutions");
            cy.contains("New institution").click();
            cy.get("#institutions_add h2").contains("New institution");
        });

        it("hides clear button when empty", () => {
            // `retries` has a defaultValue of 5; clear it first
            cy.get("#retries").clear();
            cy.get("#retries")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("not.exist");
        });

        it("shows clear button when value is numeric and clears on click", () => {
            cy.get("#timeout").clear().type("42");
            cy.get("#timeout")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("be.visible")
                .click();
            cy.get("#timeout").should("have.value", "");
            cy.get("#timeout")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("not.exist");
        });

        it("shows clear button when value is the number 0", () => {
            cy.get("#timeout").clear().type("0");
            cy.get("#timeout").should("have.value", "0");
            cy.get("#timeout")
                .parent(".input-with-clear-wrapper")
                .find(".clear-button")
                .should("be.visible");
        });
    });
});
