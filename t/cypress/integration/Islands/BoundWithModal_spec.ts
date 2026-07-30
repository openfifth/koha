describe("Bound-with modal", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.set_syspref("EnableBoundWithItems", 1);

        // The item record lives on the native record, the linked record has no item of its own
        cy.task("insertSampleBiblio", { item_count: 1 }).then(objects => {
            cy.wrap(objects).as("native");
        });
        cy.task("insertSampleBiblio", { item_count: 0 }).then(objects => {
            cy.wrap(objects).as("linked");
        });
    });

    afterEach(function () {
        cy.task("deleteSampleObjects", [this.native, this.linked]);
        cy.set_syspref("EnableBoundWithItems", 0);
    });

    it("Links a record to an item, displays it and removes the link", function () {
        const native_id = this.native.biblio.biblio_id;
        const linked_id = this.linked.biblio.biblio_id;

        cy.intercept("GET", `/api/v1/biblios/${native_id}/items*`).as(
            "searchItems"
        );
        cy.intercept("GET", "/api/v1/biblios?*").as("searchBiblios");
        cy.intercept(
            "POST",
            `/api/v1/biblios/${linked_id}/item_biblio_links`
        ).as("createLink");
        cy.intercept(
            "DELETE",
            `/api/v1/biblios/${linked_id}/item_biblio_links/*`
        ).as("deleteLink");

        cy.visit(`/cgi-bin/koha/catalogue/detail.pl?biblionumber=${native_id}`);
        cy.wait("@searchItems");

        // No link yet: no view button, the management modal is empty
        cy.get("#holdings_table .bound-with-view").should("not.exist");
        cy.get("#holdings_table .bound-with-manage").click();
        cy.get("#bound-with-modal-label").should("contain", "Bound-with links");
        cy.get(".modal.d-block .modal-body").contains(
            "This item is not yet bound with any other record."
        );

        // Search the record by its number and link it
        cy.get(".modal.d-block .modal-body input.vs__search").type(
            `${linked_id}`
        );
        cy.wait("@searchBiblios");
        cy.get(".modal.d-block .modal-body .vs__dropdown-option")
            .contains(`(Record number ${linked_id})`)
            .click();
        cy.get(".modal.d-block .modal-footer").contains("Link").click();
        cy.wait("@createLink").its("response.statusCode").should("eq", 201);

        // The page reloads, the display-only modal lists the linked record
        cy.wait("@searchItems");
        cy.get("#holdings_table .bound-with-view").should(
            "contain",
            "View (1)"
        );
        cy.get("#holdings_table .bound-with-view").click();
        cy.get("#bound-with-modal-label").should(
            "contain",
            "Bound-with records"
        );
        cy.get(
            `#bound-with-links-table a[href$="biblionumber=${linked_id}"]`
        ).should("exist");
        cy.get("#bound-with-links-table")
            .contains("Remove link")
            .should("not.exist");
        cy.get(".modal.d-block .modal-footer").contains("Close").click();

        // A linked record is not offered again
        cy.get("#holdings_table .bound-with-manage").click();
        cy.get(".modal.d-block .modal-body input.vs__search").type(
            `${linked_id}`
        );
        cy.wait("@searchBiblios");
        cy.get(".modal.d-block .modal-body .vs__dropdown-option").should(
            "not.exist"
        );

        // Remove the link
        cy.get("#bound-with-links-table").contains("Remove link").click();
        cy.get("#bound-with-modal-label").should(
            "contain",
            "Remove bound-with link"
        );
        cy.get(".modal.d-block .modal-footer").contains("Remove link").click();
        cy.wait("@deleteLink").its("response.statusCode").should("eq", 204);

        cy.wait("@searchItems");
        cy.get("#holdings_table .bound-with-view").should("not.exist");
    });

    it("Hides the management controls without the permission", function () {
        const native_id = this.native.biblio.biblio_id;

        cy.intercept("GET", `/api/v1/biblios/${native_id}/items*`).as(
            "searchItems"
        );

        // catalogue only, no editcatalogue subpermissions
        cy.task("query", {
            sql: "UPDATE borrowers SET flags=4 WHERE borrowernumber=51",
        }).then(() => {
            cy.visit(
                `/cgi-bin/koha/catalogue/detail.pl?biblionumber=${native_id}`
            );
            cy.wait("@searchItems");
            cy.get("#holdings_table .bound-with-manage").should("not.exist");
            cy.get("#boundwith-toolbar-link").should("not.exist");
            cy.task("query", {
                sql: "UPDATE borrowers SET flags=1 WHERE borrowernumber=51",
            });
        });
    });
});
