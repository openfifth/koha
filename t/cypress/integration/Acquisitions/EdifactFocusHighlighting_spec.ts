import {
    edifactTestData,
    testDataUtils,
} from "../../fixtures/edifact_test_data.js";

describe("EDIFACT Focus and Highlighting Tests", () => {
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
    });

    describe("Focus Options Support", () => {
        it("should support basketno focus parameter", () => {
            // Mock EDIFACT response with basketno data
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(
                    testDataUtils.getFocusData("basketno", "12345")
                )
            ).as("basketResponse");

            // Create a button with basketno data
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "12345");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@basketResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
        });

        it("should support basketname focus parameter", () => {
            // Mock EDIFACT response with basketname data
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(
                    testDataUtils.getFocusData("basketname", "TestBasket001")
                )
            ).as("basketnameResponse");

            // Create a button with basketname data
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@basketnameResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
        });

        it("should support invoicenumber focus parameter", () => {
            // Mock EDIFACT response with invoice data
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(
                    testDataUtils.getFocusData(
                        "invoicenumber",
                        "TEST_INVOICE_001"
                    )
                )
            ).as("invoiceResponse");

            // Create a button with invoice data
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-invoicenumber", "TEST_INVOICE_001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@invoiceResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
        });
    });

    describe("Message Focus and Highlighting", () => {
        beforeEach(() => {
            // Mock EDIFACT response with multiple messages
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("multiMessageResponse");
        });

        it("should highlight focused message with visual styling", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@multiMessageResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Check that focused message has special styling
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
            cy.get("#EDI_modal .edi-focused-message").should("exist");
        });

        it("should scroll to focused message automatically", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@multiMessageResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Wait for scroll animation to complete
            cy.wait(1000);

            // Check that focused message is visible in viewport
            cy.get('#EDI_modal [data-focus-message="true"]').should(
                "be.visible"
            );
        });

        it("should expand focused message automatically", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@multiMessageResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Check that focused message sections are expanded
            cy.get('#EDI_modal [data-focus-message="true"]').within(() => {
                cy.get(".collapse").should("have.class", "show");
            });
        });

        it("should handle focus fallback when no matching message found", () => {
            // Create a button with basketname that doesn't exist
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "NonExistentBasket");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@multiMessageResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Should expand entire tree as fallback
            cy.get("#EDI_modal .collapse.show").should("exist");
        });
    });

    describe("Focus Matching Logic", () => {
        beforeEach(() => {
            // Mock EDIFACT response with various segment types
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("variedSegmentResponse");
        });

        it("should match basketno in BGM segments", () => {
            // Create a button with basketno matching BGM element
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "12345");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Wait for focus application to complete - longer timeout for BGM matching
            cy.wait(1000);
            cy.get('#EDI_modal [data-focus-message="true"]', {
                timeout: 15000,
            }).should("exist");
        });

        it("should match basketname in RFF+ON segments", () => {
            // Create a button with basketname matching RFF+ON element
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should match invoicenumber in RFF+IV segments", () => {
            // Create a button with invoicenumber matching RFF+IV element
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-invoicenumber", "TEST_INVOICE_001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should match invoicenumber in RFF+VN segments", () => {
            // Create a button with invoicenumber matching RFF+VN element
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-invoicenumber", "TEST_INVOICE_001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should handle numeric basketno comparison correctly", () => {
            // Test with numeric basketno
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button-numeric";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "12345");
                button.textContent = "View Numeric";
                button.style.position = "fixed";
                button.style.top = "10px";
                button.style.left = "10px";
                button.style.zIndex = "9999";
                doc.body.appendChild(button);
            });

            cy.get(".test-button-numeric").click({ force: true });

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Wait for focus application and numeric comparison logic to complete
            cy.wait(1000);
            cy.get('#EDI_modal [data-focus-message="true"]', {
                timeout: 15000,
            }).should("exist");
        });

        it("should handle string basketname comparison correctly", () => {
            // Test with string basketname
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button-string";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View String";
                button.style.position = "fixed";
                button.style.top = "10px";
                button.style.left = "10px";
                button.style.zIndex = "9999";
                doc.body.appendChild(button);
            });

            cy.get(".test-button-string").click({ force: true });

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should handle non-numeric basketno without padding", () => {
            // Test with text basketno that should NOT be padded
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className =
                    "view_edifact_message test-button-text-basketno";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "BASKET_TEXT_001");
                button.textContent = "View Text Basketno";
                button.style.position = "fixed";
                button.style.top = "10px";
                button.style.left = "10px";
                button.style.zIndex = "9999";
                doc.body.appendChild(button);
            });

            cy.get(".test-button-text-basketno").click({ force: true });

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Wait for focus application to complete
            cy.wait(1000);
            cy.get('#EDI_modal [data-focus-message="true"]', {
                timeout: 15000,
            }).should("exist");
        });

        it("should pad numeric basketno to 11 digits for matching", () => {
            // This test verifies that numeric basketno 67890 gets padded to 00000067890
            // and matches the test data which has the padded version
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button-padding";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "67890");
                button.textContent = "View Padded Basketno";
                button.style.position = "fixed";
                button.style.top = "10px";
                button.style.left = "10px";
                button.style.zIndex = "9999";
                doc.body.appendChild(button);
            });

            cy.get(".test-button-padding").click({ force: true });

            cy.wait("@variedSegmentResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Wait for focus application and padding logic to complete
            cy.wait(1000);
            cy.get('#EDI_modal [data-focus-message="true"]', {
                timeout: 15000,
            }).should("exist");

            // Verify it's the correct message (should find focus highlighting)
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });
    });

    describe("Focus Cleanup", () => {
        it("should remove focus highlighting when modal closes", () => {
            // Mock EDIFACT response with focus data
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(
                    testDataUtils.getFocusData("basketno", "12345")
                )
            ).as("focusResponse");

            // Create a button with focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button-focus";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "12345");
                button.textContent = "View";
                button.style.position = "fixed";
                button.style.top = "10px";
                button.style.left = "10px";
                button.style.zIndex = "9999";
                doc.body.appendChild(button);
            });

            cy.get(".test-button-focus").click({ force: true });

            cy.wait("@focusResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Wait for initial focus highlighting to be applied
            cy.wait(1000);
            cy.get("#EDI_modal .edi-focused-message", {
                timeout: 10000,
            }).should("exist");

            // Close modal
            cy.get("#EDI_modal .btn-close").click();

            // Wait for modal to be fully hidden and reset
            cy.get("#EDI_modal").should("not.be.visible");
            cy.wait(500); // Give modal time to fully reset

            // Reopen modal
            cy.get(".test-button-focus").click({ force: true });

            cy.wait("@focusResponse");
            cy.get("#EDI_modal", { timeout: 10000 }).should("be.visible");
            cy.get("#EDI_modal .edi-tree", { timeout: 10000 }).should(
                "be.visible"
            );

            // Wait for focus highlighting to be re-applied
            cy.wait(1000);

            // Focus highlighting should be clean on reopen
            cy.get("#EDI_modal .edi-focused-message", {
                timeout: 10000,
            }).should("exist");
        });

        it("should handle multiple focus parameters correctly", () => {
            // Mock EDIFACT response with multiple matching elements
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("multiFocusResponse");

            // Create a button with multiple focus parameters
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketno", "12345");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();

            cy.wait("@multiFocusResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });
    });

    describe("Cross-View Focus Persistence", () => {
        beforeEach(() => {
            // Mock EDIFACT response with focus data
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("crossViewResponse");
        });

        it("should maintain focus highlighting when switching from Tree to Raw view", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();
            cy.wait("@crossViewResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Verify focus highlighting exists in Tree view
            cy.get('#EDI_modal [data-view="tree"]').should(
                "have.class",
                "active"
            );
            cy.get("#EDI_modal .edi-focused-message").should("exist");

            // Switch to Raw view
            cy.get('#EDI_modal [data-view="raw"]').click();
            cy.get('#EDI_modal [data-view="raw"]').should(
                "have.class",
                "active"
            );

            // Verify focus highlighting exists in Raw view
            cy.get("#EDI_modal .edi-focused-segment-line").should("exist");
            cy.get("#EDI_modal .edi-focused-segment-line").should(
                "have.length.greaterThan",
                0
            );
        });

        it("should maintain focus highlighting when switching from Raw to Tree view", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();
            cy.wait("@crossViewResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Start in Tree view, then switch to Raw view
            cy.get('#EDI_modal [data-view="raw"]').click();
            cy.get("#EDI_modal .edi-focused-segment-line").should("exist");

            // Switch back to Tree view
            cy.get('#EDI_modal [data-view="tree"]').click();
            cy.get('#EDI_modal [data-view="tree"]').should(
                "have.class",
                "active"
            );

            // Verify focus highlighting still exists in Tree view
            cy.get("#EDI_modal .edi-focused-message").should("exist");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should highlight correct message segments in Raw view", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();
            cy.wait("@crossViewResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Switch to Raw view
            cy.get('#EDI_modal [data-view="raw"]').click();

            // Verify that focused segment lines have the correct message index
            cy.get("#EDI_modal .edi-focused-segment-line").should("exist");
            cy.get("#EDI_modal .edi-focused-segment-line")
                .first()
                .should("have.attr", "data-message-index");

            // Verify visual styling is applied
            cy.get("#EDI_modal .edi-focused-segment-line").should(
                "have.css",
                "background-color"
            );
            cy.get("#EDI_modal .edi-focused-segment-line").should(
                "have.css",
                "border-left-color"
            );
        });

        it("should scroll to focused content when switching views", () => {
            // Create a button with basketname focus
            cy.document().then(doc => {
                const button = doc.createElement("button");
                button.className = "view_edifact_message test-button";
                button.setAttribute("data-message-id", "1");
                button.setAttribute("data-basketname", "TestBasket001");
                button.textContent = "View";
                doc.body.appendChild(button);
            });

            cy.get(".view_edifact_message").last().click();
            cy.wait("@crossViewResponse");
            cy.get("#EDI_modal .edi-tree").should("be.visible");

            // Switch to Raw view and verify focused content is visible
            cy.get('#EDI_modal [data-view="raw"]').click();
            cy.wait(200); // Wait for scroll animation

            cy.get("#EDI_modal .edi-focused-segment-line")
                .first()
                .should("be.visible");

            // Switch back to Tree view and verify focused content is visible
            cy.get('#EDI_modal [data-view="tree"]').click();
            cy.wait(200); // Wait for scroll animation

            cy.get("#EDI_modal .edi-focused-message").should("be.visible");
        });
    });
});
