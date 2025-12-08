describe("Main component - pref off", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept(
            "GET",
            "/api/v1/displays/config",
            '{"settings":{"enabled":"0"}}'
        );
    });

    it("Home", () => {
        cy.visit("/cgi-bin/koha/display/display-home.pl");
        cy.get(".main .sidebar_menu").should("not.exist");
        cy.get(".main div[class='alert alert-warning']").contains(
            "The displays module is disabled, turn on UseDisplayModule to use it"
        );
        cy.get(".main div[class='alert alert-warning'] a").click();
        cy.url().should("match", /\/cgi-bin\/koha\/admin\/preferences.pl/);
    });
});

describe("Main component - pref on", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept(
            "GET",
            "/api/v1/displays/config",
            '{"settings":{"enabled":"1"}}'
        );
    });

    it("Home", () => {
        cy.visit("/cgi-bin/koha/display/display-home.pl");
        cy.get(".main .sidebar_menu").should("exist");
        cy.get(".main div[class='alert alert-warning']").should("not.exist");
    });
});
