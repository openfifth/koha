// flatpickrHelpers.js - Reusable Cypress functions for Flatpickr date pickers

/**
 * Helper functions for interacting with Flatpickr date picker components in Cypress tests
 * Uses click-driven interactions instead of Flatpickr's JavaScript API
 * Supports all standard Flatpickr operations including date selection, range selection,
 * navigation, and direct input with full chainability
 *
 * CHAINABILITY:
 * All Flatpickr helper commands are fully chainable. You can:
 * - Chain multiple Flatpickr operations (open, navigate, select)
 * - Chain Flatpickr commands with standard Cypress commands
 * - Split complex interactions into multiple steps for better reliability
 *
 * Examples:
 *   cy.getFlatpickr('#myDatepicker')
 *     .flatpickr({ open: true })
 *     .flatpickr({ selectDate: '2023-05-15' });
 *
 *   cy.getFlatpickr('#rangePicker')
 *     .flatpickr({ open: true })
 *     .flatpickr({ selectRange: ['2023-06-01', '2023-06-15'] })
 *     .should('have.value', '2023-06-01 to 2023-06-15');
 */

/**
 * Main Flatpickr interaction command to perform operations on Flatpickr date pickers
 * @param {string|JQuery} [subject] - Optional jQuery element (when used with .flatpickr())
 * @param {Object} options - Configuration options for the Flatpickr operation
 * @param {boolean} [options.open=false] - Whether to open the Flatpickr calendar
 * @param {boolean} [options.close=false] - Whether to close the Flatpickr calendar
 * @param {boolean} [options.clear=false] - Whether to clear the current selection
 * @param {string|Date} [options.selectDate] - Date to select (YYYY-MM-DD string or Date object)
 * @param {Array} [options.selectRange] - Array with start and end dates for range selection
 * @param {string} [options.typeDate] - Date string to type directly into the input
 * @param {string|Date} [options.navigateToMonth] - Navigate to specified month/year
 * @param {number} [options.selectDay] - Day of month to select from current month view
 * @param {boolean} [options.nextMonth=false] - Whether to navigate to next month
 * @param {boolean} [options.prevMonth=false] - Whether to navigate to previous month
 * @param {number} [options.setYear] - Year to set in the calendar
 * @param {boolean} [options.selectToday=false] - Whether to select today's date
 * @param {string} [options.selector] - CSS selector to find the element (when not using subject)
 * @param {number} [options.timeout=10000] - Timeout for operations in milliseconds
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Basic usage
 * cy.get('#myDatepicker').flatpickr({ selectDate: '2023-05-15' });
 *
 * @example
 * // Chained operations (more reliable for complex interactions)
 * cy.getFlatpickr('#myDatepicker')
 *   .flatpickr({ open: true })
 *   .flatpickr({ navigateToMonth: '2023-06-01' })
 *   .flatpickr({ selectDay: 15 });
 *
 * @example
 * // Date range selection
 * cy.getFlatpickr('#rangePicker').flatpickr({
 *   selectRange: ['2023-06-01', '2023-06-15']
 * });
 */
Cypress.Commands.add(
    "flatpickr",
    {
        prevSubject: "optional",
    },
    (subject, options) => {
        // Default configuration
        const defaults = {
            open: false, // Whether to open the Flatpickr calendar
            close: false, // Whether to close the Flatpickr calendar
            clear: false, // Whether to clear the current selection
            selectDate: null, // Date to select (YYYY-MM-DD string or Date object)
            selectRange: null, // Array with start and end dates for range selection
            typeDate: null, // Date string to type directly into the input
            navigateToMonth: null, // Navigate to specified month/year
            selectDay: null, // Day of month to select from current month view
            nextMonth: false, // Whether to navigate to next month
            prevMonth: false, // Whether to navigate to previous month
            setYear: null, // Year to set in the calendar
            selectToday: false, // Whether to select today's date
            selector: null, // CSS selector to find the element (when not using subject)
            timeout: 10000, // Timeout for operations in milliseconds
        };

        // Merge passed options with defaults
        const config = { ...defaults, ...options };

        // Handle selecting the target Flatpickr element
        let $originalInput;
        if (subject) {
            $originalInput = subject;
            // Store the element ID as a data attribute for chaining
            cy.wrap(subject).then($el => {
                const inputId = $el.attr("id");
                if (inputId) {
                    Cypress.$($el).attr("data-flatpickr-helper-id", inputId);
                }
            });
        } else if (config.selector) {
            $originalInput = cy.get(config.selector);
        } else {
            throw new Error(
                "Either provide a subject or a selector to identify the Flatpickr element"
            );
        }

        return cy.wrap($originalInput).then($el => {
            // Try to get the ID either from the element or from the stored data attribute
            const inputId = $el.attr("id") || $el.data("flatpickr-helper-id");
            const originalInputSelector = inputId ? `#${inputId}` : null;

            // Get the visible flatpickr input element
            const getVisibleInput = () => {
                if (originalInputSelector) {
                    return cy
                        .get(originalInputSelector)
                        .parents()
                        .find(".flatpickr_wrapper input.flatpickr-input");
                } else {
                    return cy
                        .wrap($el)
                        .parents()
                        .find(".flatpickr_wrapper input.flatpickr-input");
                }
            };

            // Open the Flatpickr calendar if requested
            if (config.open) {
                cy.get(".flatpickr-calendar").then($calendar => {
                    const isVisible =
                        $calendar.hasClass("open") && $calendar.is(":visible");

                    if (!isVisible) {
                        getVisibleInput().click();
                    }

                    // Always wait for the calendar to be visible — retry if necessary
                    cy.get(".flatpickr-calendar.open", {
                        timeout: config.timeout,
                    }).should("be.visible");
                });
            }

            // Close the Flatpickr calendar if requested
            if (config.close) {
                cy.get("body").click(0, 0);
                cy.get(".flatpickr-calendar.open").should("not.exist", {
                    timeout: config.timeout,
                });
            }

            // Clear the Flatpickr input if requested
            if (config.clear) {
                cy.wrap($el).parents().find(".clear_date").click();
                cy.wrap($el).should("have.value", "");
                getVisibleInput().should("have.value", "");
            }

            // Navigate to a specific month/year if requested
            if (config.navigateToMonth !== null) {
                // Ensure calendar is open
                if (!config.open) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                // Convert to Date object if string was provided
                const dateObj =
                    typeof config.navigateToMonth === "string"
                        ? new Date(config.navigateToMonth)
                        : config.navigateToMonth;

                const targetYear = dateObj.getFullYear();
                const targetMonth = dateObj.getMonth(); // 0-based index

                // Click-based navigation to the correct month and year
                cy.get(".flatpickr-current-month").then($currentMonth => {
                    cy.log("Inside currentMonth");
                    cy.get(".flatpickr-current-month .numInput.cur-year").then(
                        $currentYear => {
                            // Parse the current month and year from the calendar display
                            const currentMonthName = $currentMonth
                                .text()
                                .trim();
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
                            const currentMonth = monthNames.findIndex(name =>
                                currentMonthName.includes(name)
                            );
                            const currentYear = parseInt($currentYear.val());

                            // Calculate the number of months to move forward or backward
                            const monthDiff =
                                (targetYear - currentYear) * 12 +
                                (targetMonth - currentMonth);

                            if (monthDiff > 0) {
                                // Click next month button the appropriate number of times
                                for (let i = 0; i < monthDiff; i++) {
                                    cy.get(".flatpickr-next-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            } else if (monthDiff < 0) {
                                // Click previous month button the appropriate number of times
                                for (let i = 0; i < Math.abs(monthDiff); i++) {
                                    cy.get(".flatpickr-prev-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            }
                        }
                    );
                });
            }

            // Move to next month if requested
            if (config.nextMonth) {
                // Ensure calendar is open
                if (!config.open && !config.navigateToMonth) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                cy.get(".flatpickr-next-month").click();
                cy.wait(100); // Give time for the calendar to update
            }

            // Move to previous month if requested
            if (config.prevMonth) {
                // Ensure calendar is open
                if (
                    !config.open &&
                    !config.navigateToMonth &&
                    !config.nextMonth
                ) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                cy.get(".flatpickr-prev-month").click();
                cy.wait(100); // Give time for the calendar to update
            }

            // Set year if requested - using click interactions on year input
            if (config.setYear !== null) {
                // Ensure calendar is open
                if (
                    !config.open &&
                    !config.navigateToMonth &&
                    !config.nextMonth &&
                    !config.prevMonth
                ) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                const yearNum = parseInt(config.setYear, 10);

                // Click on the year input to focus it
                cy.get(".flatpickr-current-month .numInput.cur-year").click();

                // Clear the current year and type the new year
                cy.get(".flatpickr-current-month .numInput.cur-year")
                    .clear()
                    .type(yearNum.toString(), { force: true })
                    .type("{enter}");

                cy.wait(100); // Give time for the calendar to update
            }

            // Select a specific day from the current month view if requested
            if (config.selectDay !== null) {
                // Ensure calendar is open
                if (
                    !config.open &&
                    !config.navigateToMonth &&
                    !config.nextMonth &&
                    !config.prevMonth &&
                    !config.setYear
                ) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                const dayNum = parseInt(config.selectDay, 10);

                // Get current month and year from the calendar display
                cy.get(".flatpickr-current-month").then($currentMonth => {
                    cy.get(".flatpickr-current-month .numInput.cur-year").then(
                        $currentYear => {
                            const currentMonthName = $currentMonth
                                .text()
                                .trim();
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
                            const currentMonth = monthNames.findIndex(name =>
                                currentMonthName.includes(name)
                            );
                            const currentYear = parseInt($currentYear.val());

                            // Format the aria-label for the target day
                            const formattedDayLabel = `${monthNames[currentMonth]} ${dayNum}, ${currentYear}`;

                            // Select the day using aria-label
                            cy.get(
                                `.flatpickr-day[aria-label="${formattedDayLabel}"]`
                            ).click();
                        }
                    );
                });

                // Verify the selection was made
                cy.wrap($el).should("not.have.value", "");
            }

            // Select today's date if requested
            if (config.selectToday) {
                // Ensure calendar is open
                if (
                    !config.open &&
                    !config.navigateToMonth &&
                    !config.nextMonth &&
                    !config.prevMonth &&
                    !config.setYear &&
                    !config.selectDay
                ) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                cy.get(".flatpickr-day.today").click();

                // Verify the selection was made
                cy.wrap($el).should("not.have.value", "");
            }

            // Select a specific date if requested
            if (config.selectDate !== null) {
                // Ensure calendar is open
                if (
                    !config.open &&
                    !config.navigateToMonth &&
                    !config.nextMonth &&
                    !config.prevMonth &&
                    !config.setYear &&
                    !config.selectDay &&
                    !config.selectToday
                ) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                // Convert to Date object if string was provided
                const dateObj =
                    typeof config.selectDate === "string"
                        ? new Date(config.selectDate)
                        : config.selectDate;

                const targetYear = dateObj.getFullYear();
                const targetMonth = dateObj.getMonth(); // 0-based index
                const targetDay = dateObj.getDate();

                // Click-based navigation to the correct month and year
                cy.get(".flatpickr-current-month").then($currentMonth => {
                    cy.get(".flatpickr-current-month .numInput.cur-year").then(
                        $currentYear => {
                            // Parse the current month and year from the calendar display
                            const currentMonthName = $currentMonth
                                .text()
                                .trim();
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
                            const currentMonth = monthNames.findIndex(name =>
                                currentMonthName.includes(name)
                            );
                            const currentYear = parseInt($currentYear.val());

                            // Calculate the number of months to move forward or backward
                            const monthDiff =
                                (targetYear - currentYear) * 12 +
                                (targetMonth - currentMonth);

                            if (monthDiff > 0) {
                                // Click next month button the appropriate number of times
                                for (let i = 0; i < monthDiff; i++) {
                                    cy.get(".flatpickr-next-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            } else if (monthDiff < 0) {
                                // Click previous month button the appropriate number of times
                                for (let i = 0; i < Math.abs(monthDiff); i++) {
                                    cy.get(".flatpickr-prev-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            }

                            // Format the aria-label for the target date
                            const formattedDateLabel = `${monthNames[targetMonth]} ${targetDay}, ${targetYear}`;

                            // Select the day using aria-label
                            cy.get(
                                `.flatpickr-day[aria-label="${formattedDateLabel}"]`
                            ).click();
                        }
                    );
                });

                // Verify the selection was made
                cy.wait(200);
                const formattedDate = `${targetYear}-${(targetMonth + 1).toString().padStart(2, "0")}-${targetDay.toString().padStart(2, "0")}`;
                cy.wrap($el).should("have.value", formattedDate);
            }

            // Select a date range if requested
            if (config.selectRange !== null) {
                // Ensure calendar is open
                if (
                    !config.open &&
                    !config.navigateToMonth &&
                    !config.nextMonth &&
                    !config.prevMonth &&
                    !config.setYear &&
                    !config.selectDay &&
                    !config.selectToday &&
                    !config.selectDate
                ) {
                    cy.get(".flatpickr-calendar").then($calendar => {
                        const isVisible =
                            $calendar.hasClass("open") &&
                            $calendar.is(":visible");

                        if (!isVisible) {
                            getVisibleInput().click();
                        }

                        // Always wait for the calendar to be visible — retry if necessary
                        cy.get(".flatpickr-calendar.open", {
                            timeout: config.timeout,
                        }).should("be.visible");
                    });
                }

                if (
                    !Array.isArray(config.selectRange) ||
                    config.selectRange.length !== 2
                ) {
                    throw new Error(
                        "selectRange must be an array with exactly two dates"
                    );
                }

                // Convert to Date objects if strings were provided
                const startDateObj =
                    typeof config.selectRange[0] === "string"
                        ? new Date(config.selectRange[0])
                        : config.selectRange[0];

                const endDateObj =
                    typeof config.selectRange[1] === "string"
                        ? new Date(config.selectRange[1])
                        : config.selectRange[1];

                // Navigate to start date using click-based interactions
                const startYear = startDateObj.getFullYear();
                const startMonth = startDateObj.getMonth();
                const startDay = startDateObj.getDate();

                // Check if the flatpickr instance is in range mode
                // Get the flatpickr instance from the DOM element
                cy.window().then(win => {
                    // First ensure we have a valid element before proceeding
                    if (!$el || !$el.length) {
                        throw new Error("Cannot find flatpickr element");
                    }

                    // Try to get the flatpickr instance from the element
                    const fpInstance = $el[0]._flatpickr;

                    if (!fpInstance) {
                        throw new Error(
                            "Cannot find flatpickr instance on this element. Make sure it's initialized with flatpickr."
                        );
                    }

                    // Check if it's in range mode
                    if (
                        fpInstance.config &&
                        fpInstance.config.mode !== "range"
                    ) {
                        throw new Error(
                            "This flatpickr instance is not in range mode. Current mode: " +
                            fpInstance.config.mode
                        );
                    }

                    cy.log("Confirmed flatpickr is in range mode");
                });

                cy.get(
                    ".flatpickr-current-month .flatpickr-monthDropdown-months"
                ).then($dropdown => {
                    cy.get(".flatpickr-current-month .numInput.cur-year").then(
                        $currentYear => {
                            // Get the selected month value from the dropdown
                            const selectedOption = $dropdown
                                .find("option:selected")
                                .first();
                            const currentMonthName = selectedOption
                                .text()
                                .trim();

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
                            const currentMonth = monthNames.findIndex(name =>
                                currentMonthName.includes(name)
                            );
                            const currentYear = parseInt($currentYear.val());

                            // Calculate the number of months to move forward or backward
                            const monthDiff =
                                (startYear - currentYear) * 12 +
                                (startMonth - currentMonth);

                            if (monthDiff > 0) {
                                // Click next month button the appropriate number of times
                                for (let i = 0; i < monthDiff; i++) {
                                    cy.get(".flatpickr-next-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            } else if (monthDiff < 0) {
                                // Click previous month button the appropriate number of times
                                for (let i = 0; i < Math.abs(monthDiff); i++) {
                                    cy.get(".flatpickr-prev-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            }

                            // Format the aria-label for the start date
                            const formattedStartDateLabel = `${monthNames[startMonth]} ${startDay}, ${startYear}`;

                            // Select start date using aria-label - don't wait here
                            cy.get(
                                `.flatpickr-day[aria-label="${formattedStartDateLabel}"]`
                            ).click();
                            cy.wait(300);

                            // Verify calendar stays open for range selection
                            cy.get(".flatpickr-calendar.open").should(
                                "be.visible",
                                {
                                    timeout: config.timeout,
                                }
                            );
                        }
                    );
                });

                // Navigate to end date if in different month
                const endYear = endDateObj.getFullYear();
                const endMonth = endDateObj.getMonth();
                const endDay = endDateObj.getDate();

                cy.get(".flatpickr-calendar.open").should("be.visible");

                if (startMonth !== endMonth || startYear !== endYear) {
                    cy.get(
                        ".flatpickr-current-month .flatpickr-monthDropdown-months"
                    ).then($dropdown => {
                        cy.get(
                            ".flatpickr-current-month .numInput.cur-year"
                        ).then($currentYear => {
                            // Get the selected month value from the dropdown
                            const selectedOption = $dropdown
                                .find("option:selected")
                                .first();
                            const currentMonthName = selectedOption
                                .text()
                                .trim();

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
                            const currentMonth = monthNames.findIndex(name =>
                                currentMonthName.includes(name)
                            );
                            const currentYear = parseInt($currentYear.val());

                            // Calculate months to navigate
                            const monthDiff =
                                (endYear - currentYear) * 12 +
                                (endMonth - currentMonth);

                            if (monthDiff > 0) {
                                // Click next month button
                                for (let i = 0; i < monthDiff; i++) {
                                    cy.get(".flatpickr-next-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            } else if (monthDiff < 0) {
                                // Click previous month button
                                for (let i = 0; i < Math.abs(monthDiff); i++) {
                                    cy.get(".flatpickr-prev-month").click();
                                    cy.wait(100); // Give time for the calendar to update
                                }
                            }
                        });
                    });
                }

                // Select end date using aria-label
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
                const formattedEndDateLabel = `${monthNames[endMonth]} ${endDay}, ${endYear}`;

                // Ensure the calendar is still open before selecting the end date
                cy.get(".flatpickr-calendar.open").should("be.visible");

                cy.get(
                    `.flatpickr-day[aria-label="${formattedEndDateLabel}"]`
                ).click();

                // Add a small delay to ensure proper state before proceeding
                cy.wait(300);

                // Verify the selection was made
                cy.wrap($el).should("not.have.value", "");
            }

            // Type a date directly into the input if requested
            if (config.typeDate !== null) {
                getVisibleInput().clear().type(config.typeDate);

                // Click away to apply the date
                cy.get("body").click(0, 0);

                // Verify the input has been updated
                cy.wrap($el).should("not.have.value", "");
            }
        });
    }
);

/**
 * Helper to get a Flatpickr input by any jQuery-like selector
 * This is the recommended starting point for chainable Flatpickr operations
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Chain multiple Flatpickr operations
 * cy.getFlatpickr('#dateInput')
 *   .flatpickr({ open: true })
 *   .flatpickr({ navigateToMonth: '2023-06-01' })
 *   .flatpickr({ selectDay: 15 });
 *
 * @example
 * // Chain with standard Cypress assertions
 * cy.getFlatpickr('#startDate')
 *   .flatpickr({ selectDate: '2023-05-15' })
 *   .should('have.value', '2023-05-15');
 */
Cypress.Commands.add("getFlatpickr", selector => {
    return cy.get(selector);
});

/**
 * Helper to clear a Flatpickr selection
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.clearFlatpickr('#dateInput');
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#dateInput')
 *   .flatpickr({ selectDate: '2023-05-15' })
 *   .clearFlatpickr('#dateInput')
 *   .flatpickr({ selectDate: '2023-06-01' });
 */
Cypress.Commands.add("clearFlatpickr", selector => {
    return cy.getFlatpickr(selector).flatpickr({ clear: true });
});

/**
 * Helper to open a Flatpickr calendar
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.openFlatpickr('#dateInput');
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#dateInput')
 *   .openFlatpickr('#dateInput')
 *   .flatpickr({ selectDay: 15 });
 */
Cypress.Commands.add("openFlatpickr", selector => {
    return cy.getFlatpickr(selector).flatpickr({ open: true });
});

/**
 * Helper to close an open Flatpickr calendar
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} [selector] - Optional jQuery-like selector for the original input element
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.closeFlatpickr();
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#dateInput')
 *   .flatpickr({ open: true })
 *   .flatpickr({ close: true });
 */
Cypress.Commands.add("closeFlatpickr", selector => {
    if (selector) {
        return cy.getFlatpickr(selector).flatpickr({ close: true });
    } else {
        return cy.flatpickr({ close: true });
    }
});

/**
 * Helper to select a date in a Flatpickr
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @param {Date|string} date - The date to select (Date object or YYYY-MM-DD string)
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.selectFlatpickrDate('#dateInput', '2023-05-15');
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#dateInput')
 *   .selectFlatpickrDate('#dateInput', '2023-05-15')
 *   .should('have.value', '2023-05-15');
 */
Cypress.Commands.add("selectFlatpickrDate", (selector, date) => {
    return cy.getFlatpickr(selector).flatpickr({ selectDate: date });
});

/**
 * Helper to type a date directly into a Flatpickr input
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @param {string} dateString - The date string to type in the format expected by Flatpickr
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.typeFlatpickrDate('#dateInput', '2023-05-15');
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#dateInput')
 *   .typeFlatpickrDate('#dateInput', '2023-05-15')
 *   .should('have.value', '2023-05-15');
 */
Cypress.Commands.add("typeFlatpickrDate", (selector, dateString) => {
    return cy.getFlatpickr(selector).flatpickr({ typeDate: dateString });
});

/**
 * Helper to select a date range in a Flatpickr range picker
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @param {Date|string} startDate - The start date to select
 * @param {Date|string} endDate - The end date to select
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.selectFlatpickrDateRange('#rangePicker', '2023-06-01', '2023-06-15');
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#rangePicker')
 *   .selectFlatpickrDateRange('#rangePicker', '2023-06-01', '2023-06-15')
 *   .should('have.value', '2023-06-01 to 2023-06-15');
 */
Cypress.Commands.add(
    "selectFlatpickrDateRange",
    (selector, startDate, endDate) => {
        return cy.getFlatpickr(selector).flatpickr({
            selectRange: [startDate, endDate],
        });
    }
);

// Helper function to navigate to a specific date in the flatpickr calendar
Cypress.Commands.add("navigateToFlatpickrDate", targetDate => {
    cy.get(".flatpickr-current-month .numInput.cur-year").then($year => {
        cy.get(".flatpickr-current-month").then($month => {
            const currentYear = parseInt($year.val());

            // Extract month name from the displayed text
            const currentMonthText = $month.text().trim();
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

            // Find current month index
            const currentMonth = monthNames.findIndex(name =>
                currentMonthText.includes(name)
            );

            // Calculate how many months to move
            const targetYear = targetDate.getFullYear();
            const targetMonth = targetDate.getMonth();

            const monthDiff =
                (targetYear - currentYear) * 12 + (targetMonth - currentMonth);

            if (monthDiff > 0) {
                // Move forward
                for (let i = 0; i < monthDiff; i++) {
                    cy.get(".flatpickr-next-month").click();
                    cy.wait(100);
                }
            } else if (monthDiff < 0) {
                // Move backward
                for (let i = 0; i < Math.abs(monthDiff); i++) {
                    cy.get(".flatpickr-prev-month").click();
                    cy.wait(100);
                }
            }
        });
    });
});

/**
 * Helper to get the current value from a Flatpickr input
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @returns {string} The date value in the input
 *
 * @example
 * // Standalone usage
 * cy.getFlatpickrValue('#dateInput').then(value => {
 *   expect(value).to.equal('2023-05-15');
 * });
 */
Cypress.Commands.add("getFlatpickrValue", selector => {
    return cy.get(selector).invoke("val");
});

/**
 * Helper to assert that a Flatpickr input has a specific date value
 *
 * @param {string} selector - jQuery-like selector for the original input element
 * @param {string} expectedDate - The expected date value in the input
 *
 * @example
 * // Standalone usage
 * cy.flatpickrShouldHaveValue('#dateInput', '2023-05-15');
 *
 * @example
 * // As part of a chain
 * cy.getFlatpickr('#dateInput')
 *   .flatpickr({ selectDate: '2023-05-15' })
 *   .flatpickrShouldHaveValue('#dateInput', '2023-05-15');
 */
Cypress.Commands.add("flatpickrShouldHaveValue", (selector, expectedDate) => {
    return cy.get(selector).should("have.value", expectedDate);
});
