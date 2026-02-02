import { mount } from "@cypress/vue";

describe("Shibboleth Field Mappings", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("List mappings", () => {
        // GET mappings returns 500
        cy.intercept("GET", "/api/v1/shibboleth/mappings*", {
            statusCode: 500,
            error: "Something went wrong",
        });
        cy.intercept("GET", "/api/v1/shibboleth/config", {
            statusCode: 200,
            body: cy.getShibbolethConfig(),
        });
        cy.visit("/cgi-bin/koha/shibboleth/shibboleth.pl");
        cy.get(".sidebar_menu").contains("Field Mappings").click();
        cy.get("main div[class='alert alert-warning']").contains(
            /Something went wrong/
        );

        // GET mappings returns empty list
        cy.intercept("GET", "/api/v1/shibboleth/mappings*", []);
        cy.visit("/cgi-bin/koha/shibboleth/mappings");
        cy.get("#mappings_list").contains(
            "There are no field mappings defined"
        );

        // GET mappings returns something
        let mapping = cy.getShibbolethMapping();
        let mappings = [mapping];

        cy.intercept("GET", "/api/v1/shibboleth/mappings*", {
            statusCode: 200,
            body: mappings,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/shibboleth/mappings/*", mapping);
        cy.visit("/cgi-bin/koha/shibboleth/mappings/");
        cy.get("#mappings_list").contains("Showing 1 to 1 of 1 entries");
    });

    it("Add mapping", () => {
        let mapping = cy.getShibbolethMapping();

        // No mappings
        cy.intercept("GET", "/api/v1/shibboleth/mappings**", {
            statusCode: 200,
            body: [],
        });
        cy.intercept("GET", "/api/v1/shibboleth/config", {
            statusCode: 200,
            body: cy.getShibbolethConfig(),
        });

        // Click the button in the toolbar
        cy.visit("/cgi-bin/koha/shibboleth/mappings");
        cy.contains("New field mapping").click();
        cy.get("#mappings_add h2").contains("New field mapping");
        cy.left_menu_active_item_is("Field Mappings");

        cy.get("#mappings_add").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.at.least",
            1
        );

        // Select koha_field from dropdown
        cy.get("#koha_field .vs__search").type("userid{enter}", {
            force: true,
        });

        // Fill in idp_field
        cy.get("#idp_field").type(mapping.idp_field);

        // Fill in default_content (optional)
        cy.get("#default_content").type("default_value");

        // Toggle is_matchpoint
        cy.get("#is_matchpoint_yes").click();
        cy.get("#is_matchpoint_yes").should("be.checked");

        cy.intercept("POST", "/api/v1/shibboleth/mappings", {
            statusCode: 500,
        });
        cy.get("#mappings_add").contains("Save").click();

        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        cy.intercept("POST", "/api/v1/shibboleth/mappings", {
            statusCode: 201,
            body: mapping,
        });
        cy.get("#mappings_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Mapping created"
        );
    });

    it("Edit mapping", () => {
        let mapping = cy.getShibbolethMapping();
        let mappings = [mapping];

        cy.intercept("GET", "/api/v1/shibboleth/config", {
            statusCode: 200,
            body: cy.getShibbolethConfig(),
        });

        // Intercept follow-up 'search' request after entering /mappings
        cy.intercept("GET", "/api/v1/shibboleth/mappings?_page*", {
            statusCode: 200,
            body: mappings,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-single-mapping-search-result");
        cy.visit("/cgi-bin/koha/shibboleth/mappings");
        cy.wait("@get-single-mapping-search-result");

        // Intercept request after edit click
        cy.intercept("GET", "/api/v1/shibboleth/mappings/*", mapping).as(
            "get-mapping"
        );

        // Click the 'Edit' button from the list
        cy.get("#mappings_list table tbody tr:first").contains("Edit").click();
        cy.wait("@get-mapping");
        cy.get("#mappings_add h2").contains("Edit field mapping");
        cy.left_menu_active_item_is("Field Mappings");

        // Form has been correctly filled in
        cy.get("#koha_field .vs__selected").should(
            "contain",
            mapping.koha_field
        );
        cy.get("#idp_field").should("have.value", mapping.idp_field);
        cy.get("#is_matchpoint_yes").should("be.checked");

        cy.intercept("PUT", "/api/v1/shibboleth/mappings/*", {
            statusCode: 500,
        });
        cy.get("#mappings_add").contains("Save").click();

        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        cy.intercept("PUT", "/api/v1/shibboleth/mappings/*", {
            statusCode: 200,
            body: mapping,
        });
        cy.get("#mappings_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Mapping updated"
        );
    });

    it("Show mapping", () => {
        let mapping = cy.getShibbolethMapping();
        let mappings = [mapping];

        cy.intercept("GET", "/api/v1/shibboleth/config", {
            statusCode: 200,
            body: cy.getShibbolethConfig(),
        });

        // Click the "name" link from the list
        cy.intercept("GET", "/api/v1/shibboleth/mappings*", {
            statusCode: 200,
            body: mappings,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/shibboleth/mappings/*", mapping).as(
            "get-mapping"
        );
        cy.visit("/cgi-bin/koha/shibboleth/mappings");
        let name_link = cy.get(
            "#mappings_list table tbody tr:first td:first a"
        );
        name_link.should("have.text", mapping.koha_field);
        name_link.click();
        cy.wait("@get-mapping");
        cy.get("#mappings_show h2").contains(
            "Field Mapping #" + mapping.mapping_id
        );
        cy.left_menu_active_item_is("Field Mappings");
    });

    it("Delete mapping", () => {
        let mapping = cy.getShibbolethMapping();
        let mappings = [mapping];

        cy.intercept("GET", "/api/v1/shibboleth/config", {
            statusCode: 200,
            body: cy.getShibbolethConfig(),
        });

        // Delete from list
        // Click the 'Delete' button from the list
        cy.intercept("GET", "/api/v1/shibboleth/mappings*", {
            statusCode: 200,
            body: mappings,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/shibboleth/mappings/*", mapping);
        cy.visit("/cgi-bin/koha/shibboleth/mappings");

        cy.get("#mappings_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this field mapping"
        );
        cy.contains(mapping.koha_field);

        // Accept the confirmation dialog, get 500
        cy.intercept("DELETE", "/api/v1/shibboleth/mappings/*", {
            statusCode: 500,
        });
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        // Accept the confirmation dialog, success!
        cy.intercept("DELETE", "/api/v1/shibboleth/mappings/*", {
            statusCode: 204,
            body: null,
        });
        cy.get("#mappings_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this field mapping"
        );
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains("Mapping")
            .contains("deleted");

        // Delete from show
        // Click the "name" link from the list
        cy.intercept("GET", "/api/v1/shibboleth/mappings*", {
            statusCode: 200,
            body: mappings,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/shibboleth/mappings/*", mapping).as(
            "get-mapping"
        );
        cy.visit("/cgi-bin/koha/shibboleth/mappings");
        let name_link = cy.get(
            "#mappings_list table tbody tr:first td:first a"
        );
        name_link.should("have.text", mapping.koha_field);
        name_link.click();
        cy.wait("@get-mapping");
        cy.get("#mappings_show h2").contains(
            "Field Mapping #" + mapping.mapping_id
        );

        cy.get("#mappings_show #toolbar").contains("Delete").click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this field mapping"
        );
        cy.contains("Yes, delete").click();

        // Make sure we return to list after deleting from show
        cy.get("#mappings_list table tbody tr:first");
    });
});
