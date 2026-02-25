import { mount } from "@cypress/vue";
const dayjs = require("dayjs");

const dates = {
    today_iso: dayjs().format("YYYY-MM-DD"),
    today_us: dayjs().format("MM/DD/YYYY"),
    tomorrow_iso: dayjs().add(1, "day").format("YYYY-MM-DD"),
    tomorrow_us: dayjs().add(1, "day").format("MM/DD/YYYY"),
};

// Generates a rule set in the format the API actually returns:
// { context: { library_id, patron_category_id, item_type_id }, overdue_N_delay, ... }
const getMockRuleSet = (
    library_id: string = "*",
    patron_category_id: string = "*",
    item_type_id: string = "*",
    triggerNum: number = 1,
    delay: string = "7"
) => {
    return {
        context: { library_id, patron_category_id, item_type_id },
        [`overdue_${triggerNum}_delay`]: delay,
        [`overdue_${triggerNum}_notice`]: null,
        [`overdue_${triggerNum}_restrict`]: null,
        [`overdue_${triggerNum}_mtt`]: null,
    };
};

const getMockLibraries = () => {
    return [
        {
            library_id: "CPL",
            name: "Centerville",
            address1: "123 Main St",
            city: "Centerville",
        },
        {
            library_id: "MPL",
            name: "Midway",
            address1: "456 Broad St",
            city: "Midway",
        },
        {
            library_id: "FPL",
            name: "Fairview",
            address1: "789 Park Ave",
            city: "Fairview",
        },
    ];
};

const getMockPatronCategories = () => {
    return [
        {
            patron_category_id: "PT",
            name: "Patron",
            description: "Regular patron",
        },
        {
            patron_category_id: "ST",
            name: "Student",
            description: "Student patron",
        },
        {
            patron_category_id: "SF",
            name: "Staff",
            description: "Staff member",
        },
    ];
};

const getMockItemTypes = () => {
    return [
        {
            item_type_id: "BK",
            description: "Books",
        },
        {
            item_type_id: "DVD",
            description: "DVDs",
        },
        {
            item_type_id: "MAG",
            description: "Magazines",
        },
    ];
};

const getMockLetters = () => {
    return [
        {
            code: "ODUE1",
            name: "First Overdue Notice",
            branchcode: null,
            module: "circulation",
        },
        {
            code: "ODUE2",
            name: "Second Overdue Notice",
            branchcode: null,
            module: "circulation",
        },
        {
            code: "ODUE3",
            name: "Third Overdue Notice",
            branchcode: null,
            module: "circulation",
        },
        {
            code: "CPL_ODUE",
            name: "Centerville Overdue",
            branchcode: "CPL",
            module: "circulation",
        },
    ];
};

describe("Circulation Triggers - Breadcrumbs", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Should display correct breadcrumbs", () => {
        cy.visit("/cgi-bin/koha/admin/admin-home.pl");
        cy.contains("Circulation triggers").click();
        cy.get("#breadcrumbs").contains("Administration");
        cy.get("#breadcrumbs > ol > li:nth-child(3)").contains(
            "Circulation triggers"
        );
    });

    it("Should have breadcrumb link from add form", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();
        cy.get("#breadcrumbs")
            .contains("Circulation triggers")
            .should("have.attr", "href")
            .and("equal", "/cgi-bin/koha/admin/circulation_triggers");
    });
});

describe("Circulation Triggers - Initial Load", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/libraries*", {
            statusCode: 200,
            body: getMockLibraries(),
        }).as("get-libraries");

        cy.intercept("GET", "/api/v1/patron_categories*", {
            statusCode: 200,
            body: getMockPatronCategories(),
        }).as("get-patron-categories");

        cy.intercept("GET", "/api/v1/item_types*", {
            statusCode: 200,
            body: getMockItemTypes(),
        }).as("get-item-types");

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                getMockRuleSet("*", "*", "*", 1),
                getMockRuleSet("*", "*", "*", 2),
                getMockRuleSet("CPL", "PT", "BK", 1),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should successfully load the component and display initial elements", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        cy.get("h1").should("contain", "Circulation triggers");
        cy.get(".page-section").should(
            "contain",
            "Rules are applied from most specific to less specific"
        );
        cy.get("#library_select").should("exist");
        cy.get("#patron_category_select").should("exist");
        cy.get("#item_type_select").should("exist");
        cy.contains("Add new trigger").should("exist");
    });

    it("Should display trigger tabs when rules exist", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("#circ_triggers_tabs").should("exist");
        cy.get(".nav-link").contains("Trigger 1").should("exist");
        cy.get(".nav-link").contains("Trigger 2").should("exist");
    });

    it("Should handle API errors gracefully", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 500,
        }).as("get-rules-error");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules-error");

        // Component should still render without crashing
        cy.get("h1").should("contain", "Circulation triggers");
    });
});

describe("Circulation Triggers - No default rules warning", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/libraries*", {
            statusCode: 200,
            body: getMockLibraries(),
        }).as("get-libraries");

        cy.intercept("GET", "/api/v1/patron_categories*", {
            statusCode: 200,
            body: getMockPatronCategories(),
        }).as("get-patron-categories");

        cy.intercept("GET", "/api/v1/item_types*", {
            statusCode: 200,
            body: getMockItemTypes(),
        }).as("get-item-types");
    });

    it("Should show warning when no default rules exist but library-specific rules do", () => {
        // First intercept: default-library fetch returns empty
        // Second intercept: all-rules fetch (for getLibrariesWithRules) returns CPL rules
        cy.intercept("GET", "/api/v1/circulation_rules*", req => {
            const url = new URL(req.url);
            if (url.searchParams.get("library_id") === "*") {
                req.reply({
                    statusCode: 200,
                    body: [],
                    headers: {
                        "X-Base-Total-Count": "0",
                        "X-Total-Count": "0",
                    },
                });
            } else {
                req.reply({
                    statusCode: 200,
                    body: [getMockRuleSet("CPL", "*", "*", 1)],
                    headers: {
                        "X-Base-Total-Count": "1",
                        "X-Total-Count": "1",
                    },
                });
            }
        }).as("get-rules");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".alert-warning").should(
            "contain",
            "No default overdue triggers are defined"
        );
        cy.get(".alert-warning").should(
            "contain",
            "The following libraries have library-specific triggers defined"
        );
        cy.get(".alert-warning").contains("Centerville").should("exist");
    });

    it("Should show get-started message when no rules exist anywhere", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        }).as("get-rules");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".alert-warning").should(
            "contain",
            "No default overdue triggers are defined"
        );
        cy.get(".alert-warning").should(
            "contain",
            "Select add new trigger above to get started"
        );
    });

    it("Should not show warning when default rules exist", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [getMockRuleSet("*", "*", "*", 1)],
            headers: { "X-Base-Total-Count": "1", "X-Total-Count": "1" },
        }).as("get-rules");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".alert-warning").should("not.exist");
    });

    it("Should switch to library view when clicking a library link in the warning", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", req => {
            const url = new URL(req.url);
            if (url.searchParams.get("library_id") === "*") {
                req.reply({
                    statusCode: 200,
                    body: [],
                    headers: {
                        "X-Base-Total-Count": "0",
                        "X-Total-Count": "0",
                    },
                });
            } else {
                req.reply({
                    statusCode: 200,
                    body: [getMockRuleSet("CPL", "*", "*", 1)],
                    headers: {
                        "X-Base-Total-Count": "1",
                        "X-Total-Count": "1",
                    },
                });
            }
        }).as("get-rules");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".alert-warning").contains("Centerville").click();

        // The library filter should now show Centerville and the warning should be gone
        cy.get("#library_select .vs__selected").should(
            "contain",
            "Centerville"
        );
        cy.get(".alert-warning").should("not.exist");
    });
});

describe("Circulation Triggers - Filtering", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/libraries*", {
            statusCode: 200,
            body: getMockLibraries(),
        });

        cy.intercept("GET", "/api/v1/patron_categories*", {
            statusCode: 200,
            body: getMockPatronCategories(),
        });

        cy.intercept("GET", "/api/v1/item_types*", {
            statusCode: 200,
            body: getMockItemTypes(),
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                getMockRuleSet("*", "*", "*", 1),
                getMockRuleSet("CPL", "*", "*", 1),
                getMockRuleSet("CPL", "PT", "*", 1),
                getMockRuleSet("CPL", "PT", "BK", 1),
                getMockRuleSet("MPL", "ST", "DVD", 1),
            ],
            headers: {
                "X-Base-Total-Count": "5",
                "X-Total-Count": "5",
            },
        }).as("get-rules");
    });

    it("Should filter by library", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("#library_select .vs__search").type("Centerville{enter}", {
            force: true,
        });
        cy.get("#library_select .vs__selected").should(
            "contain",
            "Centerville"
        );
    });

    it("Should filter by patron category", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("#patron_category_select .vs__search").type("Patron{enter}", {
            force: true,
        });
        cy.get("#patron_category_select .vs__selected").should(
            "contain",
            "Patron"
        );
    });

    it("Should filter by item type", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("#item_type_select .vs__search").type("Books{enter}", {
            force: true,
        });
        cy.get("#item_type_select .vs__selected").should("contain", "Books");
    });

    it("Should toggle between explicit and all applicable rules", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("#filter-rules").should("exist");

        cy.get("#filter-rules .vs__search").click();
        cy.get("#filter-rules .vs__dropdown-menu")
            .contains("explicitly set rules")
            .click({ force: true });
    });
});

describe("Circulation Triggers - Tab Navigation", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                getMockRuleSet("*", "*", "*", 1),
                getMockRuleSet("*", "*", "*", 2),
                getMockRuleSet("*", "*", "*", 3),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should switch between trigger tabs", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link")
            .contains("Trigger 1")
            .should("have.class", "active");

        cy.get(".nav-link").contains("Trigger 2").click();
        cy.get(".nav-link")
            .contains("Trigger 2")
            .should("have.class", "active");

        cy.get(".tab-pane.active").should("exist");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.get(".nav-link")
            .contains("Trigger 3")
            .should("have.class", "active");
    });
});

describe("Circulation Triggers - Add New Trigger", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/libraries*", {
            statusCode: 200,
            body: getMockLibraries(),
        });

        cy.intercept("GET", "/api/v1/patron_categories*", {
            statusCode: 200,
            body: getMockPatronCategories(),
        });

        cy.intercept("GET", "/api/v1/item_types*", {
            statusCode: 200,
            body: getMockItemTypes(),
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [getMockRuleSet("*", "*", "*", 1, "7")],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-rules");
    });

    it("Should open add trigger modal", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        cy.get(".modal-dialog").should("not.exist");
        cy.contains("Add new trigger").click();

        cy.get(".modal-dialog").should("be.visible");
        cy.get(".modal-title").should(
            "contain",
            "Circulation Trigger Configuration"
        );
    });

    it("Should require context selection fields", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        cy.get("#library_id").should("exist");
        cy.get("#patron_category_id").should("exist");
        cy.get("#item_type_id").should("exist");
    });

    it("Should show trigger number 1 when adding first trigger for a library with no existing rules", () => {
        // Regression test for bug where triggerNumber was NaN when no rules
        // existed for a library (triggerCounts[library_id] was undefined).
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [],
            headers: { "X-Base-Total-Count": "0", "X-Total-Count": "0" },
        });

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        cy.get("#library_id .vs__search").type("Centerville{enter}", {
            force: true,
        });
        cy.get("#patron_category_id .vs__search").type("Patron{enter}", {
            force: true,
        });
        cy.get("#item_type_id .vs__search").type("Books{enter}", {
            force: true,
        });
        cy.contains("Confirm context").click();

        // trigger number should be 1, not NaN
        cy.get("legend").should("contain", "Add new trigger 1");
        cy.get("#overdue_delay").should("exist");
        cy.get("#overdue_delay").should("not.have.attr", "name", /NaN/);
    });

    it("Should allow canceling add operation", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        cy.get(".modal-dialog").should("be.visible");

        cy.contains("Cancel").click();

        cy.get(".modal-dialog").should("not.exist");
        cy.get("h1").should("contain", "Circulation triggers");
    });
});

describe("Circulation Triggers - Delete Trigger", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                getMockRuleSet("*", "*", "*", 1),
                getMockRuleSet("*", "*", "*", 2),
                getMockRuleSet("*", "*", "*", 3),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should only show delete button for last trigger tab", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").should("exist");

        cy.get(".nav-link").contains("Trigger 1").click();
        cy.contains("Delete").should("not.exist");
    });

    it("Should show confirmation dialog for delete", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").click();

        cy.get(".modal-dialog").should("be.visible");
        cy.get(".modal-title").should("contain", "Delete");
        cy.get(".modal-body").should("contain", "3");
    });

    it("Should allow canceling delete operation", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").click();

        cy.get(".modal-dialog").should("be.visible");

        cy.contains("Cancel").click();

        cy.get(".modal-dialog").should("not.exist");
        cy.get(".nav-link")
            .contains("Trigger 3")
            .should("have.class", "active");
    });
});

describe("Circulation Triggers - Reset Rule Set", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                getMockRuleSet("*", "*", "*", 1),
                getMockRuleSet("CPL", "PT", "BK", 1),
                getMockRuleSet("MPL", "PT", "BK", 1),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should show Reset button for explicit rule sets in the table", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Reset").should("exist");
    });

    it("Should show confirmation dialog for reset", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Reset").click();

        cy.get(".modal-dialog").should("be.visible");
        cy.get(".modal-title").should(
            "contain",
            "Confirm circulation rule set reset"
        );
        cy.get(".modal-body").should(
            "contain",
            "Resetting this rule set for the chosen context"
        );
    });

    it("Should allow canceling reset operation", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Reset").click();
        cy.get(".modal-dialog").should("be.visible");

        cy.contains("Cancel").click();
        cy.get(".modal-dialog").should("not.exist");
    });
});

describe("Circulation Triggers - Empty States", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [],
            headers: {
                "X-Base-Total-Count": "0",
                "X-Total-Count": "0",
            },
        });
    });

    it("Should render without crashing when no rules exist", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        cy.get("h1").should("contain", "Circulation triggers");
        cy.get(".alert-warning").should(
            "contain",
            "No default overdue triggers"
        );
    });
});

describe("Circulation Triggers - Complex Scenarios", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/libraries*", {
            statusCode: 200,
            body: getMockLibraries(),
        });

        cy.intercept("GET", "/api/v1/patron_categories*", {
            statusCode: 200,
            body: getMockPatronCategories(),
        });

        cy.intercept("GET", "/api/v1/item_types*", {
            statusCode: 200,
            body: getMockItemTypes(),
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                getMockRuleSet("*", "*", "*", 1),
                getMockRuleSet("*", "*", "*", 2),
                getMockRuleSet("*", "*", "*", 3),
                getMockRuleSet("CPL", "*", "*", 1),
                getMockRuleSet("CPL", "PT", "*", 1),
                getMockRuleSet("CPL", "PT", "BK", 1),
            ],
            headers: {
                "X-Base-Total-Count": "6",
                "X-Total-Count": "6",
            },
        }).as("get-rules");
    });

    it("Should show all three trigger tabs for default library", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 1").should("exist");
        cy.get(".nav-link").contains("Trigger 2").should("exist");
        cy.get(".nav-link").contains("Trigger 3").should("exist");
    });

    it("Should handle rapid tab switching without errors", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 2").click();
        cy.get(".nav-link").contains("Trigger 1").click();
        cy.get(".nav-link").contains("Trigger 3").click();

        cy.get(".tab-pane.active").should("exist");
        cy.get("body").should("exist");
    });
});

describe("Circulation Triggers - Browser Navigation", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [getMockRuleSet("*", "*", "*", 1)],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
    });

    it("Should close modal on browser back button", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        cy.get(".modal-dialog").should("be.visible");

        cy.go("back");

        cy.get(".modal-dialog").should("not.exist");
    });

    it("Should reopen modal on browser forward button", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();
        cy.go("back");
        cy.go("forward");

        cy.get(".modal-dialog").should("be.visible");
    });
});
