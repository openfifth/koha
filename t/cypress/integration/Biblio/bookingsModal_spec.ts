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
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        const today = dayjs();

        // Open the flatpickr
        cy.openFlatpickr("#period");

        cy.get(".flatpickr-calendar").within(() => {
            // Find the first visible date in the calendar to determine range
            cy.get(".flatpickr-day")
                .first()
                .then($firstDay => {
                    const firstDate = dayjs($firstDay.attr("aria-label"));

                    // Check all dates from first visible date up to today are disabled
                    for (
                        let checkDate = firstDate;
                        checkDate.isSameOrBefore(today);
                        checkDate = checkDate.add(1, "day")
                    ) {
                        getDayElement(checkDate.toDate()).should(
                            "have.class",
                            "flatpickr-disabled"
                        );
                    }

                    // Check dates after today are enabled (until we make a selection)
                    for (
                        let checkDate = today.add(1, "day");
                        checkDate.isSameOrBefore(today.add(5, "day"));
                        checkDate = checkDate.add(1, "day")
                    ) {
                        getDayElement(checkDate.toDate()).should(
                            "not.have.class",
                            "flatpickr-disabled"
                        );
                    }
                });
        });

        // Select a start date (3 days from today)
        const startDate = today.add(3, "day");
        cy.selectFlatpickrDate("#period", startDate.toDate());

        // Verify dates between today and start date are disabled
        cy.get(".flatpickr-calendar").within(() => {
            for (
                let checkDate = today.add(1, "day");
                checkDate.isBefore(startDate);
                checkDate = checkDate.add(1, "day")
            ) {
                getDayElement(checkDate.toDate()).should(
                    "have.class",
                    "flatpickr-disabled"
                );
            }

            // Verify the selected start date itself is not disabled
            getDayElement(startDate.toDate()).should(
                "not.have.class",
                "flatpickr-disabled"
            );
            getDayElement(startDate.toDate()).should("have.class", "selected");
        });
    });

    it("should disable dates with existing bookings for same item", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Select an item that has existing bookings
        cy.selectFromSelect2ByIndex("#booking_item_id", 1);

        // Open the flatpickr
        cy.openFlatpickr("#period");

        // Check that dates with existing bookings are disabled
        cy.get(".flatpickr-calendar").within(() => {
            const today = dayjs();
            const bookedStart = today.add(8, "day");
            const bookedEnd = today.add(13, "day");

            // Check date before booked range is not disabled
            const beforeStart = bookedStart.subtract(1, "day");
            getDayElement(beforeStart.toDate()).should(
                "not.have.class",
                "flatpickr-disabled"
            );

            // Check dates within the booked range are disabled
            for (let i = 0; i <= bookedEnd.diff(bookedStart, "day"); i++) {
                const checkDate = bookedStart.add(i, "day");
                getDayElement(checkDate.toDate()).should(
                    "have.class",
                    "flatpickr-disabled"
                );
            }

            // Check date after booked range is not disabled
            const afterEnd = bookedEnd.add(1, "day");
            getDayElement(afterEnd.toDate()).should(
                "not.have.class",
                "flatpickr-disabled"
            );
        });
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

        // Open the flatpickr
        cy.openFlatpickr("#period");

        const startDate = dayjs().add(3, "day").startOf("day");
        cy.selectFlatpickrDate("#period", startDate.toDate());

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

        // Select a start date
        const startDate = new Date();
        startDate.setDate(startDate.getDate() + 3);

        cy.selectFlatpickrDate("#period", startDate);

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

    it("should handle biblio-level vs item-level booking conflicts", () => {
        // Open the booking modal and setup initial selections
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Test selecting "Any item" (value 0) vs specific item
        cy.selectFromSelect2ByValue("#booking_item_id", "0");

        // Select dates that would conflict with existing bookings
        const startDate = new Date();
        startDate.setDate(startDate.getDate() + 8);
        const endDate = new Date(startDate);
        endDate.setDate(startDate.getDate() + 3);

        cy.selectFlatpickrDateRange("#period", startDate, endDate);

        // Check availability calculation for biblio-level booking
        cy.get(".flatpickr-calendar").within(() => {
            // Some dates should be disabled due to all items being booked
            cy.get(".flatpickr-day.flatpickr-disabled").should("exist");
        });
    });

    it("should handle date selection and availability", () => {
        // Open the booking modal
        cy.get("#placebooking").click();
        setupModalForDateTesting();

        // Get today's date
        const startDate = new Date();
        startDate.setDate(startDate.getDate() + 3);

        // Get end date (5 days from now)
        const endDate = new Date(startDate);
        endDate.setDate(startDate.getDate() + 4);

        cy.selectFlatpickrDateRange("#period", startDate, endDate);

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
