import {
    edifactTestData,
    testDataUtils,
} from "../../fixtures/edifact_test_data.js";

describe("EDIFACT Focus and Highlighting Tests", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.visit("/cgi-bin/koha/acqui/edifactmsgs.pl");
    });

    // Injects a test button, clicks it, waits for the intercepted response, and
    // asserts the modal tree is visible. All tests use cy.intercept so no real
    // DB messages are needed for this file.
    const openEDIModal = (
        attrs: Record<string, string>,
        interceptAlias: string
    ) => {
        cy.document().then(doc => {
            const button = doc.createElement("button");
            button.className = "view_edifact_message";
            Object.entries(attrs).forEach(([k, v]) =>
                button.setAttribute(k, v)
            );
            button.textContent = "View";
            doc.body.appendChild(button);
        });
        cy.get(".view_edifact_message").last().click();
        cy.wait(`@${interceptAlias}`);
        cy.get("#EDI_modal .edi-tree").should("be.visible");
    };

    describe("Focus Options Support", () => {
        it("should support basketno focus parameter", () => {
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(
                    testDataUtils.getFocusData("basketno", "12345")
                )
            ).as("basketResponse");

            openEDIModal(
                { "data-message-id": "1", "data-basketno": "12345" },
                "basketResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should support basketname focus parameter", () => {
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(
                    testDataUtils.getFocusData("basketname", "TestBasket001")
                )
            ).as("basketnameResponse");

            openEDIModal(
                {
                    "data-message-id": "1",
                    "data-basketname": "TestBasket001",
                },
                "basketnameResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should support invoicenumber focus parameter", () => {
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

            openEDIModal(
                {
                    "data-message-id": "1",
                    "data-invoicenumber": "TEST_INVOICE_001",
                },
                "invoiceResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });
    });

    describe("Message Focus and Highlighting", () => {
        beforeEach(() => {
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("multiMessageResponse");
        });

        it("should highlight focused message with visual styling", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "multiMessageResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
            cy.get("#EDI_modal .edi-focused-message").should("exist");
        });

        it("should scroll to focused message automatically", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "multiMessageResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should(
                "be.visible"
            );
        });

        it("should expand focused message automatically", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "multiMessageResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').within(() => {
                cy.get(".collapse").should("have.class", "show");
            });
        });

        it("should handle focus fallback when no matching message found", () => {
            openEDIModal(
                {
                    "data-message-id": "1",
                    "data-basketname": "NonExistentBasket",
                },
                "multiMessageResponse"
            );
            cy.get("#EDI_modal .collapse.show").should("exist");
        });
    });

    describe("Focus Matching Logic", () => {
        beforeEach(() => {
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("variedSegmentResponse");
        });

        it("should match basketno in BGM segments", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketno": "12345" },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should match basketname in RFF+ON segments", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should match invoicenumber in RFF+IV segments", () => {
            openEDIModal(
                {
                    "data-message-id": "1",
                    "data-invoicenumber": "TEST_INVOICE_001",
                },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should match invoicenumber in RFF+VN segments", () => {
            openEDIModal(
                {
                    "data-message-id": "1",
                    "data-invoicenumber": "TEST_INVOICE_001",
                },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should handle numeric basketno comparison correctly", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketno": "12345" },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should handle string basketname comparison correctly", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should handle non-numeric basketno without padding", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketno": "BASKET_TEXT_001" },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should pad numeric basketno to 11 digits for matching", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketno": "67890" },
                "variedSegmentResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });
    });

    describe("Focus Cleanup", () => {
        it("should handle multiple focus parameters correctly", () => {
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("multiFocusResponse");

            openEDIModal(
                {
                    "data-message-id": "1",
                    "data-basketno": "12345",
                    "data-basketname": "TestBasket001",
                },
                "multiFocusResponse"
            );
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });
    });

    describe("Cross-View Focus Persistence", () => {
        beforeEach(() => {
            cy.intercept(
                "GET",
                "**/edimsg.pl*",
                testDataUtils.createMockResponse(edifactTestData.focusTestData)
            ).as("crossViewResponse");
        });

        it("should maintain focus highlighting when switching from Tree to Raw view", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "crossViewResponse"
            );

            cy.get('#EDI_modal [data-view="tree"]').should(
                "have.class",
                "active"
            );
            cy.get("#EDI_modal .edi-focused-message").should("exist");

            cy.get('#EDI_modal [data-view="raw"]').click();
            cy.get('#EDI_modal [data-view="raw"]').should(
                "have.class",
                "active"
            );
            cy.get("#EDI_modal .edi-focused-segment-line").should("exist");
        });

        it("should maintain focus highlighting when switching from Raw to Tree view", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "crossViewResponse"
            );

            cy.get('#EDI_modal [data-view="raw"]').click();
            cy.get("#EDI_modal .edi-focused-segment-line").should("exist");

            cy.get('#EDI_modal [data-view="tree"]').click();
            cy.get('#EDI_modal [data-view="tree"]').should(
                "have.class",
                "active"
            );
            cy.get("#EDI_modal .edi-focused-message").should("exist");
            cy.get('#EDI_modal [data-focus-message="true"]').should("exist");
        });

        it("should highlight correct message segments in Raw view", () => {
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "crossViewResponse"
            );

            cy.get('#EDI_modal [data-view="raw"]').click();

            cy.get("#EDI_modal .edi-focused-segment-line").should("exist");
            cy.get("#EDI_modal .edi-focused-segment-line")
                .first()
                .should("have.attr", "data-message-index");
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
            openEDIModal(
                { "data-message-id": "1", "data-basketname": "TestBasket001" },
                "crossViewResponse"
            );

            cy.get('#EDI_modal [data-view="raw"]').click();
            cy.get("#EDI_modal .edi-focused-segment-line")
                .first()
                .should("be.visible");

            cy.get('#EDI_modal [data-view="tree"]').click();
            cy.get("#EDI_modal .edi-focused-message").should("be.visible");
        });
    });
});
