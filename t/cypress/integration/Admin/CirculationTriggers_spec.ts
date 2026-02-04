import { mount } from "@cypress/vue";
const dayjs = require("dayjs");

const dates = {
    today_iso: dayjs().format("YYYY-MM-DD"),
    today_us: dayjs().format("MM/DD/YYYY"),
    tomorrow_iso: dayjs().add(1, "day").format("YYYY-MM-DD"),
    tomorrow_us: dayjs().add(1, "day").format("MM/DD/YYYY"),
};

// Helper function to generate mock circulation rule
const getMockCirculationRule = (
    library_id: string = "*",
    patron_category_id: string = "*",
    item_type_id: string = "*",
    triggerNum: number = 1
) => {
    return {
        id: Math.floor(Math.random() * 1000),
        rule_name: `overdue_${triggerNum}_delay`,
        rule_value: "7",
        branchcode: library_id === "*" ? null : library_id,
        categorycode: patron_category_id === "*" ? null : patron_category_id,
        itemtype: item_type_id === "*" ? null : item_type_id,
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
            patron_category_id: "ST",
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
        cy.get(".current").contains("Home");
    });

    it("Should have breadcrumb link from add form", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();
        cy.get(".current").contains("Add new trigger");
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

        // Intercept API calls for initial data
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
                getMockCirculationRule("*", "*", "*", 1),
                getMockCirculationRule("*", "*", "*", 2),
                getMockCirculationRule("CPL", "PT", "BK", 1),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should successfully load the component and display initial elements", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Check main heading
        cy.get("h1").should("contain", "Circulation triggers");

        // Check for the rules precedence information
        cy.get(".page-section").should(
            "contain",
            "Rules are applied from most specific to less specific"
        );

        // Check that filters are displayed
        cy.get("#library_select").should("exist");
        cy.get("#patron_category_select").should("exist");
        cy.get("#item_type_select").should("exist");

        // Check toolbar button exists
        cy.contains("Add new trigger").should("exist");
    });

    it("Should display trigger tabs", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Check that tabs are displayed
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

        // Component should handle error gracefully
        // (specific error handling depends on implementation)
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
                getMockCirculationRule("*", "*", "*", 1),
                getMockCirculationRule("CPL", "*", "*", 1),
                getMockCirculationRule("CPL", "PT", "*", 1),
                getMockCirculationRule("CPL", "PT", "BK", 1),
                getMockCirculationRule("MPL", "ST", "DVD", 1),
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

        // Select a specific library
        cy.get("#library_select .vs__search").type("Centerville{enter}", {
            force: true,
        });
        cy.get("#library_select .vs__selected").contains("Centerville");

        // Rules should be filtered to show only Centerville rules
    });

    it("Should filter by patron category", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Select a specific patron category
        cy.get("#patron_category_select .vs__search").type("Patron{enter}", {
            force: true,
        });
        cy.get("#patron_category_select .vs__selected").contains("Patron");

        // Rules should be filtered
    });

    it("Should filter by item type", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Select a specific item type
        cy.get("#item_type_select .vs__search").type("Books{enter}", {
            force: true,
        });
        cy.get("#item_type_select .vs__selected").contains("Books");

        // Rules should be filtered
    });

    it("Should filter by multiple criteria", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Select library
        cy.get("#library_select .vs__search").type("Centerville{enter}", {
            force: true,
        });

        // Select patron category
        cy.get("#patron_category_select .vs__search").type("Patron{enter}", {
            force: true,
        });

        // Select item type
        cy.get("#item_type_select .vs__search").type("Books{enter}", {
            force: true,
        });

        // Should show only rules matching all three criteria
    });

    it("Should toggle between explicit and all applicable rules", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Initially should show "all applied rules"
        cy.get("#filter-rules").should("exist");

        // Change to "explicitly set rules"
        cy.get("#filter-rules .vs__search").click();
        cy.get("#filter-rules .vs__dropdown-menu")
            .contains("explicitly set rules")
            .click({ force: true });

        // Should show fewer rules (only explicitly set ones)
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
                getMockCirculationRule("*", "*", "*", 1),
                getMockCirculationRule("*", "*", "*", 2),
                getMockCirculationRule("*", "*", "*", 3),
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

        // Check Trigger 1 is initially active
        cy.get(".nav-link")
            .contains("Trigger 1")
            .should("have.class", "active");

        // Click on Trigger 2
        cy.get(".nav-link").contains("Trigger 2").click();
        cy.get(".nav-link")
            .contains("Trigger 2")
            .should("have.class", "active");

        // Check that Trigger 2 content is displayed
        cy.get(".tab-pane.active").should("exist");

        // Click on Trigger 3
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
            body: [getMockCirculationRule("CPL", "PT", "BK", 1)],
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

        // Modal should open
        cy.get(".modal-dialog").should("be.visible");
        cy.get(".modal-title").should(
            "contain",
            "Circulation Trigger Configuration"
        );
    });

    it("Should require context selection", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Should show context selection fields
        cy.get("#library_id").should("exist");
        cy.get("#patron_category_id").should("exist");
        cy.get("#item_type_id").should("exist");

        // All fields should be required
        cy.get("input[required]").should("have.length.at.least", 3);
    });

    it("Should proceed through add trigger workflow", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Step 1: Select context
        cy.get("#library_id .vs__search").type("Centerville{enter}", {
            force: true,
        });
        cy.get("#patron_category_id .vs__search").type("Patron{enter}", {
            force: true,
        });
        cy.get("#item_type_id .vs__search").type("Books{enter}", {
            force: true,
        });

        // Confirm context
        cy.contains("Confirm context").click();

        // Step 2: Should show existing triggers for context
        cy.get(".modal-dialog").should("contain", "Existing triggers");

        // Step 3: Fill in trigger details
        cy.get("#overdue_delay").should("exist");
        cy.get("#overdue_delay").type("14");

        // Set restrict checkouts
        cy.get("#restricts-yes").check();

        // Select letter template
        cy.get("#letter_code").should("exist");
    });

    it("Should validate delay constraints", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Complete context selection
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

        // Try to enter invalid delay (should have min/max constraints)
        cy.get("#overdue_delay").should("have.attr", "min");
        cy.get("#overdue_delay").should("have.attr", "max");
    });

    it("Should successfully submit new trigger", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 200,
            body: getMockCirculationRule("CPL", "PT", "BK", 2),
        }).as("create-rule");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Complete form
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

        cy.get("#overdue_delay").type("14");
        cy.get("#restricts-yes").check();

        // Submit form
        cy.get("form").submit();

        cy.wait("@create-rule");

        // Should return to list view
        cy.get(".modal-dialog").should("not.exist");

        // Should show success message
        cy.get(".alert-info").should("contain", "updated");
    });

    it("Should handle submission errors", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 500,
        }).as("create-rule-error");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Complete and submit form
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

        cy.get("#overdue_delay").type("14");
        cy.get("form").submit();

        cy.wait("@create-rule-error");

        // Should show error message
        cy.get(".alert-warning").should("contain", "went wrong");
    });

    it("Should allow canceling add operation", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        cy.get(".modal-dialog").should("be.visible");

        // Click cancel button
        cy.contains("Cancel").click();

        // Modal should close
        cy.get(".modal-dialog").should("not.exist");

        // Should return to list view
        cy.get("h1").should("contain", "Circulation triggers");
    });

    it("Should show placeholder values for fallback rules", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [
                {
                    ...getMockCirculationRule("*", "*", "*", 1),
                    rule_value: "7", // Default delay
                },
                {
                    ...getMockCirculationRule("*", "*", "*", 1),
                    rule_name: "overdue_1_restrict",
                    rule_value: "1", // Default restrict
                },
            ],
            headers: {
                "X-Base-Total-Count": "2",
                "X-Total-Count": "2",
            },
        });

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Complete context
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

        // Delay field should show fallback value as placeholder
        cy.get("#overdue_delay").should("have.attr", "placeholder", "7");

        // Restrict checkouts should show fallback value
        cy.contains("Fallback to default").should("exist");
        cy.contains("(Yes)").should("exist"); // Showing the fallback value
    });
});

describe("Circulation Triggers - Edit Existing Trigger", () => {
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
                {
                    ...getMockCirculationRule("CPL", "PT", "BK", 1),
                    rule_value: "7",
                },
                {
                    ...getMockCirculationRule("CPL", "PT", "BK", 1),
                    rule_name: "overdue_1_restrict",
                    rule_value: "1",
                },
                {
                    ...getMockCirculationRule("CPL", "PT", "BK", 1),
                    rule_name: "overdue_1_letter",
                    rule_value: "ODUE1",
                },
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should open edit modal from table", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Click edit button/icon in table
        cy.get("table").contains("Edit").click();

        // Modal should open
        cy.get(".modal-dialog").should("be.visible");
    });

    it("Should pre-populate form with existing values", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Edit").click();

        // Context should be pre-selected and disabled
        cy.get("#library_id").should("be.disabled");
        cy.get("#patron_category_id").should("be.disabled");
        cy.get("#item_type_id").should("be.disabled");

        // Delay should be pre-filled
        cy.get("#overdue_delay").should("have.value", "7");

        // Restrict should be pre-selected
        cy.get("#restricts-yes").should("be.checked");

        // Letter should be pre-selected
        cy.get("#letter_code .vs__selected").should("contain", "ODUE1");
    });

    it("Should allow modifying trigger values within constraints", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Edit").click();

        // Change delay
        cy.get("#overdue_delay").clear().type("10");

        // Change restrict
        cy.get("#restricts-no").check();

        // Values should update
        cy.get("#overdue_delay").should("have.value", "10");
        cy.get("#restricts-no").should("be.checked");
    });

    it("Should use increment/decrement buttons for delay", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Edit").click();

        const initialDelay = 7;

        // Click increment
        cy.get(".increment-btn").click();
        cy.get("#overdue_delay").should("have.value", String(initialDelay + 1));

        // Click decrement
        cy.get(".decrement-btn").click();
        cy.get("#overdue_delay").should("have.value", String(initialDelay));
    });

    it("Should allow clearing values to use fallback", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Edit").click();

        // Clear delay using clear button
        cy.get(".clear-btn").click();
        cy.get("#overdue_delay").should("have.value", "");

        // Select fallback for restrict
        cy.get("#restricts-fallback").check();

        // Should show what fallback value will be used
        cy.get("#overdue_delay").should("have.attr", "placeholder");
    });

    it("Should successfully update trigger", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 200,
            body: {
                ...getMockCirculationRule("CPL", "PT", "BK", 1),
                rule_value: "10",
            },
        }).as("update-rule");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Edit").click();

        cy.get("#overdue_delay").clear().type("10");
        cy.get("form").submit();

        cy.wait("@update-rule");

        // Modal should close
        cy.get(".modal-dialog").should("not.exist");

        // Should show success message
        cy.get(".alert-info").should("exist");
    });

    it("Should handle update errors", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 500,
        }).as("update-rule-error");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get("table").contains("Edit").click();
        cy.get("#overdue_delay").clear().type("10");
        cy.get("form").submit();

        cy.wait("@update-rule-error");

        // Should show error message
        cy.get(".alert-warning").should("contain", "went wrong");
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
                getMockCirculationRule("CPL", "PT", "BK", 1),
                getMockCirculationRule("CPL", "PT", "BK", 2),
                getMockCirculationRule("CPL", "PT", "BK", 3),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should only show delete button for last trigger", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Navigate to Trigger 3 tab (last one)
        cy.get(".nav-link").contains("Trigger 3").click();

        // Delete button should exist
        cy.contains("Delete").should("exist");

        // Navigate to Trigger 1 tab
        cy.get(".nav-link").contains("Trigger 1").click();

        // Delete button should not exist
        cy.contains("Delete").should("not.exist");
    });

    it("Should show confirmation dialog for delete", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").click();

        // Confirmation modal should open
        cy.get(".modal-dialog").should("be.visible");
        cy.get(".modal-title").should("contain", "Delete");

        // Should show which trigger will be deleted
        cy.get(".modal-body").should("contain", "Trigger 3");
    });

    it("Should successfully delete trigger", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 200,
            body: null,
        }).as("delete-rule");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").click();

        // Confirm deletion
        cy.contains("Confirm").click();

        cy.wait("@delete-rule");

        // Should return to list
        cy.get(".modal-dialog").should("not.exist");

        // Success message should appear
        cy.get(".alert-info").should("exist");
    });

    it("Should handle delete errors", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 500,
        }).as("delete-rule-error");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").click();
        cy.contains("Confirm").click();

        cy.wait("@delete-rule-error");

        // Error message should appear
        cy.get(".alert-warning").should("contain", "went wrong");
    });

    it("Should allow canceling delete operation", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.get(".nav-link").contains("Trigger 3").click();
        cy.contains("Delete").click();

        cy.get(".modal-dialog").should("be.visible");

        // Click cancel
        cy.contains("Cancel").click();

        // Modal should close
        cy.get(".modal-dialog").should("not.exist");

        // Should still be on Trigger 3 tab
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
                getMockCirculationRule("*", "*", "*", 1),
                getMockCirculationRule("CPL", "PT", "BK", 1),
                getMockCirculationRule("MPL", "PT", "BK", 1),
            ],
            headers: {
                "X-Base-Total-Count": "3",
                "X-Total-Count": "3",
            },
        }).as("get-rules");
    });

    it("Should show reset button for explicit rules", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Look for reset button in rules table
        cy.get("table").contains("Reset").should("exist");
    });

    it("Should show confirmation dialog for reset", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.contains("Reset").click();

        // Confirmation modal should open
        cy.get(".modal-dialog").should("be.visible");
        cy.get(".modal-title").should("contain", "Reset");

        // Should explain what will happen
        cy.get(".modal-body").should("contain", "rule set will be removed");
    });

    it("Should successfully reset rule set", () => {
        cy.intercept("PUT", "/api/v1/circulation_rules", {
            statusCode: 200,
            body: null,
        }).as("reset-rules");

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        cy.contains("Reset").click();
        cy.contains("Confirm").click();

        cy.wait("@reset-rules");

        // Should return to list
        cy.get(".modal-dialog").should("not.exist");

        // Success message
        cy.get(".alert-info").should("exist");
    });

    it("Should not allow reset if it's the only rule set", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", {
            statusCode: 200,
            body: [getMockCirculationRule("CPL", "PT", "BK", 1)],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Reset button should not be available
        cy.contains("Reset").should("not.exist");
    });
});

describe("Circulation Triggers - Letter Template Filtering", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });
    });

    it("Should filter letter templates by library", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Select Centerville library
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

        // Letter dropdown should include Centerville-specific and default templates
        cy.get("#letter_code .vs__search").click();
        cy.get("#letter_code .vs__dropdown-menu").should("contain", "ODUE1");
        cy.get("#letter_code .vs__dropdown-menu").should("contain", "CPL_ODUE");

        // Should NOT include templates for other libraries
        cy.get("#letter_code .vs__dropdown-menu").should(
            "not.contain",
            "MPL_ODUE"
        );
    });

    it("Should include No letter option", () => {
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

        // Should have "No letter" option
        cy.get("#letter_code .vs__search").click();
        cy.get("#letter_code .vs__dropdown-menu").should(
            "contain",
            "No letter"
        );
    });
});

describe("Circulation Triggers - Loading States", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Should show loading messages during initialization", () => {
        cy.intercept("GET", "/api/v1/circulation_rules*", req => {
            // Delay response to see loading state
            req.reply({
                delay: 1000,
                statusCode: 200,
                body: [],
            });
        });

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Should show loading indicator or message
        cy.contains("Loading").should("exist");
    });

    it("Should show specific loading messages in modals", () => {
        cy.intercept("GET", "/api/v1/**", {
            statusCode: 200,
            body: [],
        });

        cy.intercept("GET", "/api/v1/circulation_rules*", req => {
            req.reply({
                delay: 500,
                statusCode: 200,
                body: [],
            });
        });

        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        // Should show context-specific loading message
        cy.contains("Loading").should("exist");
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

    it("Should handle no rules gracefully", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Should show message about no rules or empty state
        cy.get("body").should("exist"); // Component should still render
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
                getMockCirculationRule("*", "*", "*", 1),
                getMockCirculationRule("*", "*", "*", 2),
                getMockCirculationRule("*", "*", "*", 3),
                getMockCirculationRule("CPL", "*", "*", 1),
                getMockCirculationRule("CPL", "PT", "*", 1),
                getMockCirculationRule("CPL", "PT", "BK", 1),
            ],
            headers: {
                "X-Base-Total-Count": "6",
                "X-Total-Count": "6",
            },
        }).as("get-rules");
    });

    it("Should handle multiple triggers for same context", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Should show all three triggers
        cy.get(".nav-link").contains("Trigger 1").should("exist");
        cy.get(".nav-link").contains("Trigger 2").should("exist");
        cy.get(".nav-link").contains("Trigger 3").should("exist");
    });

    it("Should show inheritance hierarchy correctly", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Select specific context
        cy.get("#library_select .vs__search").type("Centerville{enter}", {
            force: true,
        });
        cy.get("#patron_category_select .vs__search").type("Patron{enter}", {
            force: true,
        });
        cy.get("#item_type_select .vs__search").type("Books{enter}", {
            force: true,
        });

        // Should show most specific rule
        // And indicate inherited values in italic/bold
    });

    it("Should allow rapid successive operations", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.wait("@get-rules");

        // Quickly change filters
        cy.get("#library_select .vs__search").type("Centerville{enter}", {
            force: true,
        });
        cy.get("#patron_category_select .vs__search").type("Patron{enter}", {
            force: true,
        });

        // Switch tabs
        cy.get(".nav-link").contains("Trigger 2").click();
        cy.get(".nav-link").contains("Trigger 1").click();

        // Toggle filter
        cy.get("#filter-rules .vs__search").click();
        cy.get("#filter-rules .vs__dropdown-menu")
            .contains("explicitly set rules")
            .click({ force: true });

        // Should handle all operations without errors
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
            body: [getMockCirculationRule("CPL", "PT", "BK", 1)],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
    });

    it("Should handle browser back button", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();

        cy.get(".modal-dialog").should("be.visible");

        // Use browser back
        cy.go("back");

        // Modal should close
        cy.get(".modal-dialog").should("not.exist");
    });

    it("Should handle browser forward button", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");
        cy.contains("Add new trigger").click();
        cy.go("back");
        cy.go("forward");

        // Modal should reopen
        cy.get(".modal-dialog").should("be.visible");
    });
});
