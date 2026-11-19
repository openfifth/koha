import { mount } from "@cypress/vue";

function get_supplying_agency() {
    return {
        iso18626_supplying_agency_id: 1,
        name: "Test Supplier",
        type: "ISIL",
        agency_id: "GB-SUP",
        account_id: "TEST-001",
        securityCode: "secret123",
        endpoint: "https://supplier.example/api/v1/public/ill/iso18626",
    };
}

describe("Supplying agencies CRUD operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.set_syspref("ILLModule", 1);
    });

    it("List supplying agencies", () => {
        // GET supplying agencies returns 500
        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies*", {
            statusCode: 500,
        });
        cy.visit("/cgi-bin/koha/ill/ill.pl");
        cy.get(".sidebar_menu").contains("Supplying agencies").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // GET supplying agencies returns empty list
        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies*", []);
        cy.visit("/cgi-bin/koha/ill/iso18626_supplying_agencies");
        cy.get("#iso18626_supplying_agencys_list").contains(
            "There are no supplying agencies defined"
        );

        // GET supplying agencies returns populated list
        let agency = get_supplying_agency();
        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies*", {
            statusCode: 200,
            body: [agency],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.visit("/cgi-bin/koha/ill/iso18626_supplying_agencies");
        cy.get("#iso18626_supplying_agencys_list").contains(
            "Showing 1 to 1 of 1 entries"
        );
    });

    it("Add supplying agency", () => {
        let agency = get_supplying_agency();

        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies*", {
            statusCode: 200,
            body: [],
        }).as("getAgencies");

        cy.visit("/cgi-bin/koha/ill/iso18626_supplying_agencies");
        cy.wait("@getAgencies");
        cy.contains("New supplying agency").click();
        cy.get("#iso18626_supplying_agencys_add h2").contains(
            "New supplying agency"
        );

        // Clicking save without required fields shows validation errors
        cy.get("#iso18626_supplying_agencys_add").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.above",
            0
        );

        // Fill in required fields
        cy.get("#name").type(agency.name);
        cy.get("#type .vs__search").type(agency.type + "{enter}", {
            force: true,
        });
        cy.get("#agency_id").type(agency.agency_id);
        cy.get("#endpoint").type(agency.endpoint);
        cy.get("#account_id").type(agency.account_id);
        cy.get("#securityCode").type(agency.securityCode);

        // Submit, success
        cy.intercept("POST", "/api/v1/ill/iso18626_supplying_agencies", {
            statusCode: 201,
            body: agency,
        });
        cy.get("#iso18626_supplying_agencys_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Supplying agency created"
        );
    });

    it("Edit supplying agency", () => {
        let agency = get_supplying_agency();
        let agencies = [agency];

        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies?_page*", {
            statusCode: 200,
            body: agencies,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("getAgencies");

        cy.visit("/cgi-bin/koha/ill/iso18626_supplying_agencies");
        cy.wait("@getAgencies");

        cy.intercept(
            "GET",
            "/api/v1/ill/iso18626_supplying_agencies/*",
            agency
        ).as("getAgency");

        cy.get("#iso18626_supplying_agencys_list table tbody tr:first")
            .contains("Edit")
            .click();
        cy.wait("@getAgency");
        cy.get("#iso18626_supplying_agencys_add h2").contains(
            "Edit supplying agency #" + agency.iso18626_supplying_agency_id
        );

        // Form is pre-filled with existing values
        cy.get("#name").should("have.value", agency.name);
        cy.get("#account_id").should("have.value", agency.account_id);

        // Submit, get 500
        cy.intercept("PUT", "/api/v1/ill/iso18626_supplying_agencies/*", {
            statusCode: 500,
        });
        cy.get("#iso18626_supplying_agencys_add").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // Submit, success
        cy.intercept("PUT", "/api/v1/ill/iso18626_supplying_agencies/*", {
            statusCode: 200,
            body: agency,
        });
        cy.get("#iso18626_supplying_agencys_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Supplying agency updated"
        );
    });

    it("Show supplying agency", () => {
        let agency = get_supplying_agency();

        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies*", {
            statusCode: 200,
            body: [agency],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("getAgencies");
        cy.intercept(
            "GET",
            "/api/v1/ill/iso18626_supplying_agencies/*",
            agency
        ).as("getAgency");

        cy.visit("/cgi-bin/koha/ill/iso18626_supplying_agencies");
        cy.wait("@getAgencies");

        cy.get(
            "#iso18626_supplying_agencys_list table tbody tr:first td:first a"
        ).click();
        cy.wait("@getAgency");
        cy.get("#iso18626_supplying_agencys_show h2").contains(
            "Supplying agency #" + agency.iso18626_supplying_agency_id
        );
    });

    it("Delete supplying agency", () => {
        let agency = get_supplying_agency();

        cy.intercept("GET", "/api/v1/ill/iso18626_supplying_agencies*", {
            statusCode: 200,
            body: [agency],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("getAgencies");
        cy.intercept(
            "GET",
            "/api/v1/ill/iso18626_supplying_agencies/*",
            agency
        );

        cy.visit("/cgi-bin/koha/ill/iso18626_supplying_agencies");

        cy.get("#iso18626_supplying_agencys_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this supplying agency"
        );
        cy.contains(agency.name);

        // Accept the confirmation, get 500
        cy.intercept("DELETE", "/api/v1/ill/iso18626_supplying_agencies/*", {
            statusCode: 500,
        });
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // Accept the confirmation, success
        cy.intercept("DELETE", "/api/v1/ill/iso18626_supplying_agencies/*", {
            statusCode: 204,
            body: null,
        });
        cy.get("#iso18626_supplying_agencys_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this supplying agency"
        );
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains("Supplying agency")
            .contains("deleted");
    });
});
