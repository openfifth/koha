// Note: the Cypress support file fails a test on any console.warn from the
// page, so Vue warnings (bad prop types, unexpected nulls...) fail these tests.
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
            expect(request.body.nomatch_action).to.eq(null);
            expect(request.body.item_action).to.eq(null);
            expect(request.body.parse_items).to.eq(null);
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

describe("Import profiles matcher and template names", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept("GET", "/api/v1/record_matchers*", {
            body: [
                {
                    record_matcher_id: 1,
                    code: "ISBN",
                    description: "ISBN match",
                    record_type: "biblio",
                    threshold: 100,
                },
            ],
        });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            body: [{ marc_modification_template_id: 7, name: "Strip 9xx" }],
        });
    });

    it("shows names, and Unknown for ids that no longer exist", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [
                {
                    profile_id: 1,
                    name: "Known",
                    matcher_id: 1,
                    template_id: 7,
                    record_type: "biblio",
                    format: "ISO2709",
                    encoding: "UTF-8",
                    overlay_action: "replace",
                    nomatch_action: "create_new",
                    item_action: "always_add",
                    parse_items: true,
                    comments: null,
                },
                {
                    profile_id: 2,
                    name: "Orphan",
                    matcher_id: 99,
                    template_id: 98,
                    record_type: "biblio",
                    format: "ISO2709",
                    encoding: "UTF-8",
                    overlay_action: null,
                    nomatch_action: null,
                    item_action: null,
                    parse_items: null,
                    comments: null,
                },
            ],
            headers: { "X-Base-Total-Count": "2", "X-Total-Count": "2" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("ISBN");
        cy.get("#import_batch_profiles_list").contains("Strip 9xx");
        cy.get("#import_batch_profiles_list").contains("Unknown (99)");
        cy.get("#import_batch_profiles_list").contains("Unknown (98)");
    });

    it("keeps a stored id that no longer exists when saving", () => {
        const profile = {
            profile_id: 2,
            name: "Orphan",
            matcher_id: 99,
            template_id: 98,
            record_type: "biblio",
            format: "ISO2709",
            encoding: "UTF-8",
            overlay_action: null,
            nomatch_action: null,
            item_action: null,
            parse_items: null,
            comments: null,
        };
        cy.intercept("GET", "/api/v1/import_batch_profiles/2", {
            statusCode: 200,
            body: profile,
        });
        cy.intercept("GET", "/api/v1/import_batch_profiles?*", {
            statusCode: 200,
            body: [profile],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
        cy.intercept("PUT", "/api/v1/import_batch_profiles/2", req => {
            req.reply({ statusCode: 200, body: { ...profile, ...req.body } });
        }).as("update");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/edit/2");
        cy.get("#import_batch_profiles_add").should("be.visible");
        cy.get("#name").should("have.value", "Orphan");
        cy.get("#name").clear();
        cy.get("#name").type("Orphan renamed");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@update").then(({ request }) => {
            expect(request.body.matcher_id).to.eq(99);
            expect(request.body.template_id).to.eq(98);
        });
    });

    it("offers the matchers and templates in the form", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.intercept("POST", "/api/v1/import_batch_profiles", {
            statusCode: 201,
            body: { profile_id: 9, name: "With rule" },
        }).as("create");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        cy.get("#name").type("With rule");
        cy.get("#matcher_id").click();
        cy.get(".vs__dropdown-menu").contains("ISBN (ISBN match)").click();
        cy.get("#template_id").click();
        cy.get(".vs__dropdown-menu").contains("Strip 9xx").click();
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@create").then(({ request }) => {
            expect(request.body.matcher_id).to.eq(1);
            expect(request.body.template_id).to.eq(7);
        });
    });

    // vue-select only re-resolves a stored id to its label when its `options`
    // prop is replaced, so options that arrive after the form has rendered
    // used to leave the raw id on screen. Delay the lookups to force that order.
    it("shows the matching rule and template names, not their ids, when editing", () => {
        cy.intercept("GET", "/api/v1/record_matchers*", {
            delay: 500,
            body: [
                {
                    record_matcher_id: 1,
                    code: "ISBN",
                    description: "ISBN match",
                    record_type: "biblio",
                    threshold: 100,
                },
            ],
        });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            delay: 500,
            body: [{ marc_modification_template_id: 7, name: "Strip 9xx" }],
        });
        cy.intercept("GET", "/api/v1/import_batch_profiles/6", {
            profile_id: 6,
            name: "Has both",
            matcher_id: 1,
            template_id: 7,
            record_type: "biblio",
            format: "ISO2709",
            encoding: "UTF-8",
            overlay_action: "replace",
            nomatch_action: "create_new",
            item_action: "always_add",
            parse_items: true,
            comments: null,
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/edit/6");
        cy.get("#name").should("have.value", "Has both");
        cy.get("#matcher_id")
            .closest(".v-select")
            .find(".vs__selected")
            .should("have.text", "ISBN (ISBN match)");
        cy.get("#template_id")
            .closest(".v-select")
            .find(".vs__selected")
            .should("have.text", "Strip 9xx");
    });

    // The form follows the order and grouping of the "Stage MARC records for
    // import" page (file, template, matching, items), with shorter headings.
    it("groups the form fields into fieldsets in the staging page order", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        const groups: Array<[string, Array<string>]> = [
            ["Profile", ["name", "comments"]],
            ["File format", ["record_type", "encoding", "format"]],
            ["MARC modification", ["template_id"]],
            [
                "Record matching",
                ["matcher_id", "overlay_action", "nomatch_action"],
            ],
            ["Items", ["parse_items", "item_action"]],
        ];
        cy.get("#import_batch_profiles_add form fieldset.rows").should(
            "have.length",
            groups.length
        );
        groups.forEach(([legend, ids], i) => {
            cy.get("#import_batch_profiles_add form fieldset.rows")
                .eq(i)
                .within(() => {
                    cy.get("legend").should("have.text", legend);
                    cy.get("ol > li").should("have.length", ids.length);
                    cy.get("ol > li").each(($li, j) => {
                        expect(
                            $li.find("#" + ids[j]).length,
                            `${legend}: field ${j + 1} is ${ids[j]}`
                        ).to.eq(1);
                    });
                });
        });
    });

    it("lists the columns in the same order as the form", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains(
            "There are no import profiles defined"
        );
        // An empty list shows no table, so use one row.
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [
                {
                    profile_id: 1,
                    name: "One",
                    matcher_id: null,
                    template_id: null,
                    record_type: "biblio",
                    format: "ISO2709",
                    encoding: "UTF-8",
                    overlay_action: "replace",
                    nomatch_action: "create_new",
                    item_action: "always_add",
                    parse_items: true,
                    comments: null,
                },
            ],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list thead th").then($headerCells => {
            const headers = [...$headerCells].map(th => th.textContent.trim());
            expect(headers).to.include.ordered.members([
                "ID",
                "Name",
                "Record type",
                "Character encoding",
                "Format",
                "MARC modification template",
                "Matching rule",
                "Action if matching record found",
                "Action if no match is found",
                "Check for embedded item record data",
                "How to process items",
                "Comments",
            ]);
        });
    });

    it("styles the dropdowns with the vue-select stylesheet", () => {
        // Behavioural tests pass even when the vue-select CSS is missing (the
        // widget then renders as bare inputs and oversized icons), so assert
        // on layout the stylesheet provides.
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        cy.get("#matcher_id")
            .closest(".v-select")
            .find(".vs__dropdown-toggle")
            .should("have.css", "display", "flex");
        cy.get("#record_type")
            .closest(".v-select")
            .find(".vs__dropdown-toggle")
            .should("have.css", "display", "flex");
    });

    // The API schema wants an integer or null for matcher_id/template_id, and
    // the shared form builder would otherwise send "" for an untouched select.
    // The POST stub below would happily accept anything, so assert the body.
    it("sends null, not an empty string, for a template that was left unset", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.intercept("POST", "/api/v1/import_batch_profiles", {
            statusCode: 201,
            body: { profile_id: 9, name: "Rule only" },
        }).as("create");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        cy.get("#name").type("Rule only");
        cy.get("#matcher_id").click();
        cy.get(".vs__dropdown-menu").contains("ISBN (ISBN match)").click();
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@create").then(({ request }) => {
            expect(request.body.matcher_id).to.eq(1);
            expect(request.body.template_id).to.be.null;
        });
    });

    it("sends null for both when neither a rule nor a template is chosen", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.intercept("POST", "/api/v1/import_batch_profiles", {
            statusCode: 201,
            body: { profile_id: 9, name: "Neither" },
        }).as("create");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        cy.get("#name").type("Neither");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@create").then(({ request }) => {
            expect(request.body.matcher_id).to.be.null;
            expect(request.body.template_id).to.be.null;
        });
    });

    it("does not say Unknown when a lookup fails", () => {
        cy.intercept("GET", "/api/v1/record_matchers*", {
            statusCode: 500,
            body: { error: "boom" },
        });
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [
                {
                    profile_id: 1,
                    name: "Known",
                    matcher_id: 1,
                    template_id: 7,
                    record_type: "biblio",
                    format: "ISO2709",
                    encoding: "UTF-8",
                    overlay_action: null,
                    nomatch_action: null,
                    item_action: null,
                    parse_items: null,
                    comments: null,
                },
            ],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("Known");
        cy.get("#import_batch_profiles_list").contains("Strip 9xx");
        cy.get("#import_batch_profiles_list").contains("Unavailable (1)");
        cy.get("#import_batch_profiles_list")
            .contains("Unknown")
            .should("not.exist");
    });

    it("escapes markup in names shown in the list", () => {
        cy.intercept("GET", "/api/v1/record_matchers*", {
            body: [
                {
                    record_matcher_id: 1,
                    code: "ISBN",
                    description: '<img src=x onerror="window.__xss=1">',
                    record_type: "biblio",
                    threshold: 100,
                },
            ],
        });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            body: [{ marc_modification_template_id: 7, name: "<b>x</b>" }],
        });
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [
                {
                    profile_id: 1,
                    name: "<i>profile</i>",
                    matcher_id: 1,
                    template_id: 7,
                    record_type: '<img src=x onerror="window.__xss=1">',
                    format: "ISO2709",
                    encoding: "UTF-8",
                    overlay_action: "<b>overlay</b>",
                    nomatch_action: "<b>nomatch</b>",
                    item_action: '<img src=x onerror="window.__xss=2">',
                    parse_items: null,
                    comments: "<u>note</u>",
                },
            ],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("<img src=x");
        cy.get("#import_batch_profiles_list").contains("<b>x</b>");
        cy.get("#import_batch_profiles_list").contains("<i>profile</i>");
        cy.get("#import_batch_profiles_list").contains("<u>note</u>");
        cy.get("#import_batch_profiles_list").contains("<b>overlay</b>");
        cy.get("#import_batch_profiles_list").contains("<b>nomatch</b>");
        cy.get('#import_batch_profiles_list img[src="x"]').should("not.exist");
        cy.get("#import_batch_profiles_list tbody b").should("not.exist");
        cy.window().its("__xss").should("not.exist");
    });
});

describe("Import profiles duplicate", () => {
    const source = {
        profile_id: 5,
        name: "x".repeat(100),
        matcher_id: null,
        template_id: null,
        record_type: "auth",
        format: "MARCXML",
        encoding: "MARC-8",
        overlay_action: "ignore",
        nomatch_action: "ignore",
        item_action: "ignore",
        parse_items: false,
        comments: "hello",
    };

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept("GET", "/api/v1/record_matchers*", { body: [] });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            body: [],
        });
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [source],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
    });

    it("opens the add form pre-filled, with a truncated name", () => {
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("Duplicate").click();
        cy.location("search").should("eq", "?copy=5");
        cy.get("#name").invoke("val").should("have.length", 100);
        cy.get("#name")
            .invoke("val")
            .should("match", /^Copy of /);
        cy.get("#record_type").contains("Authority");
        cy.get("#format").contains("MARCXML");
        cy.get("#encoding").contains("MARC 8");
        cy.get("#overlay_action").contains("Ignore");
        cy.get("#comments").should("have.value", "hello");
        cy.get("#parse_items").should("not.be.checked");

        cy.intercept("POST", "/api/v1/import_batch_profiles", req => {
            req.reply({ statusCode: 201, body: {} });
        }).as("create");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@create").then(({ request }) => {
            expect(request.body).to.not.have.property("profile_id");
            expect(request.body.name).to.match(/^Copy of x+$/);
            expect(request.body.name).to.have.length(100);
            expect(request.body.record_type).to.equal("auth");
            expect(request.body.format).to.equal("MARCXML");
            expect(request.body.encoding).to.equal("MARC-8");
            expect(request.body.item_action).to.equal("ignore");
            expect(request.body.parse_items).to.equal(false);
            expect(request.body.comments).to.equal("hello");
        });
    });

    it("keeps the copied name code point safe when an astral character straddles the cut", () => {
        // "Copy of " is 8 UTF-16 code units; 91 x's put the emoji's
        // surrogate pair across the 100 code unit boundary, where a
        // naive String.prototype.slice leaves a lone surrogate.
        const astralSource = {
            ...source,
            profile_id: 6,
            name: "x".repeat(91) + "😀" + "y".repeat(4),
        };
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [astralSource],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });

        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("Duplicate").click();
        cy.location("search").should("eq", "?copy=6");
        cy.get("#name")
            .invoke("val")
            .then(val => {
                expect(Array.from(val).length).to.be.at.most(100);
                const loneSurrogate =
                    /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
                expect(loneSurrogate.test(val)).to.be.false;

                cy.intercept("POST", "/api/v1/import_batch_profiles", req => {
                    req.reply({ statusCode: 201, body: {} });
                }).as("createAstral");
                cy.get("#import_batch_profiles_add form").submit();
                cy.wait("@createAstral").then(({ request }) => {
                    expect(request.body.name).to.equal(val);
                });
            });
    });

    it("shows the matching rule and template names, not their ids, on the copy", () => {
        cy.intercept("GET", "/api/v1/record_matchers*", {
            delay: 500,
            body: [
                {
                    record_matcher_id: 1,
                    code: "ISBN",
                    description: "ISBN match",
                    record_type: "biblio",
                    threshold: 100,
                },
            ],
        });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            delay: 500,
            body: [{ marc_modification_template_id: 7, name: "Strip 9xx" }],
        });
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [{ ...source, matcher_id: 1, template_id: 7 }],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("Duplicate").click();
        cy.get("#name")
            .invoke("val")
            .should("match", /^Copy of /);
        cy.get("#matcher_id")
            .closest(".v-select")
            .find(".vs__selected")
            .should("have.text", "ISBN (ISBN match)");
        cy.get("#template_id")
            .closest(".v-select")
            .find(".vs__selected")
            .should("have.text", "Strip 9xx");
    });

    it("gives defaults for a plain New after a Duplicate", () => {
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.get("#import_batch_profiles_list").contains("Duplicate").click();
        cy.get("#name")
            .invoke("val")
            .should("match", /^Copy of /);
        cy.get("#import_batch_profiles_add").contains("Cancel").click();
        cy.get("#import_batch_profiles_list").should("exist");
        cy.contains("a, button", "New import profile").click();
        cy.get("#name").should("have.value", "");
        cy.get("#record_type").contains("Bibliographic");
        cy.get("#comments").should("have.value", "");
        cy.get("#parse_items").should("be.checked");
    });

    it("falls back to defaults on a reload of ?copy=", () => {
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add?copy=5");
        cy.get("#import_batch_profiles_add").should("be.visible");
        cy.get("#name").should("have.value", "");
        cy.get("#record_type").contains("Bibliographic");
        cy.get("#parse_items").should("be.checked");
    });
});

describe("Import profiles delete, menu and save feedback", () => {
    const profile = (overrides = {}) => ({
        profile_id: 1,
        name: "Profile 1",
        matcher_id: null,
        template_id: null,
        record_type: "biblio",
        format: "ISO2709",
        encoding: "UTF-8",
        overlay_action: "replace",
        nomatch_action: "create_new",
        item_action: "always_add",
        parse_items: true,
        comments: null,
        ...overrides,
    });
    const listOf = (rows: Array<object>) => ({
        statusCode: 200,
        body: rows,
        headers: {
            "X-Base-Total-Count": String(rows.length),
            "X-Total-Count": String(rows.length),
        },
    });
    const stubLookups = () => {
        cy.intercept("GET", "/api/v1/record_matchers*", {
            body: [
                {
                    record_matcher_id: 1,
                    code: "ISBN",
                    description: "ISBN match",
                    record_type: "biblio",
                    threshold: 100,
                },
            ],
        });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            body: [{ marc_modification_template_id: 7, name: "Strip 9xx" }],
        });
    };

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        stubLookups();
    });

    describe("delete", () => {
        beforeEach(() => {
            cy.intercept(
                "GET",
                "/api/v1/import_batch_profiles*",
                listOf([profile({ name: "To delete" })])
            );
            cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
            cy.get("#import_batch_profiles_list").contains("Delete").click();
            cy.get("#confirmation").contains(
                "Staged batches that used it are not affected"
            );
            cy.get("#confirmation").contains("To delete");
        });

        it("deletes after confirmation", () => {
            cy.intercept("DELETE", "/api/v1/import_batch_profiles/1", {
                statusCode: 204,
                body: null,
            }).as("delete");
            cy.get("#confirmation").contains("Yes, delete").click();
            cy.wait("@delete");
            cy.get("main div[class='alert alert-info']").contains(
                "Import profile To delete deleted"
            );
        });

        it("sends nothing when cancelled", () => {
            cy.intercept(
                "DELETE",
                "/api/v1/import_batch_profiles/*",
                cy.spy().as("delete")
            );
            cy.get("#confirmation").contains("No, do not delete").click();
            cy.get("#confirmation").should("not.exist");
            cy.get("@delete").should("not.have.been.called");
            cy.get("#import_batch_profiles_list").contains("To delete");
        });
    });

    it("links to the page from the Cataloguing home", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", listOf([]));
        cy.visit("/cgi-bin/koha/cataloguing/cataloging-home.pl");
        cy.contains("a", "Import profiles")
            .should(
                "have.attr",
                "href",
                "/cgi-bin/koha/cataloguing/import_profiles"
            )
            .click();
        cy.location("pathname").should(
            "eq",
            "/cgi-bin/koha/cataloguing/import_profiles"
        );
        cy.get("#import_batch_profiles_list").should("exist");
    });

    it("shows a message and returns to the list after create", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", listOf([]));
        cy.intercept("POST", "/api/v1/import_batch_profiles", {
            statusCode: 201,
            body: profile({ profile_id: 9, name: "Brand new" }),
        }).as("create");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        cy.get("#name").type("Brand new");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@create");
        cy.get("main div[class='alert alert-info']").contains(
            "Import profile created!"
        );
        cy.location("pathname").should(
            "eq",
            "/cgi-bin/koha/cataloguing/import_profiles"
        );
    });

    it("shows a message and returns to the list after edit", () => {
        const row = profile({ profile_id: 3, name: "Edit me" });
        cy.intercept("GET", "/api/v1/import_batch_profiles/3", row);
        cy.intercept("GET", "/api/v1/import_batch_profiles?*", listOf([row]));
        cy.intercept("PUT", "/api/v1/import_batch_profiles/3", {
            statusCode: 200,
            body: row,
        }).as("update");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/edit/3");
        cy.get("#name").should("have.value", "Edit me");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@update");
        cy.get("main div[class='alert alert-info']").contains(
            "Import profile updated!"
        );
        cy.location("pathname").should(
            "eq",
            "/cgi-bin/koha/cataloguing/import_profiles"
        );
    });

    it("stays on the form when the save fails", () => {
        const row = profile({ profile_id: 3, name: "Edit me" });
        cy.intercept("GET", "/api/v1/import_batch_profiles/3", row);
        cy.intercept("PUT", "/api/v1/import_batch_profiles/3", {
            statusCode: 500,
            body: { error: "boom" },
        }).as("update");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/edit/3");
        cy.get("#name").should("have.value", "Edit me");
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@update");
        cy.location("pathname").should(
            "eq",
            "/cgi-bin/koha/cataloguing/import_profiles/edit/3"
        );
        cy.get("#import_batch_profiles_add").should("be.visible");
        cy.get("#name").should("have.value", "Edit me");
        cy.contains("Import profile updated!").should("not.exist");
    });

    it("sends null when the matching rule and template are cleared", () => {
        const row = profile({ profile_id: 3, matcher_id: 1, template_id: 7 });
        cy.intercept("GET", "/api/v1/import_batch_profiles/3", row);
        cy.intercept("GET", "/api/v1/import_batch_profiles?*", listOf([row]));
        cy.intercept("PUT", "/api/v1/import_batch_profiles/3", {
            statusCode: 200,
            body: row,
        }).as("update");
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/edit/3");
        cy.get("#matcher_id").contains("ISBN (ISBN match)");
        cy.get("#template_id").contains("Strip 9xx");
        cy.get("#matcher_id .vs__clear").click();
        cy.get("#template_id .vs__clear").click();
        cy.get("#import_batch_profiles_add form").submit();
        cy.wait("@update").then(({ request }) => {
            expect(request.body).to.have.property("matcher_id", null);
            expect(request.body).to.have.property("template_id", null);
        });
    });

    it("never shows Unknown while the lookups are held back", () => {
        // Hold both lookup replies until the test releases them.
        let release: () => void = () => {};
        const gate = new Promise<void>(resolve => (release = resolve));
        cy.intercept("GET", "/api/v1/record_matchers*", req =>
            gate.then(() =>
                req.reply({
                    body: [
                        {
                            record_matcher_id: 1,
                            code: "ISBN",
                            description: "ISBN match",
                            record_type: "biblio",
                            threshold: 100,
                        },
                    ],
                })
            )
        ).as("matchers");
        cy.intercept("GET", "/api/v1/marc_modification_templates*", req =>
            gate.then(() =>
                req.reply({
                    body: [
                        {
                            marc_modification_template_id: 7,
                            name: "Strip 9xx",
                        },
                    ],
                })
            )
        ).as("templates");
        cy.intercept(
            "GET",
            "/api/v1/import_batch_profiles*",
            listOf([profile({ matcher_id: 1, template_id: 7 })])
        );
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");

        // Positive anchor: the page is mounted and still pending. Row
        // rendering is not expected yet, but if it happens it must not
        // claim Unknown for ids that exist.
        cy.wait(500);
        cy.get("main").contains("Loading", { timeout: 3000 });
        cy.get("main")
            .invoke("text")
            .should("not.match", /Unknown|Unavailable/);
        cy.get("main")
            .invoke("text")
            .should("not.match", /Unknown|Unavailable/);

        cy.then(() => release());
        cy.wait(["@matchers", "@templates"]);
        cy.get("#import_batch_profiles_list").contains("ISBN");
        cy.get("#import_batch_profiles_list").contains("Strip 9xx");
        cy.get("main")
            .invoke("text")
            .should("not.match", /Unknown|Unavailable/);
    });
});

describe("Import profiles option labels", () => {
    const row = (overrides = {}) => ({
        profile_id: 1,
        name: "Labels",
        matcher_id: null,
        template_id: null,
        record_type: "auth",
        format: "MARCXML",
        encoding: "MARC-8",
        overlay_action: "ignore",
        nomatch_action: "ignore",
        item_action: "add_only_for_matches",
        parse_items: true,
        comments: null,
        ...overrides,
    });

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept("GET", "/api/v1/record_matchers*", { body: [] });
        cy.intercept("GET", "/api/v1/marc_modification_templates*", {
            body: [],
        });
    });

    // Scope to the select that was opened: another dropdown's menu may still
    // be in the page.
    const optionsOf = (id: string, expected: Array<string>) => {
        cy.get("#" + id).click();
        cy.get("#" + id)
            .closest(".v-select")
            .find(".vs__dropdown-option")
            .then($options => {
                expect([...$options].map(o => o.textContent.trim())).to.deep.eq(
                    expected
                );
            });
        cy.get("#" + id).type("{esc}");
    };

    it("offers short labels for the action options", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        optionsOf("overlay_action", [
            "Replace existing record",
            "Add as new record",
            "Ignore incoming record",
        ]);
        optionsOf("nomatch_action", [
            "Add as new record",
            "Ignore incoming record",
        ]);
        optionsOf("item_action", [
            "Always add items",
            "Add for matched records",
            "Add for new records",
            "Replace existing items",
            "Ignore items",
        ]);
    });

    it("explains the action fields with a tooltip", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles/add");
        const tip = (id: string, text: string) =>
            cy
                .get("#" + id)
                .closest("li")
                .find("a.tooltip_helper")
                .should($a => {
                    const title =
                        $a.attr("title") || $a.attr("data-bs-original-title");
                    expect(title).to.contain(text);
                });
        tip("overlay_action", "matches a record already in the catalogue");
        tip("nomatch_action", "matches nothing already in the catalogue");
        tip("item_action", "embedded in incoming records");
    });

    it("shows labels, not stored codes, in the list", () => {
        cy.intercept("GET", "/api/v1/import_batch_profiles*", {
            statusCode: 200,
            body: [
                row(),
                row({
                    profile_id: 2,
                    name: "Plugin",
                    format: "Koha::Plugin::Com::Example::Format",
                }),
            ],
            headers: { "X-Base-Total-Count": "2", "X-Total-Count": "2" },
        });
        cy.visit("/cgi-bin/koha/cataloguing/import_profiles");
        cy.contains("#import_batch_profiles_list tbody tr", "Labels").within(
            () => {
                cy.contains("Authority");
                cy.contains("MARCXML");
                cy.contains("MARC 8");
                cy.contains("Ignore incoming record");
                cy.contains("Add for matched records");
            }
        );
        // The stored codes must not show.
        cy.get("#import_batch_profiles_list tbody").should(
            "not.contain",
            "add_only_for_matches"
        );
        cy.get("#import_batch_profiles_list tbody").should(
            "not.contain",
            "auth "
        );
        // A format we have no label for (a plugin) is shown as stored.
        cy.contains("#import_batch_profiles_list tbody tr", "Plugin").contains(
            "Koha::Plugin::Com::Example::Format"
        );
    });
});
