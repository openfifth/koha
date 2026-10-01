describe("opac-imageviewer.pl imagenumber XSS", () => {
    let biblio: any;

    before(() => {
        cy.task("query", {
            sql: "UPDATE systempreferences SET value = '1' WHERE variable = 'OPACLocalCoverImages'",
        });
    });

    beforeEach(() => {
        cy.task("insertSampleBiblio", {}).then(result => {
            biblio = result;
        });
    });

    afterEach(() => {
        cy.task("deleteSampleObjects", [biblio]);
    });

    it("Should not execute a crafted imagenumber as JavaScript", () => {
        const payload = "1);alert(document.domain);var x=(1";
        const alertStub = cy.stub().as("alertStub");
        cy.on("window:alert", alertStub);

        // A non-numeric imagenumber is dropped. Cypress fails the test on
        // any uncaught exception, so this also checks the page copes with it.
        cy.visitOpac(
            `/cgi-bin/koha/opac-imageviewer.pl?biblionumber=${biblio.biblio.biblio_id}&imagenumber=${encodeURIComponent(payload)}`
        );

        cy.get("@alertStub").should("not.have.been.called");

        // The value must have been dropped (non-numeric), not reflected raw.
        cy.document().then(doc => {
            expect(doc.documentElement.innerHTML).not.to.contain(
                "alert(document.domain)"
            );
        });
    });

    it("Should load for a record without cover images and no imagenumber", () => {
        // Cypress fails the test on any uncaught exception
        cy.visitOpac(
            `/cgi-bin/koha/opac-imageviewer.pl?biblionumber=${biblio.biblio.biblio_id}`
        );
        cy.get("#largeCoverImg").should("exist");
    });
});
