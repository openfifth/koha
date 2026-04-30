/**
 * Koha Cypress Testing Data Insertion Utilities
 *
 * This module provides functions to create and manage test data for Cypress tests.
 * It handles creating complete bibliographic records, patrons, holds, checkouts,
 * and other Koha objects with proper relationships and dependencies.
 *
 * @module insertData
 */

const dayjs = require("dayjs");
const { buildSampleObject, buildSampleObjects } = require("./mockData.js");
const { query } = require("./db.js");

const { apiGet, apiPost } = require("./api-client.js");

/**
 * Creates a complete bibliographic record with associated items and libraries.
 *
 * @async
 * @function insertSampleBiblio
 * @param {Object} params - Configuration parameters
 * @param {number} params.item_count - Number of items to create for this biblio
 * @param {Object} [params.options] - Additional options
 * @param {boolean} [params.options.different_libraries] - If true, creates different libraries for each item
 * @param {string} params.baseUrl - Base URL for API calls
 * @param {string} params.authHeader - Authorization header for API calls
 * @returns {Promise<Object>} Created biblio with items, libraries, and item_type
 * @returns {Object} returns.biblio - The created bibliographic record
 * @returns {Array<Object>} returns.items - Array of created item records
 * @returns {Array<Object>} returns.libraries - Array of created library records
 * @returns {Object} returns.item_type - The created item type record
 * @example
 * // Create a biblio with 3 items using the same library
 * const result = await insertSampleBiblio({
 *   item_count: 3,
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 *
 * @example
 * // Create a biblio with 2 items using different libraries
 * const result = await insertSampleBiblio({
 *   item_count: 2,
 *   options: { different_libraries: true },
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 */
const insertSampleBiblio = async ({
    item_count,
    options,
    baseUrl,
    authHeader,
}) => {
    const generatedItemType = await buildSampleObject({ object: "item_type" });
    const item_type = await insertObject({
        type: "item_type",
        object: generatedItemType,
        baseUrl,
        authHeader,
    });

    let title = "Some boring read";
    let author = "Some boring author";
    let biblio = {
        leader: "     nam a22     7a 4500",
        fields: [
            { "005": "20250120101920.0" },
            {
                245: {
                    ind1: "",
                    ind2: "",
                    subfields: [{ a: title }],
                },
            },
            {
                100: {
                    ind1: "",
                    ind2: "",
                    subfields: [{ c: author }],
                },
            },
            {
                942: {
                    ind1: "",
                    ind2: "",
                    subfields: [{ c: item_type.item_type_id }],
                },
            },
        ],
    };
    let result = await apiPost({
        endpoint: "/api/v1/biblios",
        headers: {
            "Content-Type": "application/marc-in-json",
            "x-confirm-not-duplicate": 1,
        },
        body: biblio,
        baseUrl,
        authHeader,
    });
    const biblio_id = result.id;
    // We do not have a route to get a biblio as it is stored in DB
    // We might need to refine that in the future
    biblio = {
        biblio_id,
        title,
        author,
    };

    let items = buildSampleObjects({
        object: "item",
        count: item_count,
        values: {
            biblio_id,
            lost_status: 0,
            withdrawn: 0,
            damaged_status: 0,
            not_for_loan_status: 0,
            restricted_status: 0,
            new_status: null,
            issues: 0,
            checked_out_date: null,
            item_type_id: item_type.item_type_id,
        },
    });
    items = items.map(
        ({
            item_id,
            checkout,
            transfer,
            lost_date,
            withdrawn_date,
            damaged_date,
            course_item,
            _strings,
            biblio,
            bundle_host,
            item_group_item,
            recall,
            return_claim,
            return_claims,
            serial_item,
            first_hold,
            checkouts_count,
            renewals_count,
            holds_count,
            bundle_items_lost_count,
            analytics_count,
            effective_not_for_loan_status,
            effective_item_type_id,
            home_library,
            holding_library,
            bundle_items_not_lost_count,
            item_type,
            _status,
            effective_bookable,
            in_bundle,
            cover_image_ids,
            localuse,
            ...rest
        }) => rest
    );
    let createdItems = [];
    let libraries = [];
    let commonLibrary;
    if (!options || !options.different_libraries) {
        const generatedLibrary = await buildSampleObject({ object: "library" });
        commonLibrary = await insertObject({
            type: "library",
            object: generatedLibrary,
            baseUrl,
            authHeader,
        });
        libraries.push(commonLibrary);
    }
    for (const item of items) {
        if (options?.different_libraries) {
            const generatedLibrary = await buildSampleObject({
                object: "library",
            });
            const library = await insertObject({
                type: "library",
                object: generatedLibrary,
                baseUrl,
                authHeader,
            });
            libraries.push(library);
            item.home_library_id = library.library_id;
            item.holding_library_id = library.library_id;
        } else {
            item.home_library_id = commonLibrary.library_id;
            item.holding_library_id = commonLibrary.library_id;
        }

        await apiPost({
            endpoint: `/api/v1/biblios/${biblio_id}/items`,
            body: item,
            baseUrl,
            authHeader,
        }).then(i => createdItems.push(i));
    }
    return { biblio, items: createdItems, libraries, item_type };
};

/**
 * Creates a hold request for a bibliographic record or item.
 *
 * @async
 * @function insertSampleHold
 * @param {Object} params - Configuration parameters
 * @param {Object} [params.item] - Item to place hold on (optional if biblio provided)
 * @param {Object} [params.biblio] - Biblio to place hold on (optional if item provided)
 * @param {string} [params.library_id] - Library ID for pickup location (defaults to item's home library)
 * @param {string} params.baseUrl - Base URL for API calls
 * @param {string} params.authHeader - Authorization header for API calls
 * @returns {Promise<Object>} Created hold with associated patron and patron_category
 * @returns {Object} returns.hold - The created hold record
 * @returns {Object} returns.patron - The patron who placed the hold
 * @returns {Object} returns.patron_category - The patron's category
 * @throws {Error} When neither library_id nor item is provided
 * @example
 * // Create a hold on a specific item
 * const holdResult = await insertSampleHold({
 *   item: { item_id: 123, home_library_id: 'CPL' },
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 *
 * @example
 * // Create a biblio-level hold
 * const holdResult = await insertSampleHold({
 *   biblio: { biblio_id: 456 },
 *   library_id: 'CPL',
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 */
const insertSampleHold = async ({
    item,
    biblio,
    library_id,
    baseUrl,
    authHeader,
}) => {
    library_id ||= item?.home_library_id;

    if (!library_id) {
        throw new Error(
            "Could not generate sample hold without library_id or item"
        );
    }

    const { patron, patron_category } = await insertSamplePatron({
        library: { library_id },
        baseUrl,
        authHeader,
    });

    const generatedHold = buildSampleObject({
        object: "hold",
        values: {
            patron_id: patron.patron_id,
            biblio_id: item?.biblio_id || biblio.biblio_id,
            pickup_library_id: library_id,
            item_id: item?.item_id || null,
        },
    });
    const hold = await insertObject({
        type: "hold",
        object: generatedHold,
        baseUrl,
        authHeader,
    });
    return { hold, patron, patron_category };
};

/**
 * Creates a checkout record with associated biblio, item, and optional patron.
 *
 * @async
 * @function insertSampleCheckout
 * @param {Object} params - Configuration parameters
 * @param {Object} [params.patron] - Existing patron to check out to (creates new if not provided)
 * @param {string} params.baseUrl - Base URL for API calls
 * @param {string} params.authHeader - Authorization header for API calls
 * @returns {Promise<Object>} Created checkout with all associated records
 * @returns {Object} returns.biblio - The bibliographic record
 * @returns {Array<Object>} returns.items - Array of item records
 * @returns {Array<Object>} returns.libraries - Array of library records
 * @returns {Object} returns.item_type - The item type record
 * @returns {Object} returns.checkout - The checkout record
 * @returns {Object} [returns.patron] - The patron record (if generated)
 * @returns {Object} [returns.patron_category] - The patron category (if generated)
 * @example
 * // Create a checkout with a new patron
 * const checkoutResult = await insertSampleCheckout({
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 *
 * @example
 * // Create a checkout for an existing patron
 * const checkoutResult = await insertSampleCheckout({
 *   patron: { patron_id: 123 },
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 */
const insertSampleCheckout = async ({ patron, baseUrl, authHeader }) => {
    const { biblio, items, libraries, item_type } = await insertSampleBiblio({
        item_count: 1,
        baseUrl,
        authHeader,
    });

    let generatedPatron;
    let patronCategory;
    if (!patron) {
        generatedPatron = true;
        const patron_objects = await insertSamplePatron({
            library: { library_id: libraries[0].library_id },
            baseUrl,
            authHeader,
        });
        generatedCategory = patron_objects.category;
        patron = patron_objects.patron;
    }

    const generatedCheckout = buildSampleObject({
        object: "checkout",
        values: {
            patron_id: patron.patron_id,
            item_id: items[0].item_id,
        },
    });
    delete generatedCheckout.external_id;
    const checkout = await insertObject({
        type: "checkout",
        object: generatedCheckout,
        baseUrl,
        authHeader,
    });
    return {
        biblio,
        items,
        libraries,
        item_type,
        checkout,
        ...(generatedPatron
            ? {
                  patron,
                  patron_category: generatedCategory,
              }
            : {}),
    };
};

/**
 * Creates a patron record with associated library and category.
 *
 * @async
 * @function insertSamplePatron
 * @param {Object} params - Configuration parameters
 * @param {Object} [params.library] - Library to assign patron to (creates new if not provided)
 * @param {Object} [params.patron_category] - Patron category to assign (creates new if not provided)
 * @param {string} params.baseUrl - Base URL for API calls
 * @param {string} params.authHeader - Authorization header for API calls
 * @returns {Promise<Object>} Created patron with associated records
 * @returns {Object} returns.patron - The created patron record
 * @returns {Object} [returns.library] - The library record (if generated)
 * @returns {Object} [returns.patron_category] - The patron category record (if generated)
 * @example
 * // Create a patron with new library and category
 * const patronResult = await insertSamplePatron({
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 *
 * @example
 * // Create a patron for an existing library
 * const patronResult = await insertSamplePatron({
 *   library: { library_id: 'CPL' },
 *   baseUrl: 'http://localhost:8081',
 *   authHeader: 'Basic dGVzdDp0ZXN0'
 * });
 */
const insertSamplePatron = async ({
    library,
    patron_category,
    baseUrl,
    authHeader,
}) => {
    let generatedLibrary;
    let generatedCategory;
    if (!library) {
        generatedLibrary = await buildSampleObject({ object: "library" });
        library = await insertLibrary({
            library: generatedLibrary,
            baseUrl,
            authHeader,
        });
    }
    if (!patron_category) {
        generatedCategory = await buildSampleObject({
            object: "patron_category",
        });
        query({
            sql: "INSERT INTO categories(categorycode, description) VALUES (?, ?)",
            values: [
                generatedCategory.patron_category_id,
                `description for ${generatedCategory.patron_category_id}`,
            ],
        });
        // FIXME We need /patron_categories/:patron_category_id
        await apiGet({
            endpoint: `/api/v1/patron_categories?q={"me.patron_category_id":"${generatedCategory.patron_category_id}"}`,
            baseUrl,
            authHeader,
        }).then(categories => (patron_category = categories[0]));
    }

    let generatedPatron = await buildSampleObject({
        object: "patron",
        values: {
            library_id: library.library_id,
            category_id: patron_category.patron_category_id,
            incorrect_address: null,
            patron_card_lost: null,
        },
    });

    let {
        patron_id,
        _strings,
        anonymized,
        restricted,
        expired,
        extended_attributes,
        checkouts_count,
        overdues_count,
        account_balance,
        lang,
        login_attempts,
        sms_provider_id,
        ...patron
    } = generatedPatron;
    delete patron.library;

    patron = await apiPost({
        endpoint: `/api/v1/patrons`,
        body: patron,
        baseUrl,
        authHeader,
    });

    return {
        patron,
        ...(generatedLibrary ? { library } : {}),
        ...(generatedCategory ? { patron_category } : {}),
    };
};

/**
 * Deletes test objects from the database in the correct order to respect foreign key constraints.
 *
 * @async
 * @function deleteSampleObjects
 * @param {Object|Array<Object>} allObjects - Object(s) to delete, can be single object or array
 * @returns {Promise<boolean>} True if deletion was successful
 * @description This function handles cleanup of test data by:
 * - Accepting single objects or arrays of objects
 * - Grouping objects by type (holds, checkouts, patrons, items, etc.)
 * - Deleting in dependency order to avoid foreign key violations
 * - Supporting all major Koha object types
 * @example
 * // Delete a single test result
 * await deleteSampleObjects(checkoutResult);
 *
 * @example
 * // Delete multiple test results
 * await deleteSampleObjects([biblioResult, holdResult, checkoutResult]);
 *
 * @example
 * // Delete after creating test data
 * const biblio = await insertSampleBiblio({ item_count: 2, baseUrl, authHeader });
 * const hold = await insertSampleHold({ item: biblio.items[0], baseUrl, authHeader });
 * // ... run tests ...
 * await deleteSampleObjects([biblio, hold]);
 */
const deleteSampleObjects = async allObjects => {
    if (!Array.isArray(allObjects)) {
        allObjects = [allObjects];
    }

    const objectsMap = {
        hold: {
            plural: "holds",
            table: "reserves",
            whereColumn: "reserve_id",
            idField: "hold_id",
        },
        checkout: {
            plural: "checkouts",
            table: "issues",
            whereColumn: "issue_id",
            idField: "checkout_id",
        },
        old_checkout: {
            plural: "old_checkouts",
            table: "old_issues",
            whereColumn: "issue_id",
            idField: "checkout_id",
        },
        basket: {
            plural: "baskets",
            table: "aqbasket",
            whereColumn: "basketno",
            idField: "basket_id",
        },
        vendor: {
            plural: "vendors",
            table: "aqbooksellers",
            whereColumn: "id",
        },
        patron: {
            plural: "patrons",
            table: "borrowers",
            whereColumn: "borrowernumber",
            idField: "patron_id",
        },
        item: {
            plural: "items",
            table: "items",
            whereColumn: "itemnumber",
            idField: "item_id",
        },
        biblio: {
            plural: "biblios",
            table: "biblio",
            whereColumn: "biblionumber",
            idField: "biblio_id",
        },
        library: {
            plural: "libraries",
            table: "branches",
            whereColumn: "branchcode",
            idField: "library_id",
        },
        item_type: {
            plural: "item_types",
            table: "itemtypes",
            whereColumn: "itemtype",
            idField: "item_type_id",
        },
        erm_agreement: {
            plural: "erm_agreements",
            table: "erm_agreements",
            whereColumn: "agreement_id",
        },
        erm_eholdings_title: {
            plural: "erm_eholdings_titles",
            table: "erm_eholdings_titles",
            whereColumn: "title_id",
        },
        allocation: {
            plural: "allocations",
            table: "acq_allocations",
            whereColumn: "allocation_id",
        },
        fund: {
            plural: "funds",
            table: "acq_funds",
            whereColumn: "fund_id",
        },
        ledger: {
            plural: "ledgers",
            table: "acq_ledgers",
            whereColumn: "ledger_id",
        },
        fiscal_period: {
            plural: "fiscal_periods",
            table: "acq_fiscal_periods",
            whereColumn: "fiscal_period_id",
        },
        orderline: {
            plural: "orderlines",
            table: "acq_orderlines",
            whereColumn: "orderline_id",
        },
        orderline_fund_distribution: {
            plural: "orderline_fund_distributions",
            table: "acq_orderline_fund_distributions",
            whereColumn: "orderline_id",
            idField: "orderline_id",
        },
        orderline_manager: {
            plural: "orderline_managers",
            table: "acq_orderline_managers",
            whereColumn: "orderline_id",
            idField: "orderline_id",
        },
        orderline_user: {
            plural: "orderline_users",
            table: "acq_orderline_users",
            whereColumn: "orderline_id",
            idField: "orderline_id",
        },
    };
    // Merge by type
    const mergedObjects = {};
    for (const objects of allObjects) {
        for (const [type, value] of Object.entries(objects)) {
            let plural = objectsMap[type]?.plural || type;
            if (!mergedObjects[plural]) {
                mergedObjects[plural] = [];
            }

            if (Array.isArray(value)) {
                mergedObjects[plural].push(...value);
            } else {
                mergedObjects[plural].push(value);
            }
        }
    }

    const deletionOrder = [
        "holds",
        "checkouts",
        "old_checkouts",
        "baskets",
        "orderline_fund_distributions",
        "orderline_managers",
        "orderline_users",
        "orderlines",
        "vendors",
        "patrons",
        "items",
        "biblios",
        "allocations",
        "funds",
        "ledgers",
        "fiscal_periods",
        "libraries",
        "item_types",
        "erm_agreements",
        "erm_eholdings_titles",
    ];
    const matchTypeToObjectMap = type => {
        const matchingKey = Object.keys(objectsMap).find(
            key => objectsMap[key].plural === type
        );
        return objectsMap[matchingKey];
    };

    for (const type of deletionOrder) {
        if (!mergedObjects[type] || mergedObjects[type].length === 0) {
            continue;
        }

        const objectMap = matchTypeToObjectMap(type);
        if (!objectMap) {
            throw Error(`Not implemented yet: cannot delete object '${type}'`);
        }
        const objects = mergedObjects[type];
        let ids = objects.map(
            i =>
                i[
                    objectMap.hasOwnProperty("idField")
                        ? objectMap.idField
                        : objectMap.whereColumn
                ]
        );
        await query({
            sql: `DELETE FROM ${objectMap.table} WHERE ${objectMap.whereColumn} IN (${ids.map(() => "?").join(",")})`,
            values: ids,
        });
    }
    return true;
};

/**
 * Creates a library record via API, filtering out unsupported fields.
 *
 * @async
 * @function insertLibrary
 * @param {Object} params - Configuration parameters
 * @param {Object} params.library - Library object to insert
 * @param {string} params.baseUrl - Base URL for API calls
 * @param {string} params.authHeader - Authorization header for API calls
 * @returns {Promise<Object>} Created library record
 * @private
 * @description This is a helper function that removes fields not supported by the API
 * before creating the library record.
 */
const insertLibrary = async ({ library, baseUrl, authHeader }) => {
    const {
        pickup_items,
        smtp_server,
        cash_registers,
        desks,
        library_hours,
        needs_override,
        ...new_library
    } = library;
    return apiPost({
        endpoint: "/api/v1/libraries",
        body: new_library,
        baseUrl,
        authHeader,
    });
};

/**
 * Generic function to insert various types of Koha objects.
 *
 * @async
 * @function insertObject
 * @param {Object} params - Configuration parameters
 * @param {string} params.type - Type of object to insert ('library', 'item_type', 'hold', 'checkout', 'vendor', 'basket')
 * @param {Object} params.object - Object data to insert
 * @param {string} params.baseUrl - Base URL for API calls
 * @param {string} params.authHeader - Authorization header for API calls
 * @returns {Promise<Object|boolean>} Created object or true if successful
 * @throws {Error} When object type is not supported
 * @private
 * @description This is a generic helper function that handles the specifics of creating
 * different types of Koha objects. Each object type may require different field filtering,
 * API endpoints, or database operations.
 *
 * Supported object types:
 * - library: Creates library via API
 * - item_type: Creates item type via database query
 * - hold: Creates hold via API
 * - checkout: Creates checkout via API with confirmation token support
 * - vendor: Creates vendor via API
 * - basket: Creates basket via database query
 */
const insertObject = async ({ type, object, baseUrl, authHeader }) => {
    if (type == "library") {
        const keysToKeep = ["library_id", "name"];
        const library = Object.fromEntries(
            Object.entries(object).filter(([key]) => keysToKeep.includes(key))
        );
        return apiPost({
            endpoint: "/api/v1/libraries",
            body: library,
            baseUrl,
            authHeader,
        });
    } else if (type == "item_type") {
        const keysToKeep = ["item_type_id", "description"];
        const item_type = Object.fromEntries(
            Object.entries(object).filter(([key]) => keysToKeep.includes(key))
        );
        return query({
            sql: "INSERT INTO itemtypes(itemtype, description) VALUES (?, ?)",
            values: [item_type.item_type_id, item_type.description],
        })
            .then(result => {
                // FIXME We need /item_types/:item_type_id
                return apiGet({
                    endpoint: `/api/v1/item_types?q={"item_type_id":"${item_type.item_type_id}"}`,
                    baseUrl,
                    authHeader,
                });
            })
            .then(item_types => item_types[0]);
    } else if (type == "hold") {
        const {
            hold_id,
            deleted_biblio_id,
            item_group_id,
            desk_id,
            cancellation_date,
            cancellation_reason,
            notes,
            priority,
            status,
            timestamp,
            waiting_date,
            expiration_date,
            lowest_priority,
            suspended,
            suspended_until,
            non_priority,
            item_type_id,
            _strings,
            hold_group_id,
            item_level,
            cancellation_requested,
            biblio,
            deleted_biblio,
            item,
            pickup_library,
            hold_date,
            patron,
            ...hold
        } = object;

        return apiPost({
            endpoint: `/api/v1/holds`,
            body: hold,
            baseUrl,
            authHeader,
        });
    } else if (type == "checkout") {
        const { issuer, patron, booking, ...checkout } = object;

        let endpoint = "/api/v1/checkouts";
        // Force the checkout - we might need a parameter to control this behaviour later
        await apiGet({
            endpoint: `/api/v1/checkouts/availability?item_id=${object.item_id}&patron_id=${object.patron_id}`,
            baseUrl,
            authHeader,
        }).then(result => {
            if (result.confirmation_token) {
                endpoint += `?confirmation=${result.confirmation_token}`;
            }
        });

        return apiPost({
            endpoint,
            body: checkout,
            baseUrl,
            authHeader,
        });
    } else if (type == "vendor") {
        const {
            id,
            baskets_count,
            invoices_count,
            subscriptions_count,
            external_id,
            aliases,
            baskets,
            contacts,
            contracts,
            interfaces,
            invoices,
            list_currency,
            invoice_currency,
            extended_attributes,
            _strings,
            ...vendor
        } = object;

        let endpoint = "/api/v1/acquisitions/vendors";

        return apiPost({
            endpoint,
            body: vendor,
            baseUrl,
            authHeader,
        });
    } else if (type == "basket") {
        const keysToKeep = ["name", "vendor_id", "close_date"];
        const basket = Object.fromEntries(
            Object.entries(object).filter(([key]) => keysToKeep.includes(key))
        );
        return query({
            sql: "INSERT INTO aqbasket(basketname, booksellerid, closedate) VALUES (?, ?, ?)",
            values: [basket.name, basket.vendor_id, basket.close_date],
        })
            .then(result => {
                const basket_id = result.insertId;
                // FIXME We need /acquisitions/baskets/:basket_id
                return apiGet({
                    endpoint: `/api/v1/acquisitions/baskets?q={"basket_id":"${basket_id}"}`,
                    baseUrl,
                    authHeader,
                });
            })
            .then(baskets => baskets[0]);
    } else if (type === "erm_agreement") {
        const {
            agreement_id,
            _strings,
            periods,
            user_roles,
            agreement_relationships,
            agreement_licenses,
            documents,
            extended_attributes,
            vendor,
            ...erm_agreement
        } = object;
        if (typeof periods[0] !== "string") {
            erm_agreement.periods = periods;
        }
        return apiPost({
            endpoint: "/api/v1/erm/agreements",
            body: erm_agreement,
            baseUrl,
            authHeader,
        });
    } else if (type === "erm_eholdings_title") {
        const {
            title_id,
            biblio_id,
            create_linked_biblio,
            is_selected,
            resources,
            ...erm_eholdings_title
        } = object;
        return apiPost({
            endpoint: "/api/v1/erm/eholdings/local/titles",
            body: erm_eholdings_title,
            baseUrl,
            authHeader,
        });
    } else {
        throw Error(`Unsupported object type '${type}' to insert`);
    }

    return true;
};

const insertSampleFiscalPeriod = async ({
    fiscal_period: overrides = {},
    baseUrl,
    authHeader,
} = {}) => {
    const generated = await buildSampleObject({
        object: "acq_fiscal_period",
        values: {
            status: true,
            start_date: dayjs().format("YYYY-MM-DD"),
            end_date: dayjs().add(1, "day").format("YYYY-MM-DD"),
            managing_branch: null,
            owner_id: null,
            ...overrides,
        },
    });

    const {
        fiscal_period_id,
        modified_date,
        created_date,
        ledgers,
        funds,
        owner,
        managing_library,
        child_object_managing_branches,
        ...body
    } = generated;

    const fiscal_period = await apiPost({
        endpoint: "/api/v1/acquisitions/fiscal_periods",
        body,
        baseUrl,
        authHeader,
    });

    return { fiscal_period };
};

const insertSampleLedger = async ({
    fiscal_period,
    ledger: overrides = {},
    baseUrl,
    authHeader,
} = {}) => {
    let generatedFiscalPeriod;
    if (!fiscal_period) {
        const result = await insertSampleFiscalPeriod({ baseUrl, authHeader });
        fiscal_period = result.fiscal_period;
        generatedFiscalPeriod = true;
    }

    // currency is NOT NULL in DB so we must provide a valid value
    const currencies = await query({
        sql: "SELECT currency FROM currency WHERE active=1 LIMIT 1",
    });
    const currency = currencies[0]?.currency || "USD";

    const generated = await buildSampleObject({
        object: "acq_ledger",
        values: {
            fiscal_period_id: fiscal_period.fiscal_period_id,
            status: true,
            locked: false,
            currency,
            ledger_amount: 10000,
            managing_branch: null,
            owner_id: null,
            ...overrides,
        },
    });

    const {
        ledger_id,
        modified_date,
        created_date,
        fiscal_period: _fiscal_period,
        funds,
        owner,
        managing_library,
        allocations,
        child_object_managing_branches,
        ...body
    } = generated;

    const ledger = await apiPost({
        endpoint: "/api/v1/acquisitions/ledgers",
        body,
        baseUrl,
        authHeader,
    });

    return {
        ledger,
        ...(generatedFiscalPeriod ? { fiscal_period } : {}),
    };
};

const insertSampleFund = async ({
    ledger,
    fund: overrides = {},
    baseUrl,
    authHeader,
} = {}) => {
    let generatedLedger;
    let fiscal_period;
    let generatedFiscalPeriod;
    if (!ledger) {
        const result = await insertSampleLedger({ baseUrl, authHeader });
        ledger = result.ledger;
        generatedLedger = true;
        if (result.fiscal_period) {
            fiscal_period = result.fiscal_period;
            generatedFiscalPeriod = true;
        }
    }

    const generated = await buildSampleObject({
        object: "acq_fund",
        values: {
            ledger_id: ledger.ledger_id,
            parent_fund_id: null,
            status: true,
            fund_amount: 5000,
            managing_branch: null,
            owner_id: null,
            fund_permission: 0,
            fund_type: null,
            ...overrides,
        },
    });

    // code column is varchar(30)
    if (generated.code && generated.code.length > 30) {
        generated.code = generated.code.slice(0, 30);
    }

    const {
        fund_id,
        modified_date,
        created_date,
        fiscal_period: _fiscal_period,
        ledger: _ledger,
        allocations,
        sub_funds,
        owner,
        managing_library,
        parent_fund,
        child_object_managing_branches,
        currency,
        ...body
    } = generated;

    const fund = await apiPost({
        endpoint: "/api/v1/acquisitions/funds",
        body,
        baseUrl,
        authHeader,
    });

    return {
        fund,
        ...(generatedLedger ? { ledger } : {}),
        ...(generatedFiscalPeriod ? { fiscal_period } : {}),
    };
};

const insertSampleVendor = async ({
    vendor: overrides = {},
    baseUrl,
    authHeader,
} = {}) => {
    const generated = await buildSampleObject({
        object: "vendor",
        values: { active: 1, ...overrides },
    });
    const vendor = await insertObject({
        type: "vendor",
        object: generated,
        baseUrl,
        authHeader,
    });
    return { vendor };
};

const insertSampleOrderline = async ({
    vendor,
    fund,
    orderline: overrides = {},
    baseUrl,
    authHeader,
} = {}) => {
    let generatedVendor = false;
    let fundResult = {};

    if (!vendor) {
        generatedVendor = true;
        const result = await insertSampleVendor({ baseUrl, authHeader });
        vendor = result.vendor;
    }
    if (!fund) {
        fundResult = await insertSampleFund({ baseUrl, authHeader });
        fund = fundResult.fund;
    }

    const biblioResult = await insertSampleBiblio({
        item_count: 1,
        baseUrl,
        authHeader,
    });
    const managedByPatron = await insertSamplePatron({
        library: biblioResult.libraries[0],
        baseUrl,
        authHeader,
    });
    const notifyPatron = await insertSamplePatron({
        library: biblioResult.libraries[0],
        baseUrl,
        authHeader,
    });

    const orderline = await apiPost({
        endpoint: "/api/v1/acquisitions/orderlines",
        headers: { "x-confirm-not-duplicate": "1" },
        body: {
            vendor_id: vendor.id,
            biblionumber: biblioResult.biblio.biblio_id,
            managing_branch: biblioResult.libraries[0].library_id,
            managed_by: [{ borrowernumber: managedByPatron.patron.patron_id }],
            patrons_to_notify: [
                { borrowernumber: notifyPatron.patron.patron_id },
            ],
            vendor_price: 25.0,
            is_continuous: false,
            renewal_required: false,
            uncertain_price: true,
            urgent_order: true,
            create_items: "cataloging",
            quantity_ordered: 3,
            discount_percentage: 10,
            replacement_price: 30.0,
            internal_note: "Test internal note",
            receiving_note: "Test receiving note",
            vendor_note: "Test vendor note",
            statistic1: "STAT1",
            statistic2: "STAT2",
            estimated_delivery_date: "2026-12-31",
            fund_distributions: [
                {
                    fund_id: fund.fund_id,
                    percentage: 100,
                    exchange_rate: 1,
                    tax_rate: 0,
                    distributed_amount_oc: 25,
                    distributed_amount: 25,
                    tax_value: 0,
                    distributed_amount_tax_excluded: 0,
                    distributed_amount_tax_included: 0,
                },
            ],
            items: [],
            ...overrides,
        },
        baseUrl,
        authHeader,
    });

    return {
        orderline,
        orderline_fund_distribution: orderline,
        orderline_manager: orderline,
        orderline_user: orderline,
        ...(generatedVendor ? { vendor } : {}),
        ...fundResult,
        biblio: biblioResult.biblio,
        items: biblioResult.items,
        libraries: biblioResult.libraries,
        item_type: biblioResult.item_type,
        patrons: [managedByPatron.patron, notifyPatron.patron],
    };
};

const insertSampleAllocation = async ({
    fund,
    ledger,
    allocation: overrides = {},
    baseUrl,
    authHeader,
} = {}) => {
    const generated = await buildSampleObject({
        object: "acq_allocation",
        values: {
            fund_id: fund?.fund_id ?? null,
            ledger_id: ledger?.ledger_id ?? null,
            type: "INCREASE",
            is_transferred_to: null,
            is_transferred_from: null,
            owner_id: null,
            managing_branch: null,
            ...overrides,
        },
    });

    generated.allocation_amount = Math.abs(generated.allocation_amount) || 100;

    const {
        allocation_id,
        created_date,
        ledger: _ledger,
        fund: _fund,
        owner,
        managing_branch,
        owner_id,
        ...body
    } = generated;

    const allocation = await apiPost({
        endpoint: "/api/v1/acquisitions/allocations",
        body,
        baseUrl,
        authHeader,
    });

    return { allocation };
};

module.exports = {
    insertSampleBiblio,
    insertSampleHold,
    insertSampleCheckout,
    insertSamplePatron,
    insertSampleFiscalPeriod,
    insertSampleLedger,
    insertSampleFund,
    insertSampleAllocation,
    insertSampleVendor,
    insertSampleOrderline,
    insertObject,
    deleteSampleObjects,
};
