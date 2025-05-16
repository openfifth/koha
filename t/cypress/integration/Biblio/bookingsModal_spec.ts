const dayjs = require("dayjs"); /* Cannot use our calendar JS code, it's in an include file (!)
                                   Also note that moment.js is deprecated */
const isSameOrBefore = require("dayjs/plugin/isSameOrBefore");
dayjs.extend(isSameOrBefore);

describe("Booking Modal Tests", () => {
    // Test data setup
    const testData = {
        biblionumber: "134",
        patronId: "19",
        pickupLibraryId: "CPL",
        itemNumber: "287",
        itemTypeId: "BK",
        startDate: dayjs().add(1, "day").startOf("day").toDate(), // 1 day from now at midnight
        endDate: dayjs().add(5, "day").endOf("day").toDate(), // 5 days from now at 23:59:59.999
    };

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        // Visit the page with the booking modal
        cy.visit(
            "/cgi-bin/koha/catalogue/detail.pl?biblionumber=" +
                testData.biblionumber
        );

        // Intercept API calls and provide mock responses
        cy.intercept("GET", "/api/v1/biblios/*/items?bookable=1&_per_page=-1", {
            fixture: "bookings/bookable_items.json",
        }).as("getBookableItems");

        cy.fixture("bookings/bookings.json").then(bookings => {
            const today = dayjs();

            // Update the dates in the fixture data relative to today
            bookings[0].start_date = today
                .add(8, "day")
                .startOf("day")
                .toISOString(); // Today + 8 days at 00:00
            bookings[0].end_date = today
                .add(13, "day")
                .endOf("day")
                .toISOString(); // Today + 13 days at 23:59

            bookings[1].start_date = today
                .add(14, "day")
                .startOf("day")
                .toISOString(); // Today + 14 days at 00:00
            bookings[1].end_date = today
                .add(18, "day")
                .endOf("day")
                .toISOString(); // Today + 18 days at 23:59

            bookings[2].start_date = today
                .add(28, "day")
                .startOf("day")
                .toISOString(); // Today + 28 days at 00:00
            bookings[2].end_date = today
                .add(33, "day")
                .endOf("day")
                .toISOString(); // Today + 33 days at 23:59

            // Use the modified fixture data in your intercept
            cy.intercept("GET", "/api/v1/bookings?biblio_id=*&_per_page=-1*", {
                body: bookings,
            }).as("getBookings");
        });

        cy.intercept("GET", "/api/v1/biblios/*/checkouts?_per_page=-1", {
            fixture: "bookings/checkouts.json",
        }).as("getCheckouts");

        cy.intercept("GET", "/api/v1/patrons/*", {
            fixture: "bookings/patron.json",
        }).as("getPatron");

        cy.intercept("GET", "/api/v1/biblios/*/pickup_locations*", {
            fixture: "bookings/pickup_locations.json",
        }).as("getPickupLocations");

        cy.intercept("GET", "/api/v1/circulation_rules*", {
            fixture: "bookings/circulation_rules.json",
        }).as("getCirculationRules");

        cy.intercept("POST", "/api/v1/bookings", {
            statusCode: 201,
            body: {
                booking_id: "1001",
                start_date: testData.startDate.toISOString(),
                end_date: testData.endDate.toISOString(),
                pickup_library_id: testData.pickupLibraryId,
                biblio_id: testData.biblionumber,
                item_id: testData.itemNumber,
                patron_id: testData.patronId,
            },
        }).as("createBooking");

        cy.intercept("PUT", "/api/v1/bookings/*", {
            statusCode: 200,
            body: {
                booking_id: "1001",
                start_date: testData.startDate.toISOString(),
                end_date: testData.endDate.toISOString(),
                pickup_library_id: testData.pickupLibraryId,
                biblio_id: testData.biblionumber,
                item_id: testData.itemNumber,
                patron_id: testData.patronId,
            },
        }).as("updateBooking");

        // Populate the select2 search results for patron search
        cy.intercept("GET", "/api/v1/patrons*", {
            body: [
                {
                    patron_id: testData.patronId,
                    surname: "Doe",
                    firstname: "John",
                    cardnumber: "12345",
                    library_id: "1",
                    library: {
                        name: "Main Library",
                    },
                    category_id: "1",
                    date_of_birth: "1990-01-01",
                },
            ],
            pagination: { more: false },
        }).as("searchPatrons");

        // Add clickable button
        cy.document().then(doc => {
            const button = doc.createElement("button");
            button.setAttribute("data-bs-toggle", "modal");
            button.setAttribute("data-bs-target", "#placeBookingModal");
            button.setAttribute("data-biblionumber", testData.biblionumber);
            button.setAttribute("id", "placebooking");
            doc.body.appendChild(button);
        });
    });

    it("should load the booking modal correctly", () => {
        // Open the booking modal
        cy.get("#placebooking").click();

        // Check modal title
        cy.get("#placeBookingLabel").should("contain", "Place booking");

        // Check form elements are present
        cy.get("#booking_patron_id").should("exist");
        cy.get("#pickup_library_id").should("exist");
        cy.get("#booking_itemtype").should("exist");
        cy.get("#booking_item_id").should("exist");
        cy.get("#period").should("exist");

        // Check hidden fields
        cy.get("#booking_biblio_id").should(
            "have.value",
            testData.biblionumber
        );
        cy.get("#booking_start_date").should("have.value", "");
        cy.get("#booking_end_date").should("have.value", "");
    });

    it("should enable fields in proper sequence", () => {
        // Open the booking modal
        cy.get("#placebooking").click();

        // Initially only patron field should be enabled
        cy.get("#booking_patron_id").should("not.be.disabled");
        cy.get("#pickup_library_id").should("be.disabled");
        cy.get("#booking_itemtype").should("be.disabled");
        cy.get("#booking_item_id").should("be.disabled");
        cy.get("#period").should("be.disabled");

        // Select patron
        cy.selectFromSelect2ByIndex("#booking_patron_id", 0, "John");
        //cy.getSelect2("#booking_patron_id")
        //    .select2({ search: "John" })
        //    .select2({ selectIndex: 0 });
        cy.wait("@getPickupLocations");

        // After patron selection, pickup location, item type and item should be enabled
        cy.get("#pickup_library_id").should("not.be.disabled");
        cy.get("#booking_itemtype").should("not.be.disabled");
        cy.get("#booking_item_id").should("not.be.disabled");
        cy.get("#period").should("be.disabled");

        // Select pickup location
        cy.selectFromSelect2ByIndex("#pickup_library_id", 0);

        // Select item type, trigger circulation rules
        cy.selectFromSelect2ByIndex("#booking_itemtype", 0);
        cy.wait("@getCirculationRules");

        // After patron, pickup location and itemtype/item selection, date picker should be enabled
        cy.get("#period").should("not.be.disabled");

        // Clear item type and confirm period is disabled
        cy.clearSelect2("#booking_itemtype");
        cy.get("#period").should("be.disabled");

        // Select item, re-enable period
        cy.selectFromSelect2ByIndex("#booking_item_id", 1);
        cy.get("#period").should("not.be.disabled");
    });

    it("should handle item type and item dependencies correctly", () => {
        // Open the booking modal
        cy.get("#placebooking").click();

        // Select patron and pickup location first
        cy.selectFromSelect2ByIndex("#booking_patron_id", 0, "John");
        cy.wait("@getPickupLocations");
        cy.selectFromSelect2ByIndex("#pickup_library_id", 0);

        // Select an item first
        cy.selectFromSelect2ByIndex("#booking_item_id", 1);
        cy.wait("@getCirculationRules");

        // Verify that item type gets selected automatically
        cy.get("#booking_itemtype").should("have.value", testData.itemTypeId);

        // Verify that item type gets disabled
        cy.get("#booking_itemtype").should("be.disabled");

        // Reset the modal
        cy.get('#placeBookingModal button[data-bs-dismiss="modal"]')
            .first()
            .click();
        cy.get("#placebooking").click();

        // Now select patron, pickup and item type first
        cy.selectFromSelect2ByIndex("#booking_patron_id", 0, "John");
        cy.wait("@getPickupLocations");
        cy.selectFromSelect2ByIndex("#pickup_library_id", 0);
        cy.selectFromSelect2ByIndex("#booking_itemtype", 0);
        cy.wait("@getCirculationRules");
        cy.wait(300);

        // Verify that only 'Any item' option and items of selected type are enabled
        cy.get("#booking_item_id > option").then($options => {
            const enabledOptions = $options.filter(":not(:disabled)");
            enabledOptions.each(function () {
                const $option = cy.wrap(this);

                // Get both the value and the data-itemtype attribute to make decisions
                $option.invoke("val").then(value => {
                    if (value === "0") {
                        // We need to re-wrap the element since invoke('val') changed the subject
                        cy.wrap(this).should("contain.text", "Any item");
                    } else {
                        // Re-wrap the element again for this assertion
                        cy.wrap(this).should(
                            "have.attr",
                            "data-itemtype",
                            testData.itemTypeId
                        );
                    }
                });
            });
        });
    });

    it("should disable dates before today and between today and selected start date", () => {
        const today = dayjs();

        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        cy.wait(["@getBookableItems", "@getBookings", "@getCheckouts"]);
        setupModalForDateTesting();

        cy.get("#period").as("flatpickrInput");
        cy.get("@flatpickrInput").openFlatpickr();

        cy.get("@flatpickrInput").then($el => {
            // Phase 1: Test that all dates prior to today are disabled
            cy.log("Testing dates prior to today are disabled");

            // Find the first visible date in the calendar to determine range
            cy.get(".flatpickr-day:not(.hidden)")
                .first()
                .then($firstDay => {
                    const firstDate = dayjs($firstDay.attr("aria-label"));

                    // Check all dates from first visible date up to today are disabled
                    for (
                        let checkDate = firstDate;
                        checkDate.isSameOrBefore(today, "day");
                        checkDate = checkDate.add(1, "day")
                    ) {
                        cy.get("@flatpickrInput")
                            .getFlatpickrDay(checkDate.toDate())
                            .should("have.class", "flatpickr-disabled");
                    }
                });

            // Phase 2: Test that dates after today are initially enabled
            cy.log("Testing dates after today are initially enabled");

            // Test a broader range of future dates for better coverage
            for (
                let checkDate = today.add(1, "day");
                checkDate.isSameOrBefore(today.add(7, "day"), "day");
                checkDate = checkDate.add(1, "day")
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDay(checkDate.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }
        });

        // Phase 3: Select a start date
        cy.log("Selecting start date (5 days from today)");
        const startDate = today.add(5, "day");
        cy.get("@flatpickrInput").selectFlatpickrDate(startDate.toDate());

        // Phase 4: Verify dates between today and start date are now disabled
        cy.log("Testing dates between today and start date are disabled");

        cy.get("@flatpickrInput").then($el => {
            for (
                let checkDate = today.add(1, "day");
                checkDate.isBefore(startDate, "day");
                checkDate = checkDate.add(1, "day")
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDay(checkDate.toDate())
                    .should("have.class", "flatpickr-disabled");
            }

            // Verify the selected start date itself is properly selected and not disabled
            cy.get("@flatpickrInput")
                .getFlatpickrDay(startDate.toDate())
                .should("not.have.class", "flatpickr-disabled")
                .and("have.class", "selected");
        });

        // Phase 5: Verify dates after the start date remain enabled
        cy.log("Testing dates after start date remain enabled");

        cy.get("@flatpickrInput").then($el => {
            for (
                let checkDate = startDate.add(1, "day");
                checkDate.isSameOrBefore(startDate.add(5, "day"), "day");
                checkDate = checkDate.add(1, "day")
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDay(checkDate.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }
        });
    });

    it("should disable dates with existing bookings for same item", () => {
        const today = dayjs();
        const TEST_ITEM_ID = "789"; // The item we'll be testing with
        const TEST_ITEM_BARCODE = "BARCODE789";

        // Setup fixture data with dynamic dates
        cy.fixture("bookings/bookings.json").then(bookings => {
            // Modify existing bookings to create a comprehensive test scenario
            // All bookings will be for the same item to test date conflicts
            bookings[0].item_id = TEST_ITEM_ID;
            bookings[0].start_date = today
                .add(8, "day")
                .startOf("day")
                .toISOString();
            bookings[0].end_date = today
                .add(13, "day")
                .endOf("day")
                .toISOString();

            bookings[1].item_id = TEST_ITEM_ID;
            bookings[1].start_date = today
                .add(14, "day")
                .startOf("day")
                .toISOString();
            bookings[1].end_date = today
                .add(18, "day")
                .endOf("day")
                .toISOString();

            bookings[2].item_id = TEST_ITEM_ID;
            bookings[2].start_date = today
                .add(28, "day")
                .startOf("day")
                .toISOString();
            bookings[2].end_date = today
                .add(33, "day")
                .endOf("day")
                .toISOString();

            // Add additional bookings for comprehensive testing
            const additionalBookings = [
                {
                    booking_id: "1004",
                    biblio_id: "123",
                    patron_id: "459",
                    item_id: TEST_ITEM_ID,
                    pickup_library_id: "1",
                    start_date: today
                        .add(35, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(37, "day").endOf("day").toISOString(),
                    status: "pending",
                },
                {
                    booking_id: "1005",
                    biblio_id: "123",
                    patron_id: "460",
                    item_id: "different_item", // Different item - should not affect our test
                    pickup_library_id: "1",
                    start_date: today
                        .add(20, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(25, "day").endOf("day").toISOString(),
                    status: "pending",
                },
            ];

            const allBookings = [...bookings, ...additionalBookings];

            // Use the modified fixture data in intercept
            cy.intercept("GET", "/api/v1/bookings?biblio_id=*&_per_page=-1*", {
                body: allBookings,
            }).as("getBookings");
        });

        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        cy.wait(["@getBookableItems", "@getBookings", "@getCheckouts"]);
        setupModalForDateTesting();

        // Select the specific item that has existing bookings (TEST_ITEM_BARCODE)
        cy.selectFromSelect2("#booking_item_id", TEST_ITEM_BARCODE);

        cy.get("#period").as("flatpickrInput");
        cy.get("@flatpickrInput").openFlatpickr();

        // Define booking periods for the selected item only
        const bookingPeriodsForSelectedItem = [
            {
                name: "First booking period",
                start: today.add(8, "day"),
                end: today.add(13, "day"),
            },
            {
                name: "Second booking period",
                start: today.add(14, "day"),
                end: today.add(18, "day"),
            },
            {
                name: "Third booking period",
                start: today.add(28, "day"),
                end: today.add(33, "day"),
            },
            {
                name: "Fourth booking period",
                start: today.add(35, "day"),
                end: today.add(37, "day"),
            },
        ];

        cy.get("@flatpickrInput").then($el => {
            // Phase 1: Test dates before first booking period are available
            cy.log("Testing dates before first booking period are available");

            for (
                let checkDate = today.add(1, "day");
                checkDate.isBefore(
                    bookingPeriodsForSelectedItem[0].start,
                    "day"
                );
                checkDate = checkDate.add(1, "day")
            ) {
                cy.get("@flatpickrInput")
                    .getFlatpickrDay(checkDate.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }

            // Phase 2: Test each booked period individually
            bookingPeriodsForSelectedItem.forEach((period, index) => {
                cy.log(`Testing ${period.name} dates are disabled`);

                // Test dates within the booked range are disabled
                for (
                    let checkDate = period.start;
                    checkDate.isSameOrBefore(period.end, "day");
                    checkDate = checkDate.add(1, "day")
                ) {
                    cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                        checkDate.toDate()
                    );
                    cy.get("@flatpickrInput")
                        .getFlatpickrDay(checkDate.toDate())
                        .should("have.class", "flatpickr-disabled");
                }
            });

            // Phase 3: Test gaps between booking periods are available
            cy.log("Testing gaps between booking periods are available");

            for (let i = 0; i < bookingPeriodsForSelectedItem.length - 1; i++) {
                const currentPeriod = bookingPeriodsForSelectedItem[i];
                const nextPeriod = bookingPeriodsForSelectedItem[i + 1];

                // Test dates in the gap between current and next booking period
                for (
                    let checkDate = currentPeriod.end.add(1, "day");
                    checkDate.isBefore(nextPeriod.start, "day");
                    checkDate = checkDate.add(1, "day")
                ) {
                    cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                        checkDate.toDate()
                    );
                    cy.get("@flatpickrInput")
                        .getFlatpickrDay(checkDate.toDate())
                        .should("not.have.class", "flatpickr-disabled");
                }
            }

            // Phase 4: Test that dates booked for different items are still available
            cy.log("Testing dates booked for different items remain available");

            // The booking for different_item (days 20-25) should not affect our selected item
            const differentItemBookingStart = today.add(20, "day");
            const differentItemBookingEnd = today.add(25, "day");

            for (
                let checkDate = differentItemBookingStart;
                checkDate.isSameOrBefore(differentItemBookingEnd, "day");
                checkDate = checkDate.add(1, "day")
            ) {
                cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                    checkDate.toDate()
                );
                cy.get("@flatpickrInput")
                    .getFlatpickrDay(checkDate.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }

            // Phase 5: Test dates after last booking period are available
            cy.log("Testing dates after last booking period are available");

            const lastPeriod =
                bookingPeriodsForSelectedItem[
                    bookingPeriodsForSelectedItem.length - 1
                ];
            for (
                let checkDate = lastPeriod.end.add(1, "day");
                checkDate.isSameOrBefore(lastPeriod.end.add(5, "day"), "day");
                checkDate = checkDate.add(1, "day")
            ) {
                cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                    checkDate.toDate()
                );
                cy.get("@flatpickrInput")
                    .getFlatpickrDay(checkDate.toDate())
                    .should("not.have.class", "flatpickr-disabled");
            }
        });
    });

    it("should disable dates where all items of the same itemtype are booked", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Ensure "Any item" (value 0) is selected
        cy.selectFromSelect2ByIndex("#booking_item_id", 0);

        // Select an itemtype that has existing bookings
        cy.selectFromSelect2ByIndex("#booking_itemtype", 0);
        cy.wait("@getCirculationRules");
    });

    it("should maximize booking window by dynamically reducing available items during overlaps", () => {
        const today = dayjs();
        const TEST_ITEMTYPE = "TABLET";
        const TEST_ITEMTYPE_DESCRIPTION = "Tablet";

        // Items of the same itemtype with staggered availability
        const ITEMTYPE_ITEMS = [
            { item_id: "201", barcode: "TABLET001" },
            { item_id: "202", barcode: "TABLET002" },
            { item_id: "203", barcode: "TABLET003" },
            { item_id: "204", barcode: "TABLET004" },
        ];

        cy.fixture("bookings/bookings.json").then(bookings => {
            // Create a complex booking scenario to test dynamic item pool reduction
            const strategicBookings = [
                // TABLET001: Available days 5-9, then booked 10-15, then available again 16+
                {
                    booking_id: "3001",
                    biblio_id: "123",
                    patron_id: "501",
                    item_id: ITEMTYPE_ITEMS[0].item_id,
                    pickup_library_id: "1",
                    start_date: today
                        .add(10, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(15, "day").endOf("day").toISOString(),
                    status: "pending",
                },

                // TABLET002: Available days 5-12, then booked 13-20, then available 21+
                {
                    booking_id: "3002",
                    biblio_id: "123",
                    patron_id: "502",
                    item_id: ITEMTYPE_ITEMS[1].item_id,
                    pickup_library_id: "1",
                    start_date: today
                        .add(13, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(20, "day").endOf("day").toISOString(),
                    status: "pending",
                },

                // TABLET003: Available days 5-17, then booked 18-25, then available 26+
                {
                    booking_id: "3003",
                    biblio_id: "123",
                    patron_id: "503",
                    item_id: ITEMTYPE_ITEMS[2].item_id,
                    pickup_library_id: "1",
                    start_date: today
                        .add(18, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(25, "day").endOf("day").toISOString(),
                    status: "pending",
                },

                // TABLET004: Booked early 1-7, then available 8-22, then booked 23-30
                {
                    booking_id: "3004",
                    biblio_id: "123",
                    patron_id: "504",
                    item_id: ITEMTYPE_ITEMS[3].item_id,
                    pickup_library_id: "1",
                    start_date: today
                        .add(1, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(7, "day").endOf("day").toISOString(),
                    status: "pending",
                },
                {
                    booking_id: "3005",
                    biblio_id: "123",
                    patron_id: "505",
                    item_id: ITEMTYPE_ITEMS[3].item_id,
                    pickup_library_id: "1",
                    start_date: today
                        .add(23, "day")
                        .startOf("day")
                        .toISOString(),
                    end_date: today.add(30, "day").endOf("day").toISOString(),
                    status: "pending",
                },
            ];

            const allBookings = [...bookings, ...strategicBookings];

            cy.intercept("GET", "/api/v1/bookings?biblio_id=*&_per_page=-1*", {
                body: allBookings,
            }).as("getBookings");

            cy.intercept("GET", "/api/v1/biblios/*/items?bookable=1*", {
                body: ITEMTYPE_ITEMS.map(item => ({
                    item_id: item.item_id,
                    external_id: item.barcode,
                    effective_item_type_id: TEST_ITEMTYPE,
                    item_type: {
                        item_type_id: TEST_ITEMTYPE,
                        description: TEST_ITEMTYPE_DESCRIPTION,
                    },
                    location: "Main Library",
                    callnumber: "TEST.CALL.NUMBER",
                    status: "Available",
                })),
            }).as("getBookableItems");
        });

        cy.fixture("bookings/pickup_locations.json").then(locations => {
            const modifiedLocations = locations.map(location => {
                return {
                    ...location,
                    pickup_items: [
                        ...(location.pickup_items || []),
                        ...ITEMTYPE_ITEMS.map(item =>
                            parseInt(item.item_id, 10)
                        ),
                    ],
                };
            });

            cy.intercept("GET", "/api/v1/biblios/*/pickup_locations*", {
                body: modifiedLocations,
            }).as("getPickupLocations");
        });

        // Open booking modal and select itemtype
        cy.get("#placebooking").click();
        cy.wait(["@getBookableItems", "@getBookings", "@getCheckouts"]);
        setupModalForDateTesting();

        // Ensure "Any item" (value 0) is selected
        //cy.selectFromSelect2("#booking_item_id", "Any item");
        cy.selectFromSelect2ByIndex("#booking_item_id", 0);

        // Select an itemtype that has existing bookings
        cy.selectFromSelect2("#booking_itemtype", TEST_ITEMTYPE_DESCRIPTION);

        cy.get("#period").as("flatpickrInput");

        // Test Scenario 1: Start date Day 5 - Maximize window through item reduction
        cy.log(
            "=== Testing Start Date Day 5 (Maximize through item pool reduction) ==="
        );

        cy.get("@flatpickrInput").openFlatpickr();

        const startDate1 = today.add(5, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(startDate1.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(startDate1.toDate()).click();

        /* Expected availability progression from day 5:
         * Days 5-9:   Items available: TABLET001, TABLET002, TABLET003 (TABLET004 still booked until day 7)
         * Days 8-9:   Items available: TABLET001, TABLET002, TABLET003, TABLET004 (TABLET004 becomes available)
         * Days 10-12: Items available: TABLET002, TABLET003, TABLET004 (TABLET001 becomes unavailable)
         * Days 13-17: Items available: TABLET003, TABLET004 (TABLET002 becomes unavailable)
         * Days 18-22: Items available: TABLET004 only (TABLET003 becomes unavailable)
         * Days 23+:   No items available (TABLET004 becomes unavailable)
         *
         * So we should be able to book until day 22!
         */

        cy.log(
            "Checking maximized end date availability through item reduction"
        );

        // Days 6-9 should be available (3-4 items available)
        for (let day = 6; day <= 9; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled")
                .should("be.visible");
        }

        // Days 10-12 should still be available (3 items: TABLET002, TABLET003, TABLET004)
        for (let day = 10; day <= 12; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        // Days 13-17 should still be available (2 items: TABLET003, TABLET004)
        for (let day = 13; day <= 17; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        // Days 18-22 should still be available (1 item: TABLET004 only)
        for (let day = 18; day <= 22; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        // Days 23+ should be disabled (no items available)
        for (let day = 23; day <= 25; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("have.class", "flatpickr-disabled");
        }

        // Test Scenario 2: Start date Day 8 - All items available, maximum window
        cy.log(
            "=== Testing Start Date Day 8 (All items available initially) ==="
        );

        cy.get("@flatpickrInput").clear();
        cy.get("@flatpickrInput").openFlatpickr();

        const startDate2 = today.add(8, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(startDate2.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(startDate2.toDate()).click();

        /* Expected availability progression from day 8:
         * Days 8-9:   Items available: ALL 4 items
         * Days 10-12: Items available: TABLET002, TABLET003, TABLET004 (lose TABLET001)
         * Days 13-17: Items available: TABLET003, TABLET004 (lose TABLET002)
         * Days 18-22: Items available: TABLET004 only (lose TABLET003)
         * Days 23+:   No items available
         *
         * Maximum window should extend to day 22
         */

        cy.log("Checking maximum window from optimal start date");

        // Should be able to book all the way to day 22
        for (let day = 9; day <= 22; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        // Days 23+ should be disabled
        for (let day = 23; day <= 25; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("have.class", "flatpickr-disabled");
        }

        // Test Scenario 3: Start date Day 14 - Reduced initial pool, still maximize
        cy.log(
            "=== Testing Start Date Day 14 (Reduced pool but maximize window) ==="
        );

        cy.get("@flatpickrInput").clear();
        cy.get("@flatpickrInput").openFlatpickr();

        const startDate3 = today.add(14, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(startDate3.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(startDate3.toDate()).click();

        /* Expected availability progression from day 14:
         * Days 14-17: Items available: TABLET003, TABLET004 (TABLET001 & TABLET002 booked)
         * Days 18-22: Items available: TABLET004 only (TABLET003 becomes unavailable)
         * Days 23+:   No items available
         *
         * Should still extend to day 22 by using TABLET004
         */

        cy.log("Checking window maximization with reduced initial pool");

        // Days 15-22 should all be available
        for (let day = 15; day <= 22; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        // Days 23+ should be disabled
        for (let day = 23; day <= 25; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("have.class", "flatpickr-disabled");
        }

        // Test Scenario 4: Start date Day 19 - Single item window
        cy.log("=== Testing Start Date Day 19 (Single item available) ===");

        cy.get("@flatpickrInput").clear();
        cy.get("@flatpickrInput").openFlatpickr();

        const startDate4 = today.add(19, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(startDate4.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(startDate4.toDate()).click();

        /* Expected availability from day 19:
         * Days 19-22: Items available: TABLET004 only
         * Days 23+:   No items available
         */

        cy.log("Checking single-item window maximization");

        // Days 20-22 should be available (TABLET004 only)
        for (let day = 20; day <= 22; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("not.have.class", "flatpickr-disabled");
        }

        // Day 23+ should be disabled
        for (let day = 23; day <= 25; day++) {
            const endDate = today.add(day, "day");
            cy.get("@flatpickrInput").navigateToFlatpickrMonth(
                endDate.toDate()
            );
            cy.get("@flatpickrInput")
                .getFlatpickrDay(endDate.toDate())
                .should("have.class", "flatpickr-disabled");
        }

        // Test Scenario 5: Test item selection hints/preferences for optimal assignment
        cy.log("=== Testing optimal item assignment hints ===");

        // Go back to day 8 start for comprehensive testing
        cy.get("@flatpickrInput").clear();
        cy.get("@flatpickrInput").openFlatpickr();

        cy.get("@flatpickrInput").navigateToFlatpickrMonth(startDate2.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(startDate2.toDate()).click();

        // Select end date day 12 (where TABLET002, TABLET003, TABLET004 are available)
        const endDate5 = today.add(12, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(endDate5.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(endDate5.toDate()).click();

        // The system should prefer TABLET004 for assignment because:
        // - It has the longest availability window (until day 22)
        // - Choosing it leaves TABLET002 & TABLET003 available for other bookings
        // - This maximizes future booking opportunities

        // Check that the form indicates the optimal item choice (if your UI shows this)
        // This would be implementation-specific, but could be something like:
        // cy.get("#suggested_item").should("contain", "TABLET004");
        // or a hidden field that gets populated:
        // cy.get("#optimal_item_id").should("have.value", ITEMTYPE_ITEMS[3].item_id);

        cy.log("=== Verifying cross-scenario consistency ===");

        // Test that changing start date properly recalculates maximum windows
        cy.get("@flatpickrInput").clear();
        cy.get("@flatpickrInput").openFlatpickr();

        // Go to day 16 where only TABLET003 and TABLET004 are available initially
        const startDate6 = today.add(16, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(startDate6.toDate());
        cy.get("@flatpickrInput").getFlatpickrDay(startDate6.toDate()).click();

        // Should still be able to book until day 22 via TABLET004
        const endDate6 = today.add(22, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(endDate6.toDate());
        cy.get("@flatpickrInput")
            .getFlatpickrDay(endDate6.toDate())
            .should("not.have.class", "flatpickr-disabled");

        // But day 23 should be disabled
        const endDate6_blocked = today.add(23, "day");
        cy.get("@flatpickrInput").navigateToFlatpickrMonth(
            endDate6_blocked.toDate()
        );
        cy.get("@flatpickrInput")
            .getFlatpickrDay(endDate6_blocked.toDate())
            .should("have.class", "flatpickr-disabled");

        cy.log(
            "Dynamic item pool reduction and window maximization test completed"
        );
    });
    it("should handle lead and trail period hover highlighting", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Open the flatpickr
        cy.openFlatpickr("#period");

        // Get a future date to hover over
        let hoverDate = dayjs();
        hoverDate = hoverDate.add(5, "day");

        // Hover over a date and check for lead/trail highlighting
        cy.get(".flatpickr-calendar").within(() => {
            getDayElement(hoverDate.toDate()).trigger("mouseover");
            cy.wait(100);

            // Check for lead range classes (assuming 2-day lead period from circulation rules)
            cy.get(".leadRange, .leadRangeStart, .leadRangeEnd").should(
                "exist"
            );

            // Check for trail range classes (assuming 2-day trail period)
            cy.get(".trailRange, .trailRangeStart, .trailRangeEnd").should(
                "exist"
            );
        });
    });

    it("should disable click when lead/trail periods overlap with disabled dates", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Open the flatpickr
        cy.openFlatpickr("#period");

        // Find a date that would have overlapping lead/trail with disabled dates
        const today = dayjs();
        const problematicDate = today.add(7, "day"); // Just before a booked period

        cy.get(".flatpickr-calendar").within(() => {
            getDayElement(problematicDate.toDate())
                .trigger("mouseover")
                .should($el => {
                    expect(
                        $el.hasClass("leadDisable") ||
                            $el.hasClass("trailDisable"),
                        "element has either leadDisable or trailDisable"
                    ).to.be.true;
                });
        });
    });

    it("should show event dots for dates with existing bookings", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Open the flatpickr
        cy.openFlatpickr("#period");

        // Check for event dots on dates with bookings
        cy.get(".flatpickr-calendar").within(() => {
            cy.get(".event-dots").should("exist");
            cy.get(".event-dots .event").should("exist");
        });
    });

    it("should show only the correct bold dates for issue and renewal periods", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        cy.get("#period").as("flatpickrInput");

        const startDate = dayjs().add(3, "day").startOf("day");
        cy.get("@flatpickrInput").selectFlatpickrDate(startDate.toDate());

        const expectedBoldDates = [
            startDate.add(14, "day"),
            startDate.add(21, "day"),
            startDate.add(28, "day"),
        ];

        cy.get(".flatpickr-calendar").within(() => {
            // Confirm each expected bold date is bold
            expectedBoldDates.forEach(boldDate => {
                getDayElement(boldDate.toDate()).should("have.class", "title");
            });

            // Confirm that only expected dates are bold
            cy.get(".flatpickr-day.title").each($el => {
                const ariaLabel = $el.attr("aria-label");
                const date = dayjs(ariaLabel, "MMMM D, YYYY");
                const isExpected = expectedBoldDates.some(expected =>
                    date.isSame(expected, "day")
                );
                expect(isExpected, `Unexpected bold date: ${ariaLabel}`).to.be
                    .true;
            });
        });
    });

    it("should set correct max date based on circulation rules", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        cy.get("#period").as("flatpickrInput");

        // Select a start date
        const startDate = new Date();
        startDate.setDate(startDate.getDate() + 3);

        cy.get("@flatpickrInput").selectFlatpickrDate(startDate.toDate());

        // Check that dates beyond the maximum allowed period are disabled
        cy.get(".flatpickr-calendar").within(() => {
            // Assuming circulation rules allow 14 days + renewals
            const maxDate = new Date(startDate);
            maxDate.setDate(maxDate.getDate() + 30); // Beyond reasonable limit

            // Navigate to future months if needed and check disabled state
            cy.get(".flatpickr-next-month").click();
            cy.get(".flatpickr-day.flatpickr-disabled").should("exist");
        });
    });

    it("should handle visible and hidden fields on date selection", () => {
        // Open the booking modal
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        cy.get("#period").as("flatpickrInput");

        // Get today's date
        const startDate = new Date();
        startDate.setDate(startDate.getDate() + 3);

        // Get end date (5 days from now)
        const endDate = new Date(startDate);
        endDate.setDate(startDate.getDate() + 4);

        cy.get("@flatpickrInput").selectFlatpickrDateRange(startDate, endDate);

        // Use should with retry capability instead of a simple assertion
        const format = date => date.toISOString().split("T")[0];
        cy.get("#period").should(
            "have.value",
            `${format(startDate)} to ${format(endDate)}`
        );

        // Verify the flatpickr visible input also has value
        cy.getFlatpickr("#period").should(
            "have.value",
            `${format(startDate)} to ${format(endDate)}`
        );
        // Now check the hidden fields
        cy.get("#booking_start_date").should(
            "have.value",
            dayjs(startDate).startOf("day").toISOString()
        );
        cy.get("#booking_end_date").should(
            "have.value",
            dayjs(endDate).endOf("day").toISOString()
        );
    });

    it("should submit a new booking successfully", () => {
        // Open the booking modal
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Set dates with flatpickr
        cy.window().then(win => {
            const picker = win.document.getElementById("period")._flatpickr;
            const startDate = new Date(testData.startDate);
            const endDate = new Date(testData.endDate);
            picker.setDate([startDate, endDate], true);
        });

        // Submit the form
        cy.get("#placeBookingForm").submit();
        cy.wait("@createBooking");

        // Check success message
        cy.get("#transient_result").should(
            "contain",
            "Booking successfully placed"
        );

        // Check modal closes
        cy.get("#placeBookingModal").should("not.be.visible");
    });

    it("should edit an existing booking successfully", () => {
        // Open edit booking modal
        cy.get("#placebooking")
            .invoke("attr", "data-booking", "1001")
            .invoke("attr", "data-patron", "456")
            .invoke("attr", "data-itemnumber", "789")
            .invoke("attr", "data-pickup_library", "1")
            .invoke("attr", "data-start_date", "2025-05-01T00:00:00.000Z")
            .invoke("attr", "data-end_date", "2025-05-05T23:59:59.999Z")
            .click();
        cy.wait(300);

        // Check modal title for edit
        cy.get("#placeBookingLabel").should("contain", "Edit booking");

        // Verify booking ID is set
        cy.get("#booking_id").should("have.value", "1001");

        // Verify patron ID is set
        cy.get("#booking_patron_id").should("have.value", "456");

        // Verify itemnumber is set
        cy.get("#booking_item_id").should("have.value", "789");

        // Verify pickup_library is set
        cy.get("#booking_library_id").should("have.value", "1");

        // Verify item_type is set
        cy.get("#booking_itemtype").should("have.value", "BK");

        // Change pickup location
        cy.get("#pickup_library_id").select("2");

        // Submit the form
        cy.get("#placeBookingForm").submit();
        cy.wait("@updateBooking");

        // Check success message
        cy.get("#transient_result").should(
            "contain",
            "Booking successfully updated"
        );

        // Check modal closes
        cy.get("#placeBookingModal").should("not.be.visible");
    });

    it("should handle booking failure gracefully", () => {
        // Override the create booking intercept to return an error
        cy.intercept("POST", "/api/v1/bookings", {
            statusCode: 400,
            body: {
                error: "Booking failed",
            },
        }).as("failedBooking");

        // Open the booking modal
        cy.get("#placebooking").click();

        // Fill out the booking form
        cy.selectFromSelect2ByIndex("#booking_patron_id", 0, "John");
        cy.wait("@getPickupLocations");
        cy.selectFromSelect2ByIndex("#pickup_library_id", 0);
        cy.selectFromSelect2ByIndex("#booking_item_id", 1);
        cy.wait("@getCirculationRules");

        // Set dates with flatpickr
        cy.window().then(win => {
            const picker = win.document.getElementById("period")._flatpickr;
            const startDate = new Date(testData.startDate);
            const endDate = new Date(testData.endDate);
            picker.setDate([startDate, endDate], true);
        });

        // Submit the form
        cy.get("#placeBookingForm").submit();
        cy.wait("@failedBooking");

        // Check error message
        cy.get("#booking_result").should("contain", "Failure");

        // Modal should remain open
        cy.get("#placeBookingModal").should("be.visible");
    });

    it("should reset form when modal is closed", () => {
        // Open the booking modal
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Close the modal
        cy.get('#placeBookingModal button[data-bs-dismiss="modal"]')
            .first()
            .click();

        // Re-open the modal
        cy.get("#placebooking").click();

        // Check fields are reset
        cy.get("#booking_patron_id").should("have.value", null);
        cy.get("#pickup_library_id").should("be.disabled");
        cy.get("#booking_itemtype").should("be.disabled");
        cy.get("#booking_item_id").should("be.disabled");
        cy.get("#period").should("be.disabled");
        cy.get("#booking_start_date").should("have.value", "");
        cy.get("#booking_end_date").should("have.value", "");
        cy.get("#booking_id").should("have.value", "");
    });

    // Helper function to setup modal for date testing
    function setupModalForDateTesting() {
        // Select patron, pickup location and item
        cy.selectFromSelect2ByIndex("#booking_patron_id", 0, "John");
        cy.wait("@getPickupLocations");
        cy.selectFromSelect2ByIndex("#pickup_library_id", 0);
        cy.selectFromSelect2ByIndex("#booking_item_id", 1);
        cy.wait("@getCirculationRules");
        // Wait for flatpickr to be enabled
        cy.get("#period").should("not.be.disabled");
    }

    // Helper function to find the day element for a given date
    function getDayElement(targetDate) {
        const targetYear = targetDate.getFullYear();
        const targetMonth = targetDate.getMonth();
        const targetDay = targetDate.getDate();

        const monthNames = [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
        ];

        // Format the aria-label for the target date
        const formattedDateLabel = `${monthNames[targetMonth]} ${targetDay}, ${targetYear}`;

        // Select the day using aria-label
        return cy.get(`.flatpickr-day[aria-label="${formattedDateLabel}"]`);
    }
});
