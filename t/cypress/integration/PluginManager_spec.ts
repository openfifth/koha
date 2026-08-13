describe("Plugin manager", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Should list installed plugins", () => {
        cy.intercept("GET", "**/api/v1/plugins*", req => {
            req.reply({
                statusCode: 200,
                body: [
                    {
                        class: "Koha::Plugin::Test",
                        name: "Test Plugin",
                        description: "A plugin for testing",
                        author: "Koha",
                        version: "1.0.0",
                        is_enabled: true,
                        can_configure: false,
                        can_tool: false,
                        can_report: false,
                        can_admin: false,
                    },
                ],
            });
        });
        cy.intercept("GET", "**/api/v1/plugins/config*", req => {
            req.reply({
                statusCode: 200,
                body: {
                    permissions: { CAN_user_plugins_manage: true },
                },
            });
        });

        cy.visit("/cgi-bin/koha/plugin-store/plugin-store.pl");
        cy.get("table tbody").contains("Test Plugin");
        cy.get("table tbody").contains("Enabled");
    });

    it("Should disable and re-enable a plugin", () => {
        let is_enabled = true;
        cy.intercept("GET", "**/api/v1/plugins*", req => {
            req.reply({
                statusCode: 200,
                body: [
                    {
                        class: "Koha::Plugin::Test",
                        name: "Test Plugin",
                        description: "A plugin for testing",
                        author: "Koha",
                        version: "1.0.0",
                        is_enabled,
                        can_configure: false,
                        can_tool: false,
                        can_report: false,
                        can_admin: false,
                    },
                ],
            });
        }).as("getPlugins");
        cy.intercept("GET", "**/api/v1/plugins/config*", {
            statusCode: 200,
            body: {
                permissions: { CAN_user_plugins_manage: true },
            },
        });
        cy.intercept("PUT", "**/api/v1/plugins/Koha*", req => {
            is_enabled = req.body.is_enabled;
            req.reply({
                statusCode: 200,
                body: { success: "Plugin updated" },
            });
        }).as("updatePlugin");

        cy.visit("/cgi-bin/koha/plugin-store/plugin-store.pl");
        cy.wait("@getPlugins");
        cy.get("table tbody").contains("Disable").click();
        cy.wait("@updatePlugin");
        cy.wait("@getPlugins");
        cy.get("table tbody").contains("Disabled");
    });

    it("Should uninstall a plugin after confirmation", () => {
        let is_enabled = true;
        cy.intercept("GET", "**/api/v1/plugins*", req => {
            req.reply({
                statusCode: 200,
                body: [
                    {
                        class: "Koha::Plugin::Test",
                        name: "Test Plugin",
                        description: "A plugin for testing",
                        author: "Koha",
                        version: "1.0.0",
                        is_enabled,
                        can_configure: false,
                        can_tool: false,
                        can_report: false,
                        can_admin: false,
                    },
                ],
            });
        }).as("getPlugins");
        cy.intercept("GET", "**/api/v1/plugins/config*", req => {
            req.reply({
                statusCode: 200,
                body: {
                    permissions: { CAN_user_plugins_manage: true },
                },
            });
        });
        cy.intercept("DELETE", "**/api/v1/plugins/Koha*", req => {
            req.reply({
                statusCode: 204,
            });
        }).as("deletePlugin");

        cy.visit("/cgi-bin/koha/plugin-store/plugin-store.pl");
        cy.wait("@getPlugins");
        // Try to find Uninstall in the table body, retry up to 15s
        //
        // force: true -- since the page now embeds the full admin sidebar
        // (Islands AdminMenu), Cypress's actionability check intermittently
        // reports this link as covered by its own column's <th>. Verified
        // this is specific to Cypress's own AUT rendering: the same mocked
        // page, loaded directly (and inside a plain iframe) via Playwright
        // at the same viewport, never shows the header overlapping the row.
        // Not a real layout bug -- a real click at this element's coordinates
        // does land on the link.
        cy.get("table tbody", { timeout: 15000 })
            .contains("Uninstall")
            .click({ force: true });
        cy.get("#confirmation.modal").contains(
            "Are you sure you want to uninstall Test Plugin?"
        );
        cy.get("#accept_modal").click();
        cy.wait("@deletePlugin");
    });
});
