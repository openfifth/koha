describe("Import profiles list", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("shows an empty list", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains(
            "There are no import profiles defined"
        );
    });

    it("keeps a plugin format and tolerates null fields when editing", () => {
        const profile = {
            profile_id: 3,
            name: "Plugin profile",
            record_type: "biblio",
            encoding: "UTF-8",
            format: "Koha::Plugin::Com::Example::Importer",
            matcher_id: null,
            template_id: null,
            overlay_action: null,
            nomatch_action: null,
            item_action: null,
            parse_items: null,
            comments: null,
        };
        cy.intercept("GET", "/api/v1/import_batch_profiles/3", {
            statusCode: 200,
            body: profile,
        });
        cy.intercept("PUT", "/api/v1/import_batch_profiles/3", req => {
            req.reply({ statusCode: 200, body: { ...profile, ...req.body } });
        }).as("update");
        cy.intercept("GET", "/api/v1/import_batch_profiles?*", {
            statusCode: 200,
            body: [profile],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/edit/3");
        cy.get("#import_batch_profiles_add").should("be.visible");
        cy.get("#name").should("have.value", "Plugin profile");
        cy.get("#format").contains("Koha::Plugin::Com::Example::Importer");
        cy.get("#name").clear();
        cy.get("#name").type("Renamed profile");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@update").then(({ request }) => {
            expect(request.body.format).to.eq(
                "Koha::Plugin::Com::Example::Importer"
            );
            expect(request.body.name).to.eq("Renamed profile");
            expect(request.body).to.not.have.property("profile_id");
            expect(request.body.overlay_action).to.eq(null);
            expect(request.body.comments).to.eq(null);
        });
    });

    it("creates a profile with the default values", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.intercept("POST", "/api/v1/import_batch_profiles", {
            statusCode: 201,
            body: { profile_id: 9, name: "New one" },
        }).as("create");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        cy.get("#name").type("New one");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@create").then(({ request }) => {
            expect(request.body).to.deep.include({
                name: "New one",
                record_type: "biblio",
                encoding: "UTF-8",
                format: "ISO2709",
                overlay_action: "replace",
                nomatch_action: "create_new",
                item_action: "always_add",
                parse_items: true,
            });
        });
        cy.get("#import_batch_profiles_list").should("exist");
    });
});
