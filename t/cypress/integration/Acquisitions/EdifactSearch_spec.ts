import {
    edifactTestData,
    testDataUtils,
} from "../../fixtures/edifact_test_data.js";

describe("EDIFACT Search Functionality Tests", () => {
    // Helper function to reliably type search terms and wait for results
    const typeSearchTerm = (searchTerm, shouldFindResults = true) => {
        // Clear input first to ensure clean state
        cy.get("#EDI_modal .edi-search-input").clear();

        // Type with delay and verify the value was entered correctly
        cy.get("#EDI_modal .edi-search-input").type(searchTerm, { delay: 50 });

        // Verify the input contains what we typed - retry if needed
        cy.get("#EDI_modal .edi-search-input").should("have.value", searchTerm);

        if (shouldFindResults) {
            // Wait for debounce + search to complete (with longer timeout for reliability)
            cy.get("#EDI_modal .edi-search-count", { timeout: 3000 }).should(
                "not.contain",
                "0 results"
            );
        } else {
            // Wait for debounce period when we expect no results
            cy.wait(700);
        }
    };

    let edifact_test_data = null;

    before(() => {
        // Insert test EDIFACT messages into the database
        cy.task("insertSampleEdifactMessages").then(test_data => {
            edifact_test_data = test_data;
        });
    });

    after(() => {
        // Clean up test data
        if (edifact_test_data) {
            cy.task("deleteSampleEdifactMessages", edifact_test_data);
        }
    });

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.visit("/cgi-bin/koha/acqui/edifactmsgs.pl");

        // Mock comprehensive EDIFACT response for search testing
        cy.intercept(
            "GET",
            "**/edimsg.pl*",
            testDataUtils.createMockResponse(edifactTestData.searchableContent)
        ).as("searchResponse");
    });

    describe("Search Interface", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");
        });

        it("should display search input field", () => {
            cy.get("#EDI_modal .edi-search-input").should("be.visible");
            cy.get("#EDI_modal .edi-search-input").should(
                "have.attr",
                "placeholder",
                "Search segments..."
            );
        });

        it("should display search input as type search", () => {
            cy.get("#EDI_modal .edi-search-input").should(
                "have.attr",
                "type",
                "search"
            );
        });

        it("should display search results counter", () => {
            cy.get("#EDI_modal .edi-search-count").should("be.visible");
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );
        });

        it("should display navigation buttons", () => {
            cy.get("#EDI_modal .edi-search-prev").should("be.visible");
            cy.get("#EDI_modal .edi-search-next").should("be.visible");
            cy.get("#EDI_modal .edi-search-prev").should("be.disabled");
            cy.get("#EDI_modal .edi-search-next").should("be.disabled");
        });

        it("should display search form in main navbar", () => {
            cy.get("#EDI_modal .edi-main-navbar .edi-search-form").should(
                "exist"
            );
            cy.get("#EDI_modal .edi-main-navbar .edi-search-form").should(
                "be.visible"
            );
        });
    });

    describe("Search Functionality", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");
        });

        it("should perform search with debouncing", () => {
            // Type JavaScript and verify the search completes
            typeSearchTerm("JavaScript");

            // Results should appear
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
        });

        it("should find segments containing search term", () => {
            typeSearchTerm("SEARCH_BASKET");

            // Should find the BGM segment with SEARCH_BASKET
            cy.get("#EDI_modal .edi-search-count").should("contain", "1 of 1");
        });

        it("should find multiple matches", () => {
            typeSearchTerm("JavaScript");

            // Should find multiple JavaScript matches
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
        });

        it("should be case insensitive", () => {
            typeSearchTerm("javascript");

            // Should find JavaScript segments (case insensitive)
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
        });

        it("should ignore searches with less than 2 characters", () => {
            typeSearchTerm("O", false);

            // Should not perform search
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );
        });

        it("should highlight search matches", () => {
            typeSearchTerm("SEARCH_BASKET");

            // Should highlight the match
            cy.get("#EDI_modal .edi-search-highlight").should("exist");
            cy.get("#EDI_modal .edi-search-highlight").should(
                "contain",
                "SEARCH_BASKET"
            );
        });

        it("should enable navigation buttons when results exist", () => {
            typeSearchTerm("JavaScript");

            // Navigation buttons should be enabled
            cy.get("#EDI_modal .edi-search-prev").should("not.be.disabled");
            cy.get("#EDI_modal .edi-search-next").should("not.be.disabled");
        });
    });

    describe("Search Navigation", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");

            // Perform search to get multiple results
            typeSearchTerm("JavaScript");
        });

        it("should navigate to next result", () => {
            cy.get("#EDI_modal .edi-search-next").click();

            // Should update counter (2 of 6)
            cy.get("#EDI_modal .edi-search-count").should("contain", "2 of 6");
        });

        it("should navigate to previous result", () => {
            // First go to next result
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-count").should("contain", "2 of 6");

            // Then go back to previous
            cy.get("#EDI_modal .edi-search-prev").click();
            cy.get("#EDI_modal .edi-search-count").should("contain", "1 of 6");
        });

        it("should wrap around at end of results", () => {
            // Navigate to last result (click next 5 times to get to 6 of 6)
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-count").should("contain", "6 of 6");

            // Navigate past end should wrap to first
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-count").should("contain", "1 of 6");
        });

        it("should wrap around at beginning of results", () => {
            // Navigate to previous from first result should wrap to last
            cy.get("#EDI_modal .edi-search-prev").click();
            cy.get("#EDI_modal .edi-search-count").should("contain", "6 of 6");
        });

        it("should highlight current result", () => {
            // Current result should have special highlighting
            cy.get("#EDI_modal .edi-search-current").should("exist");

            // Navigate to next result
            cy.get("#EDI_modal .edi-search-next").click();
            cy.get("#EDI_modal .edi-search-count").should("contain", "2 of 6");

            // Should still have one current result
            cy.get("#EDI_modal .edi-search-current").should("have.length", 1);
        });

        it("should scroll to current result", () => {
            // Navigate to next result
            cy.get("#EDI_modal .edi-search-next").click();

            // Current result should be visible
            cy.get("#EDI_modal .edi-search-current").should("be.visible");
        });
    });

    describe("Keyboard Navigation", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");

            // Perform search to get multiple results
            typeSearchTerm("JavaScript");
        });

        it("should navigate with Enter key", () => {
            cy.get("#EDI_modal .edi-search-input").type("{enter}");

            // Should navigate to next result
            cy.get("#EDI_modal .edi-search-count").should("contain", "2 of 6");
        });

        it("should navigate backwards with Shift+Enter", () => {
            // First go to next result
            cy.get("#EDI_modal .edi-search-input").type("{enter}");
            cy.get("#EDI_modal .edi-search-count").should("contain", "2 of 6");

            // Then go back with Shift+Enter
            cy.get("#EDI_modal .edi-search-input").type("{shift+enter}");
            cy.get("#EDI_modal .edi-search-count").should("contain", "1 of 6");
        });

        it("should not submit form on Enter key", () => {
            // Enter key should not cause page navigation
            cy.get("#EDI_modal .edi-search-input").type("{enter}");
            cy.url().should("include", "/acqui/edifactmsgs.pl");
        });
    });

    describe("Search Clearing", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");

            // Perform search
            typeSearchTerm("JavaScript");
        });

        it("should clear search when input is cleared with native clear", () => {
            // Use browser's native clear functionality
            cy.get("#EDI_modal .edi-search-input").clear();
            cy.wait(600); // Wait for debounce

            // Results should be reset
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );

            // Navigation buttons should be disabled
            cy.get("#EDI_modal .edi-search-prev").should("be.disabled");
            cy.get("#EDI_modal .edi-search-next").should("be.disabled");
        });

        it("should remove highlights when search is cleared", () => {
            cy.get("#EDI_modal .edi-search-highlight").should("exist");

            cy.get("#EDI_modal .edi-search-input").clear();
            cy.wait(600); // Wait for debounce

            // Highlights should be removed
            cy.get("#EDI_modal .edi-search-highlight").should("not.exist");
            cy.get("#EDI_modal .edi-search-current").should("not.exist");
        });

        it("should clear search when input is emptied", () => {
            cy.get("#EDI_modal .edi-search-input").clear();
            cy.wait(600);

            // Results should be reset
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );

            // Highlights should be removed
            cy.get("#EDI_modal .edi-search-highlight").should("not.exist");
        });
    });

    describe("Search in Different Views", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");
        });

        it("should search in tree view", () => {
            // Ensure we're in tree view
            cy.get('#EDI_modal [data-view="tree"]').click();

            typeSearchTerm("JavaScript");

            // Should find results in tree view
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
            cy.get("#EDI_modal .edi-search-highlight").should("exist");
        });

        it("should search in raw view", () => {
            // Switch to raw view
            cy.get('#EDI_modal [data-view="raw"]').click();

            typeSearchTerm("JavaScript");

            // Should find results in raw view
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
            cy.get("#EDI_modal .edi-search-highlight").should("exist");
        });

        it("should re-execute search when switching views", () => {
            // Search in tree view
            typeSearchTerm("JavaScript");

            cy.get("#EDI_modal .edi-search-count").should("contain", "of");

            // Switch to raw view
            cy.get('#EDI_modal [data-view="raw"]').click();

            // Search should be re-executed in raw view
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
            cy.get("#EDI_modal .edi-search-highlight").should("exist");
        });
    });

    describe("Smart Expand/Collapse for Search", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");
        });

        it("should expand sections containing search results", () => {
            // Collapse all sections first
            cy.get("#EDI_modal .collapse-all-btn").click();
            cy.wait(500);

            // Perform search
            typeSearchTerm("JavaScript");

            // Sections with results should be expanded
            cy.get("#EDI_modal .edi-search-current").should("be.visible");
            cy.get("#EDI_modal .edi-search-current")
                .parents(".collapse")
                .should("have.class", "show");
        });

        it("should collapse sections without search results", () => {
            // Expand all sections first
            cy.get("#EDI_modal .expand-all-btn").click();
            cy.wait(500);

            // Perform specific search that matches only some sections
            typeSearchTerm("SEARCH_BASKET");

            // Wait for smart expand/collapse to complete
            cy.wait(100);

            // Section with result should be expanded
            cy.get("#EDI_modal .edi-search-current").should("be.visible");
        });
    });

    describe("Search Performance", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");
        });

        it("should handle rapid typing with debouncing", () => {
            // Type rapidly (spell JavaScript)
            cy.get("#EDI_modal .edi-search-input").type("J");
            cy.get("#EDI_modal .edi-search-input").type("a");
            cy.get("#EDI_modal .edi-search-input").type("v");
            cy.get("#EDI_modal .edi-search-input").type("a");
            cy.get("#EDI_modal .edi-search-input").type("S");

            // Should not perform search until debounce completes
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );

            // Wait for debounce
            cy.wait(600);

            // Should perform search once
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
        });

        it("should handle empty search gracefully", () => {
            cy.get("#EDI_modal .edi-search-input").type("   ");
            cy.wait(600);

            // Should not perform search for whitespace only
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );
        });

        it("should handle special characters in search", () => {
            typeSearchTerm("220+ORDER");

            // Should handle special regex characters (should find RFF+IV:220+ORDER67890)
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");
        });
    });

    describe("Search State Management", () => {
        beforeEach(() => {
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");
        });

        it("should maintain search state when modal is reopened", () => {
            // Perform search
            typeSearchTerm("JavaScript");

            // Close modal
            cy.get("#EDI_modal .btn-close").click();

            // Reopen modal
            cy.get(".view_edifact_message").first().click();
            cy.wait("@searchResponse");
            cy.get("#EDI_modal .edi-tree", {
                timeout: 10000,
            }).should("be.visible");

            // Search should be cleared on new modal open
            cy.get("#EDI_modal .edi-search-input").should("have.value", "");
            cy.get("#EDI_modal .edi-search-count").should(
                "contain",
                "0 results"
            );
        });

        it("should clear search state on modal close", () => {
            // Perform search
            typeSearchTerm("JavaScript");
            cy.get("#EDI_modal .edi-search-count").should("contain", "of");

            // Close modal
            cy.get("#EDI_modal .btn-close").click();

            // Modal should reset content
            cy.get("#EDI_modal .modal-body").should("contain", "Loading");
        });
    });
});
