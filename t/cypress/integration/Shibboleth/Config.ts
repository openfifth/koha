import { mount } from "@cypress/vue";

describe("Shibboleth Configuration", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Should display the home page", () => {
        cy.visit("/cgi-bin/koha/shibboleth/shibboleth.pl");
        cy.get("h2").contains("Shibboleth Configuration");
    });

    it("Should navigate to config edit page", () => {
        let config = cy.getShibbolethConfig();

        cy.intercept("GET", "/api/v1/shibboleth/config*", {
            statusCode: 200,
            body: config,
        }).as("getConfig");

        cy.visit("/cgi-bin/koha/shibboleth/shibboleth.pl");

        cy.get(".sidebar_menu").contains("Configuration").click();
        cy.wait("@getConfig");
        cy.left_menu_active_item_is("Configuration");
    });

    it("Should handle config fetch error", () => {
        cy.intercept("GET", "/api/v1/shibboleth/config*", {
            statusCode: 500,
            body: { error: "Something went wrong" },
        }).as("getConfigError");

        cy.visit("/cgi-bin/koha/shibboleth/config");
        cy.wait("@getConfigError");
        cy.get("main div[class='alert alert-warning']").contains(
            /Something went wrong/
        );
    });

    it("Should edit configuration", () => {
        let config = cy.getShibbolethConfig();

        cy.intercept("GET", "/api/v1/shibboleth/config*", {
            statusCode: 200,
            body: config,
        }).as("getConfig");

        cy.visit("/cgi-bin/koha/shibboleth/config");
        cy.wait("@getConfig");

        cy.get("#configs_add h2").contains("Edit Shibboleth Configuration");

        cy.get("#force_opac_sso_no").should("be.checked");
        cy.get("#force_staff_sso_no").should("be.checked");
        cy.get("#autocreate_no").should("be.checked");
        cy.get("#sync_no").should("be.checked");
        cy.get("#welcome_no").should("be.checked");

        cy.get("#force_opac_sso_yes").click();
        cy.get("#force_opac_sso_yes").should("be.checked");

        cy.get("#force_staff_sso_yes").click();
        cy.get("#force_staff_sso_yes").should("be.checked");

        cy.get("#autocreate_yes").click();
        cy.get("#autocreate_yes").should("be.checked");

        cy.get("#sync_yes").click();
        cy.get("#sync_yes").should("be.checked");

        cy.get("#welcome_yes").click();
        cy.get("#welcome_yes").should("be.checked");

        cy.intercept("PUT", "/api/v1/shibboleth/config*", {
            statusCode: 500,
        });
        cy.get("#configs_add").contains("Save").click();

        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        let updatedConfig = {
            ...config,
            force_opac_sso: true,
            force_staff_sso: true,
            autocreate: true,
            sync: true,
            welcome: true,
        };
        cy.intercept("PUT", "/api/v1/shibboleth/config*", {
            statusCode: 200,
            body: updatedConfig,
        });
        cy.get("#configs_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Configuration updated"
        );
    });

    it("Should handle loading state during edit", () => {
        let config = cy.getShibbolethConfig();

        cy.intercept("GET", "/api/v1/shibboleth/config*", {
            statusCode: 200,
            body: config,
        }).as("getConfig");

        cy.visit("/cgi-bin/koha/shibboleth/config");
        cy.wait("@getConfig");

        cy.get("#force_opac_sso_yes").click();

        cy.intercept("PUT", "/api/v1/shibboleth/config*", req => {
            req.reply({
                statusCode: 200,
                body: { ...config, force_opac_sso: true },
                delay: 1000,
            });
        });
        cy.get("#configs_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Configuration updated"
        );
    });

    it("Should cancel editing and return to home", () => {
        let config = cy.getShibbolethConfig();

        cy.intercept("GET", "/api/v1/shibboleth/config*", {
            statusCode: 200,
            body: config,
        }).as("getConfig");

        cy.visit("/cgi-bin/koha/shibboleth/config");
        cy.wait("@getConfig");

        cy.contains("Cancel").click();

        cy.get("h2").contains("Shibboleth Configuration");
    });
});
