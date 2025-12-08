const dayjs = require("dayjs"); /* Cannot use our calendar JS code, it's in an include file (!)
                                   Also note that moment.js is deprecated */

const dates = {
    yesterday_iso: dayjs().subtract(1, "day").format("YYYY-MM-DD"),
    yesterday_us: dayjs().subtract(1, "day").format("MM/DD/YYYY"),
    today_iso: dayjs().format("YYYY-MM-DD"),
    today_us: dayjs().format("MM/DD/YYYY"),
    tomorrow_iso: dayjs().add(1, "day").format("YYYY-MM-DD"),
    tomorrow_us: dayjs().add(1, "day").format("MM/DD/YYYY"),
};

describe("Displays - CRUD operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept(
            "GET",
            "/api/v1/displays/config",
            '{"settings":{"enabled":true,"permissions":{"CAN_user_displays":1,"CAN_user_displays_add_displays":1,"CAN_user_displays_add_displays_to_any_libraries":1,"CAN_user_displays_delete_displays":1,"CAN_user_displays_delete_displays_from_any_libraries":1,"CAN_user_displays_edit_displays":1,"CAN_user_displays_edit_displays_from_any_libraries":1,"CAN_user_displays_manage_display_items":1,"CAN_user_displays_view_displays":1,"CAN_user_displays_view_displays_from_any_libraries":1}}}'
        );
    });

    it("Add display", () => {
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, []);
        cy.visit("/cgi-bin/koha/display/display-home.pl");

        let display = cy.getDisplay();
        let displays = [display];
        let item = cy.getItem();

        cy.contains("New display").click();

        // Main display
        cy.get("#display_name").type(display.display_name);
        cy.get("#display_branch .vs__search").type("centerville" + "{enter}", {
            force: true,
        });

        cy.get("#display_home_branch .vs__search").type(
            "fairfield" + "{enter}",
            {
                force: true,
            }
        );
        cy.get("#display_holding_branch .vs__search").type(
            "fairview" + "{enter}",
            {
                force: true,
            }
        );
        cy.get("#display_location .vs__search").type("on display" + "{enter}", {
            force: true,
        });
        cy.get("#display_code .vs__search").type("reference" + "{enter}", {
            force: true,
        });
        cy.get("#display_itype .vs__search").type("books" + "{enter}", {
            force: true,
        });

        cy.get("#display_days").type(display.display_days);
        cy.get("#start_date+input").click();
        cy.get(".flatpickr-calendar")
            .eq(0)
            .find("span.today")
            .prev("span")
            .click();
        cy.get("#end_date+input").click();
        cy.get(".flatpickr-calendar")
            .eq(1)
            .find("span.today")
            .next("span")
            .click();

        cy.get("#staff_note").type(display.staff_note);
        cy.get("#public_note").type(display.public_note);

        cy.get("#display_return_over .vs__search").type(
            "yes, any library" + "{enter}",
            {
                force: true,
            }
        );
        cy.get("#enabled_yes").click();

        // Display item
        cy.contains("Add new display item").click();
        cy.get("#display_items_barcode_0").type(item.external_id);
        cy.get("#display_items_date_added_0+input").click();
        cy.get(".flatpickr-calendar")
            .eq(2)
            .find("span.today")
            .prev("span")
            .click();
        cy.get("#display_items_date_remove_0+input").click();
        cy.get(".flatpickr-calendar")
            .eq(3)
            .find("span.today")
            .next("span")
            .click();

        // Submit the form, get 500
        cy.intercept("POST", "/api/v1/displays", {
            statusCode: 500,
            error: "Something went wrong",
        });
        cy.get("#displays_add").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "An error occurred while saving the display"
        );

        // Submit the form, success!
        cy.intercept("POST", "/api/v1/displays", {
            statusCode: 201,
            body: display,
        });
        cy.get("#displays_add").contains("Save").click();

        // Intercept list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.get("main div[class='alert alert-info']").contains(
            "Display created"
        );
    });

    it("List displays", () => {
        // GET displays returns 500
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 500,
        });
        cy.visit("/cgi-bin/koha/display/display-home.pl");
        cy.get(".sidebar_menu a").contains("Displays").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // GET displays returns empty list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, []);
        cy.visit("/cgi-bin/koha/display/displays");
        cy.get("#displays_list").contains("There are no displays defined");

        // GET displays returns something
        let display = cy.getDisplay();
        let displays = [display];

        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.visit("/cgi-bin/koha/display/displays");
        cy.get("#displays_list").contains("Showing 1 to 1 of 1 entries");
    });

    it("Show display", () => {
        let display = cy.getDisplay();
        let displays = [display];
        let item = cy.getItem();

        // Click the "name" link from the list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-displays");
        cy.intercept("GET", /\/api\/v1\/displays\/\d+/, display).as(
            "get-display"
        );
        cy.intercept("GET", /\/api\/v1\/items\/\d+/, {
            statusCode: 200,
            body: item,
        }).as("get-item");

        cy.visit("/cgi-bin/koha/display/displays");
        cy.wait("@get-displays");
        let id_cell = cy.get("#displays_list table tbody tr:first td:first");
        id_cell.contains(display.display_id);

        let name_link = cy
            .get("#displays_list table tbody tr:first td")
            .eq(1)
            .find("a");
        name_link.should("have.text", display.display_name);
        name_link.click();
        cy.wait("@get-item");
        cy.get("#displays_show h2").contains("Display #" + display.display_id);
        cy.left_menu_active_item_is("Displays");
    });

    it("Edit display", () => {
        let display = cy.getDisplay();
        let displays = [display];
        let item = cy.getItem();

        // Click the 'Edit' button from the list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-displays");
        cy.intercept("GET", /\/api\/v1\/displays\/\d+/, display).as(
            "get-display"
        );
        cy.intercept("GET", /\/api\/v1\/items\/\d+/, {
            statusCode: 200,
            body: item,
        }).as("get-item");

        cy.visit("/cgi-bin/koha/display/displays");
        cy.wait("@get-displays");
        cy.get("#displays_list table tbody tr:first").contains("Edit").click();
        cy.wait("@get-item");
        cy.get("#displays_add h2").contains("Edit display");
        cy.left_menu_active_item_is("Displays");

        // Form has been correctly filled in
        cy.get("#display_name").should("have.value", display.display_name);
        cy.get("#display_branch .vs__selected").contains("Centerville");
        cy.get("#display_home_branch .vs__selected").contains("Fairfield");
        cy.get("#display_holding_branch .vs__selected").contains("Fairview");
        cy.get("#display_location .vs__selected").contains("On display");
        cy.get("#display_code .vs__selected").contains("Reference");
        cy.get("#display_itype .vs__selected").contains("Mixed Materials");
        cy.get("#display_days").should("have.value", display.display_days);
        cy.get("#start_date").should("have.value", display.start_date);
        cy.get("#end_date").should("have.value", display.end_date);
        cy.get("#public_note").should("have.value", display.public_note);
        cy.get("#staff_note").should("have.value", display.staff_note);

        cy.get("#display_items_barcode_0").should(
            "have.value",
            item.external_id
        );
        cy.get("#display_items_date_added_0").should(
            "have.value",
            dates.yesterday_iso
        );
        cy.get("#display_items_date_remove_0").should(
            "have.value",
            dates.tomorrow_iso
        );

        // Submit the form, get 500
        cy.intercept("PUT", "/api/v1/displays/*", {
            statusCode: 500,
        });
        cy.get("#displays_add").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "An error occurred while saving the display"
        );

        // Submit the form, success!
        cy.intercept("PUT", "/api/v1/displays/*", {
            statusCode: 200,
            body: display,
        });
        cy.get("#displays_add").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Display updated"
        );
    });

    it("Delete display", () => {
        let display = cy.getDisplay();
        let displays = [display];
        let item = cy.getItem();

        // Click the 'Delete' button from the list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", /\/api\/v1\/displays\/\d+/, display);
        cy.visit("/cgi-bin/koha/display/displays");

        cy.get("#displays_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this display"
        );
        cy.contains(display.display_name);

        // Accept the confirmation dialog, get 500
        cy.intercept("DELETE", "/api/v1/displays/*", {
            statusCode: 500,
        });
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );

        // Accept the confirmation dialog, success!
        cy.intercept("DELETE", "/api/v1/displays/*", {
            statusCode: 204,
            body: null,
        });
        cy.get("#displays_list table tbody tr:first")
            .contains("Delete")
            .click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this display"
        );
        cy.contains("Yes, delete").click();
        cy.get("main div[class='alert alert-info']")
            .contains("Display")
            .contains("deleted");

        // Delete from show
        // Click the "name" link from the list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-displays");
        cy.intercept("GET", /\/api\/v1\/displays\/\d+/, display).as(
            "get-display"
        );
        cy.intercept("GET", /\/api\/v1\/items\/\d+/, {
            statusCode: 200,
            body: item,
        }).as("get-item");

        cy.visit("/cgi-bin/koha/display/displays");
        cy.wait("@get-displays");
        let id_cell = cy.get("#displays_list table tbody tr:first td:first");
        id_cell.contains(display.display_id);

        let name_link = cy
            .get("#displays_list table tbody tr:first td")
            .eq(1)
            .find("a");
        name_link.should("have.text", display.display_name);
        name_link.click();
        cy.wait("@get-display");
        cy.get("#displays_show h2").contains("Display #" + display.display_id);

        cy.get("#displays_show #toolbar").contains("Delete").click();
        cy.get(".alert-warning.confirmation h1").contains(
            "remove this display"
        );
        cy.contains("Yes, delete").click();

        //Make sure we return to list after deleting from show
        cy.get("#displays_list table tbody tr:first");
    });

    it("Batch add items", () => {
        let display = cy.getDisplay();
        let displays = [display];
        let batch = {
            job_id: 1,
            message: "Batch add operation queued",
        };
        let batches = [batch];
        let item = cy.getItem();

        // Click the "batch add" link from the list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-displays");
        cy.intercept("GET", /\/api\/v1\/displays\/\d+/, display).as(
            "get-display"
        );
        cy.intercept("GET", /\/api\/v1\/items\/\d+/, {
            statusCode: 200,
            body: item,
        }).as("get-item");

        cy.visit("/cgi-bin/koha/display/display-home.pl");
        cy.contains("Batch add items from list").click();

        cy.get("#barcodes").type("39999000002355\n39999000002331\n\n");
        cy.get("#display_id .vs__search").type(
            display.display_name + "{enter}",
            {
                force: true,
            }
        );
        cy.get("#date_added+input").click();
        cy.get(".flatpickr-calendar")
            .eq(0)
            .find("span.today")
            .prev("span")
            .click();
        cy.get("#date_remove+input").click();
        cy.get(".flatpickr-calendar")
            .eq(1)
            .find("span.today")
            .next("span")
            .click();

        // Submit the form, get 500
        cy.intercept("POST", "/api/v1/display/items/batch", {
            statusCode: 500,
            error: "Something went wrong",
        });
        cy.get("#list").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Internal Server Error"
        );

        // Submit the form, success!
        cy.intercept("POST", "/api/v1/display/items/batch", {
            statusCode: 202,
            body: batch,
        });
        cy.get("#list").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Batch job successfully queued"
        );
    });

    it.only("Batch delete items", () => {
        let display = cy.getDisplay();
        let displays = [display];
        let batch = {
            job_id: 2,
            message: "Batch add operation queued",
        };
        let batches = [batch];
        let item = cy.getItem();

        // Click the "batch add" link from the list
        cy.intercept("GET", /\/api\/v1\/displays.(?!config).*/, {
            statusCode: 200,
            body: displays,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-displays");
        cy.intercept("GET", /\/api\/v1\/displays\/\d+/, display).as(
            "get-display"
        );
        cy.intercept("GET", /\/api\/v1\/items\/\d+/, {
            statusCode: 200,
            body: item,
        }).as("get-item");

        cy.visit("/cgi-bin/koha/display/display-home.pl");
        cy.contains("Batch remove items from list").click();

        cy.get("#barcodes").type("39999000002355\n39999000002331\n\n");
        cy.get("#display_id .vs__search").type(
            display.display_name + "{enter}",
            {
                force: true,
            }
        );

        // Submit the form, get 500
        cy.intercept("DELETE", "/api/v1/display/items/batch", {
            statusCode: 500,
        });
        cy.get("#list").contains("Save").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Internal Server Error"
        );

        // Submit the form, success!
        cy.intercept("DELETE", "/api/v1/display/items/batch", {
            statusCode: 202,
            body: batch,
        });
        cy.get("#list").contains("Save").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Batch job successfully queued"
        );
    });
});
