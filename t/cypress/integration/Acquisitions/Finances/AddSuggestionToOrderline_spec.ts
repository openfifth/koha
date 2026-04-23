describe("SuggestionResource - Add order from suggestion", () => {
    const suggestion = {
        suggestion_id: 1,
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        copyright_date: 1925,
        volume_desc: "First Edition",
        isbn: "9780743273565",
        publisher_code: "Scribner",
        publication_year: "1925",
        publication_place: "New York",
        note: "A classic novel",
        status: "ACCEPTED",
        suggested_by: 10,
        managed_by: 20,
        budget_id: 1,
        library_id: "CPL",
        item_type: "BK",
        quantity: "3",
        item_price: 12.5,
        total_price: "37.50",
        biblio_id: null,
        suggester: {
            patron_id: 10,
            firstname: "Jane",
            preferred_name: "Jane",
            surname: "Doe",
            cardnumber: "jane001",
        },
        manager: {
            patron_id: 20,
            firstname: "John",
            preferred_name: "John",
            surname: "Smith",
            cardnumber: "john001",
        },
        library: { library_id: "CPL", name: "Central Public Library" },
        fund: { fund_id: 1, name: "Books Fund" },
        _strings: { item_type: { str: "Book" } },
    };

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Shows error when API fails", () => {
        cy.intercept("GET", "/api/v1/suggestions*", { statusCode: 500 });
        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong"
        );
    });

    it("Lists accepted suggestions with correct column data", () => {
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        // Suggestion column: title plus all detail fields added in the Vue conversion
        cy.get("#suggestions_list table tbody tr:first td")
            .eq(1)
            .within(() => {
                cy.contains("The Great Gatsby");
                cy.contains("F. Scott Fitzgerald");
                cy.contains("© 1925");
                cy.contains("First Edition");
                cy.contains("9780743273565");
                cy.contains("Scribner");
                cy.contains("New York");
                cy.contains("A classic novel");
            });
        cy.get("#suggestions_list table tbody tr:first").within(() => {
            cy.contains("Book"); // Document type via _strings
            // Patron columns render as anchor tags
            cy.contains("a", "Jane Doe"); // Suggested by
            cy.contains("a", "John Smith"); // Accepted by
            cy.contains("Central Public Library");
            cy.contains("Books Fund");
            cy.contains("3"); // Quantity
            cy.contains("Order");
        });
    });

    it("Renders Price and Total columns", () => {
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        cy.get("#suggestions_list table thead").contains("Price");
        cy.get("#suggestions_list table thead").contains("Total");

        // Columns were previously inert type:"text" attrs with no tableColumnDefinition
        // and would not render at all — verify they now contain a value
        cy.get("#suggestions_list table tbody tr:first td")
            .eq(7)
            .invoke("text")
            .invoke("trim")
            .should("not.be.empty"); // Price
        cy.get("#suggestions_list table tbody tr:first td")
            .eq(9)
            .invoke("text")
            .invoke("trim")
            .should("not.be.empty"); // Total
    });

    it("Does not display quantity when zero", () => {
        const zeroQtySuggestion = {
            ...suggestion,
            suggestion_id: 2,
            title: "Zero Quantity Book",
            quantity: "0",
        };
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [zeroQtySuggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        cy.get("#suggestions_list table tbody tr:first td")
            .eq(8) // Quantity column
            .invoke("text")
            .invoke("trim")
            .should("be.empty");
    });

    it("Mine filter sends request filtered by managed_by only", () => {
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("mine-filter");

        cy.get('.filters input[value="Mine"]').click();
        cy.wait("@mine-filter")
            .its("request.url")
            .should("include", "managed_by")
            .and("not.include", "suggested_by");
    });

    it("All filter does not filter by managed_by", () => {
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [],
            headers: {
                "X-Base-Total-Count": "0",
                "X-Total-Count": "0",
            },
        }).as("mine-filter");
        cy.get('input[value="Mine"]').click();
        cy.wait("@mine-filter");

        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("all-filter");
        cy.get('input[value="All"]').click();
        cy.wait("@all-filter")
            .its("request.url")
            .should("not.include", "managed_by");
    });

    it("Order button navigates to orderline form with suggestion_id", () => {
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestion],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");
        cy.intercept("GET", "/api/v1/acquisitions/orderlines*", {
            statusCode: 200,
            body: [],
            headers: {
                "X-Base-Total-Count": "0",
                "X-Total-Count": "0",
            },
        });

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        cy.get("#suggestions_list table tbody tr:first")
            .contains("Order")
            .click();
        cy.url()
            .should("include", `suggestion_id=${suggestion.suggestion_id}`)
            .and("not.include", "biblionumber");
    });

    it("Order button includes biblionumber when suggestion has a biblio_id", () => {
        const suggestionWithBiblio = { ...suggestion, biblio_id: 42 };
        cy.intercept("GET", "/api/v1/suggestions*", {
            statusCode: 200,
            body: [suggestionWithBiblio],
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        }).as("get-suggestions");
        cy.intercept("GET", "/api/v1/acquisitions/orderlines*", {
            statusCode: 200,
            body: [],
            headers: {
                "X-Base-Total-Count": "0",
                "X-Total-Count": "0",
            },
        });

        cy.visit("/cgi-bin/koha/acquisitions/order_management/suggestions");
        cy.wait("@get-suggestions"); // count request
        cy.wait("@get-suggestions"); // DataTable data request

        cy.get("#suggestions_list table tbody tr:first")
            .contains("Order")
            .click();
        cy.url()
            .should(
                "include",
                `suggestion_id=${suggestionWithBiblio.suggestion_id}`
            )
            .and("include", "biblionumber=42");
    });
});
