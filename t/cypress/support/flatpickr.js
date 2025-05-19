// flatpickrHelpers.js - Reusable Cypress functions for Flatpickr date pickers

/**
 * Helper functions for interacting with Flatpickr date picker components in Cypress tests
 * Uses click-driven interactions instead of Flatpickr's JavaScript API
 * Supports all standard Flatpickr operations including date selection, range selection,
 * navigation, and direct input.
 *
 * CHAINABILITY:
 * All Flatpickr helper commands are fully chainable. You can:
 * - Chain multiple Flatpickr operations (open, navigate, select)
 * - Chain Flatpickr commands with standard Cypress commands
 * - Split complex interactions into multiple steps for better reliability
 *
 * Examples:
 * cy.getFlatpickr('#myDatepicker')
 * .openFlatpickr()
 * .selectFlatpickrDate('2023-05-15');
 *
 * cy.getFlatpickr('#rangePicker')
 * .openFlatpickr()
 * .selectFlatpickrDateRange('2023-06-01', '2023-06-15')
 * .should('have.value', '2023-06-01 to 2023-06-15');
 */

// --- Base Helper to Get the Flatpickr Input ---
/**
 * Helper to get a Flatpickr input element by its selector.
 * This is the recommended starting point for chainable Flatpickr operations.
 *
 * @param {string} selector - jQuery-like selector for the original input element.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns a chainable Cypress object for further commands.
 *
 * @example
 * cy.getFlatpickr('#dateInput')
 * .openFlatpickr();
 */
Cypress.Commands.add("getFlatpickr", selector => {
    return cy.get(selector);
});

// --- Internal Utility Functions ---

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

/**
 * Generates a Cypress selector for a specific day element within the Flatpickr calendar
 * based on its aria-label. This is a low-level internal helper.
 *
 * @param {Date} date - The Date object representing the day to find.
 * @returns {string} - A CSS selector string for the day element.
 */
const _getFlatpickrDaySelector = date => {
    const month = monthNames[date.getMonth()];
    const day = date.getDate();
    const year = date.getFullYear();
    const formattedLabel = `${month} ${day}, ${year}`;
    return `.flatpickr-day[aria-label="${formattedLabel}"]`;
};

/**
 * Ensures the Flatpickr calendar is open. If not, it clicks the input to open it.
 * This is an internal helper used by other commands.
 * @param {Cypress.Chainable<JQuery<HTMLElement>>} $el - The Cypress chainable for the Flatpickr input.
 * @param {number} timeout - The timeout for waiting for the calendar to open.
 */
const ensureCalendarIsOpen = ($el, timeout) => {
    $el.then($input => {
        const inputToClick = $input.is(":visible")
            ? $input
            : $input.parents().find(".flatpickr-input:visible").first();
        if (!inputToClick.length) {
            throw new Error(
                `Flatpickr: Could not find visible input element for selector '${$input.selector}' to open calendar.`
            );
        }

        cy.get(".flatpickr-calendar").then($calendar => {
            const isVisible =
                $calendar.hasClass("open") && $calendar.is(":visible");
            if (!isVisible) {
                cy.wrap(inputToClick).click();
            }
            cy.get(".flatpickr-calendar.open", { timeout }).should(
                "be.visible"
            );
        });
    });
};

/**
 * Navigates the Flatpickr calendar to the target month and year.
 * This is an internal helper used by other commands.
 * @param {Date} targetDate - The date object representing the target month/year.
 * @param {number} timeout - The timeout for operations in milliseconds.
 */
const navigateToMonthAndYear = (targetDate, timeout = 10000) => {
    cy.get(".flatpickr-calendar.open", { timeout })
        .should("be.visible")
        .within(() => {
            const targetYear = targetDate.getFullYear();
            const targetMonth = targetDate.getMonth();

            cy.get(".flatpickr-current-month .numInput.cur-year")
                .invoke("val")
                .then(initialYearVal => {
                    const initialYear = parseInt(initialYearVal, 10);
                    cy.get(
                        ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected"
                    )
                        .invoke("text")
                        .then(initialMonthName => {
                            const initialMonth = monthNames.findIndex(name =>
                                initialMonthName.includes(name.trim())
                            );

                            const monthDiff =
                                (targetYear - initialYear) * 12 +
                                (targetMonth - initialMonth);
                            const numClicks = Math.abs(monthDiff);
                            const clickButtonSelector =
                                monthDiff > 0
                                    ? ".flatpickr-next-month"
                                    : ".flatpickr-prev-month";

                            Cypress._.times(numClicks, i => {
                                cy.get(clickButtonSelector).click();
                            });

                            // Assert that the calendar displays the target month and year
                            cy.get(
                                ".flatpickr-current-month .numInput.cur-year",
                                { timeout }
                            ).should("have.value", targetYear.toString());
                            cy.get(
                                ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected",
                                { timeout }
                            ).should("contain.text", monthNames[targetMonth]);
                        });
                });
        });
};

// --- User-Facing Helper Commands ---

/**
 * Helper to open a Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.openFlatpickr('#dateInput');
 * cy.getFlatpickr('#dateInput').openFlatpickr();
 */
Cypress.Commands.add(
    "openFlatpickr",
    { prevSubject: "optional" },
    (subject, selector, timeout = 10000) => {
        const $el = subject ? cy.wrap(subject) : cy.get(selector);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input for consistency
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to close an open Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} [subjectOrSelector] - Optional: Either a jQuery element (when chained) or a string selector.
 * If not provided, it assumes a calendar is open and clicks away to close it.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject if provided, else `cy.get('body')`.
 *
 * @example
 * cy.closeFlatpickr(); // Closes the currently open calendar
 * cy.getFlatpickr('#dateInput').closeFlatpickr(); // Closes for a specific input
 */
Cypress.Commands.add(
    "closeFlatpickr",
    { prevSubject: "optional" },
    (subject, selector) => {
        const chain = subject
            ? cy.wrap(subject)
            : selector
                ? cy.get(selector)
                : cy.get("body");
        return chain.then($el => {
            cy.get("body").click(0, 0); // Click anywhere outside to close
            // Assert that the calendar is no longer open
            cy.get(".flatpickr-calendar.open").should("not.exist", {
                timeout: 5000,
            });
            return cy.wrap($el); // Pass on the original subject for chainability
        });
    }
);

/**
 * Helper to clear a Flatpickr selection.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.clearFlatpickr('#dateInput');
 * cy.getFlatpickr('#dateInput').clearFlatpickr();
 */
Cypress.Commands.add(
    "clearFlatpickr",
    { prevSubject: "optional" },
    (subject, selector, timeout = 10000) => {
        const $el = subject ? cy.wrap(subject) : cy.get(selector);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            cy.wrap($input).parents().find(".flatpickr-clear").click();
            // Assert the input is cleared
            cy.wrap($input).should("have.value", "");
            cy.wrap($input)
                .parents()
                .find(".flatpickr-input:visible")
                .should("have.value", "");
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to navigate to a specific month and year in a Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {string|Date} targetDate - The date to navigate to (YYYY-MM-DD string or Date object).
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.navigateToFlatpickrMonth('#dateInput', '2024-10-01');
 * cy.getFlatpickr('#dateInput').navigateToFlatpickrMonth('2024-10-01');
 */
Cypress.Commands.add(
    "navigateToFlatpickrMonth",
    { prevSubject: true },
    (subject, targetDate, timeout = 10000) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            const dateObj =
                typeof targetDate === "string"
                    ? new Date(targetDate)
                    : targetDate;
            navigateToMonthAndYear(dateObj, timeout);
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to navigate to the next month in a Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.nextFlatpickrMonth('#dateInput');
 * cy.getFlatpickr('#dateInput').nextFlatpickrMonth();
 */
Cypress.Commands.add(
    "nextFlatpickrMonth",
    { prevSubject: "optional" },
    (subject, selector, timeout = 10000) => {
        const $el = subject ? cy.wrap(subject) : cy.get(selector);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            cy.get(
                ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected"
            )
                .invoke("text")
                .then(initialMonthName => {
                    cy.get(".flatpickr-current-month .numInput.cur-year")
                        .invoke("val")
                        .then(initialYearVal => {
                            cy.get(".flatpickr-calendar.open")
                                .should("be.visible")
                                .find(".flatpickr-next-month")
                                .click();
                            cy.get(
                                ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected",
                                { timeout: 5000 }
                            )
                                .should("not.contain.text", initialMonthName)
                                .or("not.have.value", initialYearVal);
                        });
                });
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to navigate to the previous month in a Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.prevFlatpickrMonth('#dateInput');
 * cy.getFlatpickr('#dateInput').prevFlatpickrMonth();
 */
Cypress.Commands.add(
    "prevFlatpickrMonth",
    { prevSubject: "optional" },
    (subject, selector, timeout = 10000) => {
        const $el = subject ? cy.wrap(subject) : cy.get(selector);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            cy.get(
                ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected"
            )
                .invoke("text")
                .then(initialMonthName => {
                    cy.get(".flatpickr-current-month .numInput.cur-year")
                        .invoke("val")
                        .then(initialYearVal => {
                            cy.get(".flatpickr-calendar.open")
                                .should("be.visible")
                                .find(".flatpickr-prev-month")
                                .click();
                            cy.get(
                                ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected",
                                { timeout: 5000 }
                            )
                                .should("not.contain.text", initialMonthName)
                                .or("not.have.value", initialYearVal);
                        });
                });
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to set the year in a Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {number} year - The year to set.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.setFlatpickrYear('#dateInput', 2025);
 * cy.getFlatpickr('#dateInput').setFlatpickrYear(2025);
 */
Cypress.Commands.add(
    "setFlatpickrYear",
    { prevSubject: true },
    (subject, year, timeout = 10000) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            cy.get(".flatpickr-calendar.open")
                .should("be.visible")
                .find(".flatpickr-current-month .numInput.cur-year")
                .click()
                .clear()
                .type(year.toString(), { force: true })
                .type("{enter}") // Ensure the year input updates its value
                .should("have.value", year.toString()); // Assert the input value has updated
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to get the Flatpickr mode ('single', 'range', 'multiple').
 * This command must be chained from a Flatpickr input element.
 *
 * @param {Cypress.Chainable<JQuery<HTMLElement>>} subject - The jQuery element (input field) the Flatpickr is attached to.
 * @returns {Cypress.Chainable<string>} - Yields the mode string ('single', 'range', 'multiple').
 *
 * @example
 * cy.get('#dateInput').getFlatpickrMode().then(mode => {
 * cy.log(`Flatpickr mode: ${mode}`);
 * });
 */
Cypress.Commands.add(
    "getFlatpickrMode",
    { prevSubject: true }, // This command MUST be chained from an element
    subject => {
        return cy.wrap(subject).then($input => {
            const fpInstance = $input[0]._flatpickr;
            if (!fpInstance) {
                throw new Error(
                    `Flatpickr: Cannot find flatpickr instance on element ${$input.selector}. Make sure it's initialized with flatpickr.`
                );
            }
            return fpInstance.config.mode; // Yield the mode string
        });
    }
);

/**
 * Helper to select a specific day of the month from the current Flatpickr view.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {number} day - The day of the month to select (e.g., 15 for the 15th).
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.selectFlatpickrDay('#dateInput', 15);
 * cy.getFlatpickr('#dateInput').selectFlatpickrDay(15);
 */
Cypress.Commands.add(
    "selectFlatpickrDay",
    { prevSubject: true },
    (subject, day, timeout = 10000) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            cy.get(".flatpickr-calendar.open")
                .should("be.visible")
                .within(() => {
                    cy.get(".flatpickr-current-month .numInput.cur-year").then(
                        $currentYearInput => {
                            cy.get(
                                ".flatpickr-current-month .flatpickr-monthDropdown-months"
                            ).then($currentMonthDropdown => {
                                const currentYear = parseInt(
                                    $currentYearInput.val(),
                                    10
                                );
                                const selectedMonthName = $currentMonthDropdown
                                    .find("option:selected")
                                    .first()
                                    .text()
                                    .trim();
                                const currentMonth = monthNames.findIndex(
                                    name =>
                                        selectedMonthName.includes(name.trim())
                                );

                                const targetDateInCurrentView = new Date(
                                    currentYear,
                                    currentMonth,
                                    day
                                );

                                cy.wrap($input)
                                    .getFlatpickrDay(targetDateInCurrentView)
                                    .click(); // Pass the input subject

                                // Conditional assertion based on Flatpickr mode
                                cy.wrap($input)
                                    .getFlatpickrMode()
                                    .then(mode => {
                                        if (mode === "single") {
                                            const expectedDateFormatted = `${targetDateInCurrentView.getFullYear()}-${(targetDateInCurrentView.getMonth() + 1).toString().padStart(2, "0")}-${targetDateInCurrentView.getDate().toString().padStart(2, "0")}`;
                                            cy.wrap($input).should(
                                                "have.value",
                                                expectedDateFormatted
                                            );
                                            cy.get(
                                                ".flatpickr-calendar.open"
                                            ).should("not.exist", {
                                                timeout: 5000,
                                            }); // Assert calendar closes
                                        } else if (mode === "range") {
                                            // In range mode, the first selection keeps the calendar open.
                                            // Assert that the day is marked as selected (Flatpickr adds 'selected' and 'startRange' classes)
                                            cy.wrap($input)
                                                .getFlatpickrDay(
                                                    targetDateInCurrentView
                                                )
                                                .should(
                                                    "have.class",
                                                    "selected"
                                                );
                                            cy.get(
                                                ".flatpickr-calendar.open"
                                            ).should("be.visible"); // Assert calendar stays open
                                        }
                                    });
                                return cy.wrap($input);
                            });
                        }
                    );
                });
        });
    }
);

/**
 * Helper to select today's date in a Flatpickr calendar.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.selectFlatpickrToday('#dateInput');
 * cy.getFlatpickr('#dateInput').selectFlatpickrToday();
 */
Cypress.Commands.add(
    "selectFlatpickrToday",
    { prevSubject: "optional" },
    (subject, selector, timeout = 10000) => {
        const $el = subject ? cy.wrap(subject) : cy.get(selector);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            cy.get(".flatpickr-calendar.open")
                .should("be.visible")
                .find(".flatpickr-day.today")
                .click();

            // Conditional assertion based on Flatpickr mode
            cy.wrap($input)
                .getFlatpickrMode()
                .then(mode => {
                    const today = new Date(); // Using native Date for today's date
                    if (mode === "single") {
                        const expectedDateFormatted = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, "0")}-${today.getDate().toString().padStart(2, "0")}`;
                        cy.wrap($input).should(
                            "have.value",
                            expectedDateFormatted
                        );
                        cy.get(".flatpickr-calendar.open").should("not.exist", {
                            timeout: 5000,
                        }); // Assert calendar closes
                    } else if (mode === "range") {
                        // In range mode, the first selection keeps the calendar open.
                        cy.wrap($input)
                            .getFlatpickrDay(today)
                            .should("have.class", "selected"); // Assert it's selected
                        cy.get(".flatpickr-calendar.open").should("be.visible"); // Assert calendar stays open
                    }
                });
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to select a specific date in a Flatpickr.
 * This command will navigate to the correct month/year if necessary and then select the day.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {string|Date} date - The date to select (YYYY-MM-DD string or Date object).
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.selectFlatpickrDate('#dateInput', '2023-05-15');
 * cy.getFlatpickr('#dateInput').selectFlatpickrDate('2023-05-15');
 */
Cypress.Commands.add(
    "selectFlatpickrDate",
    { prevSubject: true },
    (subject, date, timeout = 10000) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input
            const dateObj = typeof date === "string" ? new Date(date) : date;
            navigateToMonthAndYear(dateObj, timeout);

            // Use the new public getFlatpickrDay command for selection
            cy.wrap($input).getFlatpickrDay(dateObj).click(); // Pass the input subject

            // Conditional assertion based on Flatpickr mode
            cy.wrap($input)
                .getFlatpickrMode()
                .then(mode => {
                    if (mode === "single") {
                        const expectedDateFormatted = `${dateObj.getFullYear()}-${(dateObj.getMonth() + 1).toString().padStart(2, "0")}-${dateObj.getDate().toString().padStart(2, "0")}`;
                        cy.wrap($input).should(
                            "have.value",
                            expectedDateFormatted
                        );
                        cy.get(".flatpickr-calendar.open").should("not.exist", {
                            timeout: 5000,
                        }); // Assert calendar closes
                    } else if (mode === "range") {
                        // In range mode, the first selection keeps the calendar open.
                        cy.wrap($input)
                            .getFlatpickrDay(dateObj)
                            .should("have.class", "selected"); // Assert it's selected
                        cy.get(".flatpickr-calendar.open").should("be.visible"); // Assert calendar stays open
                    }
                });
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to select a specific date in a Flatpickr.
 * This command will navigate to the correct month/year if necessary and then select the day.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {string|Date} date - The date to select (YYYY-MM-DD string or Date object).
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.selectFlatpickrDate('#dateInput', '2023-05-15');
 * cy.getFlatpickr('#dateInput').selectFlatpickrDate('2023-05-15');
 */
Cypress.Commands.add(
    "selectFlatpickrDate",
    { prevSubject: true },
    (subject, date, timeout = 10000) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout);
            const dateObj = typeof date === "string" ? new Date(date) : date;
            navigateToMonthAndYear(dateObj, timeout);

            // Click the day element directly without chaining
            cy.wrap($input).getFlatpickrDay(dateObj).click();

            // Now perform assertions and return the input
            return cy
                .wrap($input)
                .getFlatpickrMode()
                .then(mode => {
                    if (mode === "single") {
                        const expectedDateFormatted = `${dateObj.getFullYear()}-${(dateObj.getMonth() + 1).toString().padStart(2, "0")}-${dateObj.getDate().toString().padStart(2, "0")}`;
                        cy.wrap($input).should(
                            "have.value",
                            expectedDateFormatted
                        );
                        cy.get(".flatpickr-calendar.open").should("not.exist", {
                            timeout: 5000,
                        });
                    } else if (mode === "range") {
                        cy.wrap($input)
                            .getFlatpickrDay(dateObj)
                            .should("have.class", "selected");
                        cy.get(".flatpickr-calendar.open").should("be.visible");
                    }

                    // Always return the original input for chainability
                    return cy.wrap($input);
                });
        });
    }
);

/**
 * Helper to type a date directly into a Flatpickr input.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {string} dateString - The date string to type in the format expected by Flatpickr.
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.typeFlatpickrDate('#dateInput', '2023-05-15');
 * cy.getFlatpickr('#dateInput').typeFlatpickrDate('2023-05-15');
 */
Cypress.Commands.add(
    "typeFlatpickrDate",
    { prevSubject: true },
    (subject, dateString) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            // Find the visible input field for Flatpickr
            cy.wrap($input)
                .parents()
                .find(".flatpickr-input:visible")
                .clear()
                .type(dateString);
            cy.get("body").click(0, 0); // Click away to trigger blur and date parsing
            cy.wrap($input).should("not.have.value", ""); // Assert something was entered
            return cy.wrap($input);
        });
    }
);

/**
 * Helper to select a date range in a Flatpickr range picker.
 * This command will navigate to the correct months if necessary and then select the start and end days.
 *
 * @param {string|Cypress.Chainable<JQuery<HTMLElement>>} subjectOrSelector - Either a jQuery element (when chained) or a string selector.
 * @param {string|Date} startDate - The start date to select (YYYY-MM-DD string or Date object).
 * @param {string|Date} endDate - The end date to select (YYYY-MM-DD string or Date object).
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - Returns the original subject for chainability.
 *
 * @example
 * cy.selectFlatpickrDateRange('#rangePicker', '2023-06-01', '2023-06-15');
 * cy.getFlatpickr('#rangePicker').selectFlatpickrDateRange('2023-06-01', '2023-06-15');
 */
Cypress.Commands.add(
    "selectFlatpickrDateRange",
    { prevSubject: true },
    (subject, startDate, endDate, timeout = 10000) => {
        const $el = cy.wrap(subject);
        return $el.then($input => {
            ensureCalendarIsOpen(cy.wrap($input), timeout); // Pass wrapped input

            const startDateObj =
                typeof startDate === "string" ? new Date(startDate) : startDate;
            const endDateObj =
                typeof endDate === "string" ? new Date(endDate) : endDate;

            // Check if the flatpickr instance is in range mode
            cy.wrap($input)
                .getFlatpickrMode()
                .then(mode => {
                    if (mode !== "range") {
                        throw new Error(
                            `Flatpickr: This flatpickr instance (${$input.selector}) is not in range mode. Current mode: ${mode}. Cannot select range.`
                        );
                    }
                });

            navigateToMonthAndYear(startDateObj, timeout);

            // Select start date
            cy.wrap($input).getFlatpickrDay(startDateObj).click(); // Pass the input subject
            // Assert that the start date is marked as selected (and range properties if applicable)
            cy.wrap($input)
                .getFlatpickrDay(startDateObj)
                .should("have.class", "selected")
                .and("have.class", "startRange");
            cy.get(".flatpickr-calendar.open").should("be.visible"); // Assert calendar stays open

            // Navigate to end date if it's in a different month/year
            if (
                startDateObj.getMonth() !== endDateObj.getMonth() ||
                startDateObj.getFullYear() !== endDateObj.getFullYear()
            ) {
                navigateToMonthAndYear(endDateObj, timeout);
            }

            // Select end date
            cy.wrap($input).getFlatpickrDay(endDateObj).click(); // Pass the input subject
            // Assert input value and calendar closes
            const expectedRangeFormatted = `${startDateObj.getFullYear()}-${(startDateObj.getMonth() + 1).toString().padStart(2, "0")}-${startDateObj.getDate().toString().padStart(2, "0")} to ${endDateObj.getFullYear()}-${(endDateObj.getMonth() + 1).toString().padStart(2, "0")}-${endDateObj.getDate().toString().padStart(2, "0")}`;
            cy.wrap($input).should("have.value", expectedRangeFormatted);
            cy.get(".flatpickr-calendar.open").should("not.exist", {
                timeout: 5000,
            }); // Assert calendar closes
            return cy.wrap($input);
        });
    }
);

// --- Assertions ---

/**
 * Helper to get the current value from a Flatpickr input.
 *
 * @param {string} selector - jQuery-like selector for the original input element.
 * @returns {Cypress.Chainable<string>} The date value in the input.
 *
 * @example
 * cy.getFlatpickrValue('#dateInput').then(value => {
 * expect(value).to.equal('2023-05-15');
 * });
 */
Cypress.Commands.add("getFlatpickrValue", selector => {
    return cy.get(selector).invoke("val");
});

/**
 * Helper to assert that a Flatpickr input has a specific date value.
 *
 * @param {string} selector - jQuery-like selector for the original input element.
 * @param {string} expectedDate - The expected date value in the input (e.g., 'YYYY-MM-DD' or 'YYYY-MM-DD toBRUARY-MM-DD').
 *
 * @example
 * cy.flatpickrShouldHaveValue('#dateInput', '2023-05-15');
 */
Cypress.Commands.add("flatpickrShouldHaveValue", (selector, expectedDate) => {
    return cy.get(selector).should("have.value", expectedDate);
});

/**
 * Helper to get a specific Flatpickr day element by its date.
 * This command yields the actual day element (<td> or <span>) in the calendar.
 * It also asserts that the calendar is open and that the correct month/year is in view.
 *
 * @param {Cypress.Chainable<JQuery<HTMLElement>>} subject - The Flatpickr input element this calendar belongs to (obtained via cy.getFlatpickr()).
 * @param {Date|string} date - The date to get the element for (Date object or BCE-MM-DD string).
 * @returns {Cypress.Chainable<JQuery<HTMLElement>>} - A Cypress chainable that yields the day element.
 *
 * @example
 * cy.getFlatpickr('#myDatepicker')
 * .openFlatpickr()
 * .getFlatpickrDay('2023-07-15') // Pass date directly as it's chained
 * .should('have.class', 'flatpickr-disabled');
 */
Cypress.Commands.add(
    "getFlatpickrDay",
    { prevSubject: true }, // This command MUST be chained from an element
    (subject, date) => {
        const dateObj = typeof date === "string" ? new Date(date) : date;
        if (!(dateObj instanceof Date && !isNaN(dateObj.getTime()))) {
            throw new Error(
                `getFlatpickrDay: Invalid date provided. Received: ${date}`
            );
        }

        const targetMonth = dateObj.getMonth();
        const targetYear = dateObj.getFullYear();

        // 1. Assert that the Flatpickr calendar is open and visible
        return cy
            .get(".flatpickr-calendar.open", { timeout: 10000 })
            .should("be.visible")
            .then($calendar => {
                // 2. Check if the correct month and year is in view
                return cy
                    .get($calendar)
                    .find(".flatpickr-current-month .numInput.cur-year")
                    .then($currentYearInput => {
                        const currentYear = parseInt(
                            $currentYearInput.val(),
                            10
                        );

                        return cy
                            .get($calendar)
                            .find(
                                ".flatpickr-current-month .flatpickr-monthDropdown-months option:selected"
                            )
                            .then($currentMonthOption => {
                                const currentMonthName = $currentMonthOption
                                    .text()
                                    .trim();
                                const currentMonth = monthNames.findIndex(
                                    name =>
                                        currentMonthName.includes(name.trim())
                                );

                                if (
                                    currentMonth !== targetMonth ||
                                    currentYear !== targetYear
                                ) {
                                    throw new Error(
                                        `Flatpickr: Calendar is showing '${monthNames[currentMonth]} ${currentYear}' but expected to find day for '${monthNames[targetMonth]} ${targetYear}'. ` +
                                        `Please ensure the calendar is navigated to the correct month/year using .navigateToFlatpickrMonth() before calling .getFlatpickrDay().`
                                    );
                                }

                                // 3. If all checks pass, find and yield the day element
                                return cy.get(
                                    _getFlatpickrDaySelector(dateObj)
                                );
                            });
                    });
            });
    }
);
