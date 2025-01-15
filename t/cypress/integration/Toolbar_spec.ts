describe("Sticky toolbar", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Should stick on scroll", () => {
        cy.visit("/cgi-bin/koha/acqui/acqui-home.pl");

        cy.get("#toolbar").contains("New vendor").click();
        cy.scrollTo("bottom");
        cy.get("#toolbar").should("be.visible");
        cy.get("#toolbar").should("have.class", "floating");

        cy.scrollTo("top");
        cy.get("#toolbar").should("not.have.class", "floating");
    });
});
