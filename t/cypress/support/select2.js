// Select2Helpers.js - Reusable Cypress functions for Select2 dropdowns

/**
 * Helper functions for interacting with Select2 dropdown components in Cypress tests
 * Supports AJAX-based Select2s, triggering all standard Select2 events, and
 * multiple selection methods including index and text matching (partial/full)
 *
 * CHAINABILITY:
 * All Select2 helper commands are fully chainable. You can:
 * - Chain multiple Select2 operations (search, then select)
 * - Chain Select2 commands with standard Cypress commands
 * - Split complex interactions into multiple steps for better reliability
 *
 * Examples:
 *   cy.getSelect2('#mySelect')
 *     .select2({ search: 'foo' })
 *     .select2({ select: 'FooBar' });
 *
 *   cy.getSelect2('#mySelect')
 *     .select2({ search: 'bar' })
 *     .select2({ selectIndex: 0 })
 *     .should('have.value', 'bar_value');
 */

/**
 * Main Select2 interaction command to perform operations on Select2 dropdowns
 * @param {string|JQuery} [subject] - Optional jQuery element (when used with .select2())
 * @param {Object} options - Configuration options for the Select2 operation
 * @param {string} [options.search] - Search text to enter in the search box
 * @param {string|Object} [options.select] - Text to select or object with matcher options
 * @param {number} [options.selectIndex] - Index of the option to select (0-based)
 * @param {string} [options.selector] - CSS selector to find the select element (when not using subject)
 * @param {boolean} [options.clearSelection=false] - Whether to clear the current selection first
 * @param {Function} [options.matcher] - Custom matcher function for complex option selection
 * @param {number} [options.timeout=10000] - Timeout for AJAX responses in milliseconds
 * @param {boolean} [options.multiple=false] - Whether the select2 allows multiple selections
 * @param {number} [options.minSearchLength=3] - Minimum length of search text needed for Ajax select2
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Basic usage
 * cy.get('#mySelect').select2({ search: 'foo', select: 'FooBar' });
 *
 * @example
 * // Chained operations (more reliable, especially for AJAX Select2)
 * cy.getSelect2('#mySelect')
 *   .select2({ search: 'foo' })
 *   .select2({ select: 'FooBar' });
 *
 * @example
 * // With custom matcher
 * cy.getSelect2('#mySelect').select2({
 *   search: 'special',
 *   matcher: (option) => option.text.includes('Special Edition')
 * });
 */
Cypress.Commands.add(
    "select2",
    {
        prevSubject: "optional",
    },
    (subject, options) => {
        // Default configuration
        const defaults = {
            search: null, // Search text to enter in the search box
            select: null, // Text to select or object with matcher options
            selectIndex: null, // Index of the option to select
            selector: null, // CSS selector to find the select element (when not using subject)
            clearSelection: false, // Whether to clear the current selection first
            matcher: null, // Custom matcher function for complex option selection
            timeout: 10000, // Timeout for AJAX responses
            multiple: false, // Whether the select2 allows multiple selections
            minSearchLength: 3, // Minimum length of search text needed for Ajax select2
        };

        // Merge passed options with defaults
        const config = { ...defaults, ...options };

        // Handle selecting the target Select2 element
        let $originalSelect;
        if (subject) {
            $originalSelect = subject;
            // Store the element ID as a data attribute for chaining
            cy.wrap(subject).then($el => {
                const selectId = $el.attr("id");
                if (selectId) {
                    Cypress.$($el).attr("data-select2-helper-id", selectId);
                }
            });
        } else if (config.selector) {
            $originalSelect = cy.get(config.selector);
        } else {
            throw new Error(
                "Either provide a subject or a selector to identify the Select2 element"
            );
        }

        return cy.wrap($originalSelect).then($el => {
            // Try to get the ID either from the element or from the stored data attribute
            const selectId = $el.attr("id") || $el.data("select2-helper-id");

            if (!selectId) {
                throw new Error(
                    "Select element must have an ID attribute for the Select2 helper to work correctly"
                );
            }

            // Find the Select2 container - based on the actual DOM structure
            // Look for a span.select2-container that's a sibling of the original select
            cy.get(`select#${selectId}`)
                .siblings(".select2-container")
                .first()
                .then($container => {
                    // Handle clearing the selection if requested
                    if (config.clearSelection) {
                        // Use Select2's API to clear the selection
                        cy.window().then(win => {
                            // Use jQuery to access the Select2 element and clear it programmatically
                            win.$(`select#${selectId}`)
                                .val(null)
                                .trigger("change");
                        });
                        // Return early if we're just clearing
                        if (
                            config.search === null &&
                            config.select === null &&
                            config.selectIndex === null &&
                            config.matcher === null
                        ) {
                            return;
                        }
                    }

                    // Find the select2-selection element within the container and click it
                    cy.wrap($container)
                        .find(".select2-selection")
                        .first()
                        .click({ force: true });

                    // Handle search functionality
                    if (config.search !== null) {
                        // Find the search field in the dropdown (which is appended to body)
                        cy.get(
                            ".select2-search--dropdown .select2-search__field"
                        )
                            .first()
                            .should("be.visible")
                            .type(config.search, { force: true });

                        // If this is an Ajax select2 that requires minimum characters
                        if (config.search.length < config.minSearchLength) {
                            cy.log(
                                `Warning: Search text "${config.search}" may be too short for Ajax select2 (minimum typically ${config.minSearchLength} characters)`
                            );

                            // Check if we see the "Please enter X or more characters" message
                            cy.get(".select2-results__message").then(
                                $message => {
                                    if (
                                        $message.length > 0 &&
                                        $message.text().includes("character")
                                    ) {
                                        cy.log(
                                            "Detected minimum character requirement message. Search string may be too short."
                                        );
                                    }
                                }
                            );
                        }

                        // Wait for results to load - use a longer timeout for AJAX-based Select2
                        cy.get(".select2-results__options", {
                            timeout: config.timeout,
                        }).should("exist");

                        // Wait a moment for AJAX responses to complete
                        cy.wait(300); // Small wait to ensure AJAX response completes

                        // Check for no results to provide helpful error
                        cy.get(".select2-results__option").then($options => {
                            if (
                                $options.length === 0 ||
                                ($options.length === 1 &&
                                    $options
                                        .first()
                                        .text()
                                        .includes("No results")) ||
                                ($options.length === 1 &&
                                    $options
                                        .first()
                                        .text()
                                        .includes("Please enter"))
                            ) {
                                cy.log(
                                    `Warning: No results found for search: "${config.search}"`
                                );
                            }
                        });
                    }

                    // Handle selection based on the provided options
                    if (
                        config.select !== null ||
                        config.selectIndex !== null ||
                        config.matcher !== null
                    ) {
                        // Get the results options
                        cy.get(".select2-results__option").then($options => {
                            if (
                                $options.length === 0 ||
                                ($options.length === 1 &&
                                    $options
                                        .first()
                                        .text()
                                        .includes("No results")) ||
                                ($options.length === 1 &&
                                    $options
                                        .first()
                                        .text()
                                        .includes("Please enter"))
                            ) {
                                throw new Error(
                                    `No selectable options found for search: "${config.search}"`
                                );
                            }

                            let $optionToSelect;

                            // Select by index
                            if (config.selectIndex !== null) {
                                if (
                                    config.selectIndex < 0 ||
                                    config.selectIndex >= $options.length
                                ) {
                                    throw new Error(
                                        `Select2: index ${config.selectIndex} out of bounds (0-${$options.length - 1})`
                                    );
                                }
                                $optionToSelect = $options.eq(
                                    config.selectIndex
                                );
                            }
                            // Select by custom matcher function
                            else if (
                                config.matcher !== null &&
                                typeof config.matcher === "function"
                            ) {
                                for (let i = 0; i < $options.length; i++) {
                                    const $option = $options.eq(i);
                                    const optionContent = {
                                        text: $option.text().trim(),
                                        html: $option.html(),
                                        element: $option[0],
                                    };

                                    if (config.matcher(optionContent, i)) {
                                        $optionToSelect = $option;
                                        break;
                                    }
                                }
                            }
                            // Select by text (default)
                            else if (config.select !== null) {
                                // If config.select is a string, use default matching
                                if (typeof config.select === "string") {
                                    const selectText = config.select;

                                    // Try exact match first
                                    const exactMatch = $options.filter(
                                        (i, el) =>
                                            Cypress.$(el).text().trim() ===
                                            selectText
                                    );

                                    if (exactMatch.length) {
                                        $optionToSelect = exactMatch.first();
                                    } else {
                                        // Fall back to partial match
                                        const partialMatches = $options.filter(
                                            (i, el) =>
                                                Cypress.$(el)
                                                    .text()
                                                    .trim()
                                                    .includes(selectText)
                                        );

                                        if (partialMatches.length) {
                                            $optionToSelect =
                                                partialMatches.first();
                                        }
                                    }
                                }
                                // Handle object format for advanced matching
                                else if (typeof config.select === "object") {
                                    const matchType =
                                        config.select.matchType || "partial"; // 'exact', 'partial', 'startsWith', 'endsWith'
                                    const text = config.select.text;

                                    if (!text) {
                                        throw new Error(
                                            'When using object format for selection, "text" property is required'
                                        );
                                    }

                                    let matcher;
                                    switch (matchType) {
                                        case "exact":
                                            matcher = optText =>
                                                optText === text;
                                            break;
                                        case "startsWith":
                                            matcher = optText =>
                                                optText.startsWith(text);
                                            break;
                                        case "endsWith":
                                            matcher = optText =>
                                                optText.endsWith(text);
                                            break;
                                        case "partial":
                                        default:
                                            matcher = optText =>
                                                optText.includes(text);
                                    }

                                    for (let i = 0; i < $options.length; i++) {
                                        const $option = $options.eq(i);
                                        const optionText = $option
                                            .text()
                                            .trim();

                                        if (matcher(optionText)) {
                                            $optionToSelect = $option;
                                            break;
                                        }
                                    }
                                }
                            }

                            // If we found an option to select, click it
                            if ($optionToSelect) {
                                cy.wrap($optionToSelect).click({ force: true });
                                cy.wait(300);

                                // Check that the original select has a value (to verify selection worked)
                                // We just check that it has some value, not a specific value
                                cy.get(`select#${selectId}`).should($el => {
                                    expect($el.val()).to.not.be.null;
                                    expect($el.val()).to.not.equal("");
                                });
                            } else {
                                throw new Error(
                                    `Could not find any option matching the selection criteria. Search: "${config.search}", Select: "${config.select}"`
                                );
                            }
                        });
                    }
                });
        });
    }
);

/**
 * Helper to get a Select2 dropdown by any jQuery-like selector
 * This is the recommended starting point for chainable Select2 operations
 *
 * @param {string} selector - jQuery-like selector for the original select element
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Chain multiple Select2 operations
 * cy.getSelect2('#bookSelect')
 *   .select2({ search: 'JavaScript' })
 *   .select2({ select: 'JavaScript: The Good Parts' });
 *
 * @example
 * // Chain with standard Cypress assertions
 * cy.getSelect2('#categorySelect')
 *   .select2({ select: 'Fiction' })
 *   .should('have.value', 'fiction');
 */
Cypress.Commands.add("getSelect2", selector => {
    return cy.get(selector);
});

/**
 * Helper to clear a Select2 selection
 * Can be used as a standalone command or as part of a chain
 *
 * @param {string} selector - jQuery-like selector for the original select element
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage
 * cy.clearSelect2('#tagSelect');
 *
 * @example
 * // As part of a chain
 * cy.getSelect2('#tagSelect')
 *   .select2({ select: 'Mystery' })
 *   .clearSelect2('#tagSelect')
 *   .select2({ select: 'Fantasy' });
 */
Cypress.Commands.add("clearSelect2", selector => {
    return cy.getSelect2(selector).select2({ clearSelection: true });
});

/**
 * Helper to search in a Select2 dropdown without making a selection
 * Useful for testing search functionality or as part of a multi-step interaction
 *
 * @param {string} selector - jQuery-like selector for the original select element
 * @param {string} searchText - Text to search for
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Standalone usage to test search functionality
 * cy.searchSelect2('#authorSelect', 'Gaiman');
 *
 * @example
 * // Chained with selection - more reliable for AJAX Select2s
 * cy.getSelect2('#publisherSelect')
 *   .searchSelect2('#publisherSelect', "O'Reilly")
 *   .wait(500) // Allow time for AJAX results
 *   .select2({ selectIndex: 0 });
 */
Cypress.Commands.add("searchSelect2", (selector, searchText) => {
    return cy.getSelect2(selector).select2({ search: searchText });
});

/**
 * Helper to select an option in a Select2 dropdown by text
 * Combines search and select in one command, but can be less reliable for AJAX Select2s
 *
 * @param {string} selector - jQuery-like selector for the original select element
 * @param {string|Object} selectText - Text to select or object with matcher options
 * @param {string} [searchText=null] - Optional text to search for before selecting
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Basic usage
 * cy.selectFromSelect2('#authorSelect', 'J.R.R. Tolkien');
 *
 * @example
 * // With search text
 * cy.selectFromSelect2('#publisherSelect', 'O\'Reilly Media', 'O\'Reilly');
 *
 * @example
 * // Using advanced matching options
 * cy.selectFromSelect2('#bookSelect',
 *   { text: 'The Hobbit', matchType: 'exact' },
 *   'Hobbit'
 * );
 *
 * @example
 * // Chainable with other Cypress commands
 * cy.selectFromSelect2('#categorySelect', 'Fiction')
 *   .should('have.value', 'fiction')
 *   .and('be.visible');
 */
Cypress.Commands.add(
    "selectFromSelect2",
    (selector, selectText, searchText = null) => {
        return cy.getSelect2(selector).select2({
            search: searchText,
            select: selectText,
        });
    }
);

/**
 * Helper to select an option in a Select2 dropdown by index
 * Useful when the exact text is unknown or when needing to select a specific item by position
 *
 * @param {string} selector - jQuery-like selector for the original select element
 * @param {number} index - Index of the option to select (0-based)
 * @param {string} [searchText=null] - Optional text to search for before selecting
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Select the first item in dropdown
 * cy.selectFromSelect2ByIndex('#categorySelect', 0);
 *
 * @example
 * // Search first, then select by index
 * cy.selectFromSelect2ByIndex('#bookSelect', 2, 'Fiction');
 *
 * @example
 * // Chain with assertions
 * cy.selectFromSelect2ByIndex('#authorSelect', 0)
 *   .should('not.have.value', '')
 *   .and('be.visible');
 */
Cypress.Commands.add(
    "selectFromSelect2ByIndex",
    (selector, index, searchText = null) => {
        return cy.getSelect2(selector).select2({
            search: searchText,
            selectIndex: index,
        });
    }
);

/**
 * Helper to select an option in a Select2 dropdown using a custom matcher function
 * Most flexible option for complex Select2 structures with nested elements or specific attributes
 *
 * @param {string} selector - jQuery-like selector for the original select element
 * @param {Function} matcherFn - Custom function to match against option content
 * @param {string} [searchText=null] - Optional text to search for before selecting
 * @returns {Cypress.Chainable} - Returns a chainable Cypress object for further commands
 *
 * @example
 * // Select option with specific data attribute
 * cy.selectFromSelect2WithMatcher('#bookSelect',
 *   (option) => option.element.hasAttribute('data-special') &&
 *               option.text.includes('Special Edition'),
 *   'Lord of the Rings'
 * );
 *
 * @example
 * // Select option that contains both title and author
 * cy.selectFromSelect2WithMatcher('#bookSelect',
 *   (option) => option.text.includes('Tolkien') && option.text.includes('Hobbit'),
 *   'Tolkien'
 * );
 *
 * @example
 * // Chain with other commands
 * cy.selectFromSelect2WithMatcher('#publisherSelect',
 *   (option) => option.html.includes('<em>Premium</em>'),
 *   'Premium'
 * ).then(() => {
 *   cy.get('#premium-options').should('be.visible');
 * });
 */
Cypress.Commands.add(
    "selectFromSelect2WithMatcher",
    (selector, matcherFn, searchText = null) => {
        return cy.getSelect2(selector).select2({
            search: searchText,
            matcher: matcherFn,
        });
    }
);
