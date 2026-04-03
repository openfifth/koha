import { mount } from "@cypress/vue";

function get_provider() {
    return {
        identity_provider_id: 1,
        code: "test_oauth",
        description: "Test OAuth Provider",
        protocol: "OAuth",
        enabled: true,
        icon_url: null,
        config: {
            key: "my_client_id",
            secret: "my_client_secret",
            authorize_url: "https://idp.example.com/authorize",
            token_url: "https://idp.example.com/token",
            userinfo_url: "",
            scope: "",
        },
        domains: [],
        hostnames: [],
        mappings: [],
    };
}

describe("Identity providers", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        // The provider component fetches all known hostnames on mount
        cy.intercept("GET", "/api/v1/auth/hostnames*", []);
    });

    it("List providers", () => {
        // GET returns empty list
        cy.intercept("GET", "/api/v1/auth/identity_providers*", []);
        cy.visit("/cgi-bin/koha/admin/identity_providers");
        cy.get("#providers_list").contains(
            "There are no identity providers configured"
        );

        // GET returns something
        let provider = get_provider();
        let providers = [provider];

        cy.intercept("GET", "/api/v1/auth/identity_providers*", {
            statusCode: 200,
            body: providers,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/auth/identity_providers/*", provider);
        cy.visit("/cgi-bin/koha/admin/identity_providers/");
        cy.get("#providers_list").contains("Showing 1 to 1 of 1 entries");
    });

    it("Add provider", () => {
        cy.intercept("GET", "/api/v1/auth/identity_providers**", {
            statusCode: 200,
            body: [],
        });

        cy.visit("/cgi-bin/koha/admin/identity_providers");
        cy.contains("New identity provider").click();
        cy.get("#providers_add h2").contains("New identity provider");
        cy.left_menu_active_item_is("Identity providers");

        // Required fields are validated
        cy.get("#providers_add").contains("Save").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length.gte",
            1
        );

        cy.get("#code").type("test_oauth");
        cy.get("#description").type("Test OAuth Provider");

        // Selecting OAuth shows OAuth-specific config fields
        cy.get("#protocol .vs__search").type("OAuth{enter}", { force: true });
        cy.get("#_config_key").should("be.visible");
        cy.get("#_config_secret").should("be.visible");
        cy.get("#_config_authorize_url").should("be.visible");
        cy.get("#_config_token_url").should("be.visible");
        // OIDC-only field should not be visible
        cy.get("#_config_well_known_url").should("not.exist");

        cy.get("#_config_key").type("my_client_id");
        cy.get("#_config_secret").type("my_client_secret");
        cy.get("#_config_authorize_url").type(
            "https://idp.example.com/authorize"
        );
        cy.get("#_config_token_url").type("https://idp.example.com/token");

        // Add a mapping relationship
        cy.contains("Add mapping").click();
        cy.get("#mappings_0 #mappings_provider_field_0").type("email");

        // Add a domain rule
        cy.contains("Add domain rule").click();
        cy.get("#domains_0 #domains_domain_0").type("library.org");

        // Submit the form, get 500
        cy.intercept("POST", "/api/v1/auth/identity_providers", {
            statusCode: 500,
        });
        cy.get("#providers_add").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        // Submit the form, success!
        let provider = get_provider();
        cy.intercept("POST", "/api/v1/auth/identity_providers", {
            statusCode: 201,
            body: provider,
        });
        cy.intercept("POST", "/api/v1/auth/identity_providers/*/mappings", {
            statusCode: 201,
            body: {},
        });
        cy.intercept("POST", "/api/v1/auth/identity_providers/*/domains", {
            statusCode: 201,
            body: {},
        });
        cy.get("#providers_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Identity provider created"
        );
    });

    it("Add provider - OIDC protocol shows correct fields", () => {
        cy.intercept("GET", "/api/v1/auth/identity_providers**", {
            statusCode: 200,
            body: [],
        });

        cy.visit("/cgi-bin/koha/admin/identity_providers/add");

        // Select OIDC - should show well_known_url, hide OAuth-specific fields
        cy.get("#protocol .vs__search").type("OIDC{enter}", { force: true });
        cy.get("#_config_well_known_url").should("be.visible");
        cy.get("#_config_authorize_url").should("not.exist");
        cy.get("#_config_token_url").should("not.exist");
    });

    it("Add provider - matchpoint validation", () => {
        cy.intercept("GET", "/api/v1/auth/identity_providers**", {
            statusCode: 200,
            body: [],
        });
        cy.intercept("GET", "/api/v1/auth/hostnames*", [
            { hostname_id: 1, hostname: "library.example.com" },
        ]);

        cy.visit("/cgi-bin/koha/admin/identity_providers/add");
        cy.get("#code").type("test_oauth");
        cy.get("#description").type("Test OAuth Provider");
        cy.get("#protocol .vs__search").type("OAuth{enter}", { force: true });
        cy.get("#_config_key").type("my_client_id");
        cy.get("#_config_secret").type("my_client_secret");
        cy.get("#_config_authorize_url").type(
            "https://idp.example.com/authorize"
        );
        cy.get("#_config_token_url").type("https://idp.example.com/token");

        // Add a hostname with a matchpoint but no corresponding mapping
        cy.contains("Add hostname").click();
        cy.get("#hostnames_0 #hostnames_hostname_0 .vs__search").type(
            "library.example.com{enter}",
            { force: true }
        );
        cy.get("#hostnames_0 #hostnames_matchpoint_0 .vs__search").type(
            "Email{enter}",
            { force: true }
        );

        // Submit without a matching mapping → should show validation error
        cy.intercept("POST", "/api/v1/auth/identity_providers", {
            statusCode: 201,
            body: { identity_provider_id: 1 },
        });
        cy.get("#providers_add").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "The selected matchpoint must have a corresponding attribute mapping"
        );
    });

    it("Edit provider", () => {
        let provider = get_provider();
        let providers = [provider];

        // Intercept the list load
        cy.intercept("GET", "/api/v1/auth/identity_providers?_page*", {
            statusCode: 200,
            body: providers,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-providers-list");

        cy.visit("/cgi-bin/koha/admin/identity_providers");
        cy.wait("@get-providers-list");

        // Intercept the single-provider fetch after clicking Edit
        cy.intercept("GET", "/api/v1/auth/identity_providers/*", provider).as(
            "get-provider"
        );

        cy.get("#providers_list table tbody tr:first").contains("Edit").click();
        cy.wait("@get-provider");
        cy.wait(500); // Allow Vue to populate the form
        cy.get("#providers_add h2").contains("Edit identity provider");
        cy.left_menu_active_item_is("Identity providers");

        // Form is pre-filled correctly
        cy.get("#code").should("have.value", provider.code);
        cy.get("#description").should("have.value", provider.description);

        // Submit the form, get 500
        cy.intercept("PUT", "/api/v1/auth/identity_providers/*", req => {
            req.reply({
                statusCode: 500,
                delay: 1000,
            });
        }).as("edit-provider");
        cy.get("#providers_add").contains("Save").click();
        cy.get("main div[class='modal_centered']").contains("Submitting...");
        cy.wait("@edit-provider");
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        // Submit the form, success!
        cy.intercept("PUT", "/api/v1/auth/identity_providers/*", {
            statusCode: 200,
            body: provider,
        });
        cy.get("#providers_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Identity provider updated"
        );
    });

    it("Show provider", () => {
        let provider = get_provider();
        let providers = [provider];

        cy.intercept("GET", "/api/v1/auth/identity_providers*", {
            statusCode: 200,
            body: providers,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/auth/identity_providers/*", provider).as(
            "get-provider"
        );

        cy.visit("/cgi-bin/koha/admin/identity_providers");
        let code_link = cy.get(
            "#providers_list table tbody tr:first td:first a"
        );
        code_link.should("have.text", provider.code);
        code_link.click();
        cy.wait("@get-provider");
        cy.get("#providers_show h2").contains(
            "Identity provider #" + provider.identity_provider_id
        );
        cy.left_menu_active_item_is("Identity providers");
    });

    it("Delete provider", () => {
        let provider = get_provider();
        let providers = [provider];

        // Delete from list
        cy.intercept("GET", "/api/v1/auth/identity_providers*", {
            statusCode: 200,
            body: providers,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/auth/identity_providers/*", provider);
        cy.visit("/cgi-bin/koha/admin/identity_providers");

        cy.get("#providers_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "delete this identity provider"
        );
        cy.contains(provider.code);

        // Accept the confirmation dialog, get 500
        cy.intercept("DELETE", "/api/v1/auth/identity_providers/*", {
            statusCode: 500,
        });
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        // Accept the confirmation dialog, success!
        cy.intercept("DELETE", "/api/v1/auth/identity_providers/*", {
            statusCode: 204,
            body: null,
        });
        cy.get("#providers_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "delete this identity provider"
        );
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Identity provider deleted"
        );

        // Delete from show
        cy.intercept("GET", "/api/v1/auth/identity_providers*", {
            statusCode: 200,
            body: providers,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/auth/identity_providers/*", provider).as(
            "get-provider"
        );
        cy.visit("/cgi-bin/koha/admin/identity_providers");
        let code_link = cy.get(
            "#providers_list table tbody tr:first td:first a"
        );
        code_link.click();
        cy.wait("@get-provider");
        cy.get("#providers_show h2").contains(
            "Identity provider #" + provider.identity_provider_id
        );

        cy.get("#providers_show #toolbar").contains("Delete").click();
        cy.get(".alert-warning.confirmation h1").contains(
            "delete this identity provider"
        );
        cy.contains("Yes, delete").click();

        // Make sure we return to the list after deleting from show
        cy.get("#providers_list table tbody tr:first");
    });
});
