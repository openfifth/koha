/**
 * Bug 43127 - Vue "Place a hold" page (biblio-level express hold).
 *
 * Uses real seeded data (patron/biblio/item/circulation rules) throughout,
 * matching bookingsModalBasic_spec.ts's convention for this folder. A
 * cy.intercept() is only used where real data genuinely can't force the
 * scenario: forcing a POST /holds failure, and adding an artificial delay
 * to make the holdability cache's two-phase paint observable.
 *
 * Ground truth notes (see the accompanying plan for full source citations):
 * - Item-level blockers never reach this page's blocked-reasons list - the
 *   biblio-level check collapses every per-item failure into just
 *   "No item on this record can fill a hold" / "This record has no items".
 *   Only patron-level blockers (card_lost, debt_limit, hold_limit, etc.)
 *   render their specific label here.
 * - Blocker <li> order is a Perl hash iteration order - never assert by
 *   position, only by full-list membership.
 * - Two bootstrap calls (AllowHoldPolicyOverride syspref, HOLD_CANCELLATION
 *   authorised values) gate the whole app behind Main.vue's
 *   v-if="initialized" - every test waits for both before asserting content.
 * - Known, pre-existing quirks worked around rather than hidden:
 *   - `PlaceHold.vue` passes id="place-hold-patron" but PatronAutoComplete
 *     never binds it to the actual <input> - use input.patron-search-input.
 *   - patron.branchname doesn't exist in the patron API response, so the
 *     pickup-library select's default option has an empty label until the
 *     dropdown is opened - never asserted on before that.
 *
 * Tests that need AllowHoldPolicyOverride at a specific value are grouped
 * into "with AllowHoldPolicyOverride on/off" blocks below for readability.
 * Each still sets it via its own setPrefOnce() call rather than a
 * block-level before() - see the comment on setPrefOnce() for why (test
 * isolation clears cookies before a describe's own before() too, so it
 * can't rely on reusing a previous test's session).
 */

const dayjs = require("dayjs");

const PLACE_HOLD_PATH = "/cgi-bin/koha/reserve/request.pl";

describe("Place a hold (bib-level, UseNewHoldsInterface)", () => {
    let testData = {};
    let originalPrefs = {};

    // C4::Context->preference() is backed by a per-worker in-process L1
    // cache on top of the shared Memcached one (Koha/Cache.pm's
    // %L1_cache) - a raw `UPDATE systempreferences` updates the DB and
    // the shared cache but never touches the *already-running* app
    // server's own L1, so it keeps serving the stale value.
    // cy.set_syspref() (an existing command, used the same way by
    // FineNoRenewals_spec.ts in this folder) goes through the real app,
    // so the worker that serves *that* request invalidates its own L1 -
    // but with more than one Starman worker (KTD runs 2) and no
    // guaranteed session affinity, a later request (this page's own
    // bootstrap fetch of the same pref) may land on a different worker
    // that never saw the update. Each real HTTP round trip is a chance to
    // hit the wrong worker, so tests are grouped by the pref value they
    // need (below) to keep the total number of these round trips as low
    // as it can be, rather than one per test. See reloadUntil() below for
    // how the one assertion still exposed to the race guards against it.
    //
    // Cypress's default test isolation clears cookies before every test
    // (including before a describe block's own before() hook, which runs
    // as part of "getting ready" for its first test) - so a describe-level
    // before() can't rely on a previous test's login still being active,
    // and doing its own extra cy.login() there just reintroduces a second
    // login racing the current test's own beforeEach login. Instead, each
    // grouped test calls setPrefOnce() itself, right where cy.set_syspref()
    // would otherwise go - it's a no-op after the first call for a given
    // variable+value this run, so the group still only pays for the real
    // HTTP round trip once, but always from inside an already-logged-in
    // test rather than a separate hook lifecycle stage.
    const prefsSetThisRun = new Set();
    const setPrefOnce = (variable, value) => {
        const key = `${variable}=${value}`;
        if (prefsSetThisRun.has(key)) return;
        prefsSetThisRun.add(key);
        cy.set_syspref(variable, value);
    };

    // Guards against the cross-worker staleness cy.set_syspref() can't rule
    // out on its own: reloads the current page (a cheap way to try a fresh
    // backend connection, which may land on a different worker) until
    // `check` passes or attempts run out, rather than trusting the first
    // page load actually got the post-setPrefOnce value.
    const reloadUntil = (check, attemptsLeft = 5) => {
        cy.get("body").then($body => {
            if (check($body) || attemptsLeft <= 0) return;
            cy.reload();
            waitForBootstrap();
            reloadUntil(check, attemptsLeft - 1);
        });
    };

    const capturePref = variable =>
        cy
            .task("query", {
                sql: "SELECT value FROM systempreferences WHERE variable = ?",
                values: [variable],
            })
            .then(rows => {
                originalPrefs[variable] = rows.length ? rows[0].value : null;
            });

    const MANAGED_PREFS = [
        "UseNewHoldsInterface",
        "AllowHoldPolicyOverride",
        "AllowHoldsOnDamagedItems",
        "UseBranchTransferLimits",
        "BranchTransferLimitsType",
    ];

    // Capture/restore once for the whole suite, not per test: cy.set_syspref
    // is a real HTTP round trip, and before()/after() themselves have
    // nothing that reads a pref back within the same test, so plain SQL is
    // fine here - RESTBasicAuth already relies on exactly that in the
    // sibling bookingsModalBasic_spec.ts - and it also avoids an extra
    // cy.login() immediately before beforeEach's own, which was
    // intermittently racing into a stale-CSRF-token 403 on the login form.
    before(() => {
        cy.task("query", {
            sql: "UPDATE systempreferences SET value = '1' WHERE variable = 'RESTBasicAuth'",
        });
        cy.wrap(MANAGED_PREFS)
            .each(pref => capturePref(pref))
            .then(() =>
                cy.task("query", {
                    sql: `INSERT INTO systempreferences (variable, value)
                          VALUES ('UseNewHoldsInterface', '1')
                          ON DUPLICATE KEY UPDATE value = '1'`,
                })
            );
    });

    after(() => {
        cy.wrap(MANAGED_PREFS).each(pref => {
            const original = originalPrefs[pref];
            if (typeof original === "undefined" || original === null) {
                return cy.task("query", {
                    sql: "DELETE FROM systempreferences WHERE variable = ?",
                    values: [pref],
                });
            }
            return cy.task("query", {
                sql: "UPDATE systempreferences SET value = ? WHERE variable = ?",
                values: [original, pref],
            });
        });
    });

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.task("insertSampleBiblio", { item_count: 2 })
            .then(objects => {
                testData = objects;
                return cy.task("insertSamplePatron", {
                    library: testData.libraries[0],
                    patronValues: {
                        surname: "Holdtest",
                        firstname: "Patron",
                        cardnumber: `PH${Date.now()}`,
                        expiry_date: "2099-12-31",
                        incorrect_address: null,
                        patron_card_lost: null,
                    },
                });
            })
            .then(patronResult => {
                testData.patron = patronResult.patron;
                // insertSamplePatron generates a fresh patron_category
                // when none is passed in (as here) - keep it on testData
                // so afterEach's deleteSampleObjects(testData) actually
                // cleans it up, instead of leaking one category per test.
                testData.patron_category = patronResult.patron_category;

                const itemtype = testData.item_type.item_type_id;
                return cy.task("query", {
                    sql: `INSERT INTO circulation_rules
                            (branchcode, categorycode, itemtype, rule_name, rule_value)
                          VALUES
                            (NULL, NULL, ?, 'reservesallowed', '5'),
                            (NULL, NULL, ?, 'holds_per_record', '2'),
                            (NULL, NULL, ?, 'holdallowed', 'from_any_library'),
                            (NULL, NULL, ?, 'hold_fulfillment_policy', 'any')`,
                    values: [itemtype, itemtype, itemtype, itemtype],
                });
            });
    });

    afterEach(() => {
        if (testData.biblio) {
            cy.task("deleteSampleObjects", testData);
        }
        cy.task("query", {
            sql: "DELETE FROM branch_transfer_limits WHERE fromBranch = ? OR toBranch = ?",
            values: [
                testData.libraries?.[0]?.library_id || "",
                testData.libraries?.[1]?.library_id || "",
            ],
        });
        testData = {};
    });

    const visit = (extraQuery = "") =>
        cy.visit(
            `${PLACE_HOLD_PATH}?biblionumber=${testData.biblio.biblio_id}` +
                `&borrowernumber=${testData.patron.patron_id}${extraQuery}`
        );

    // .holdability-shield only mounts once Main.vue's bootstrap has
    // resolved AND a patron is loaded, so its presence is sufficient proof
    // both have happened - no need to check the two bootstrap requests or
    // the skeleton separately.
    const waitForBootstrap = () => {
        cy.get("#holds", { timeout: 10000 }).should("exist");
        cy.get(".holdability-shield", { timeout: 10000 }).should("exist");
    };

    // The pickup library field is a vue-select (v-select), not select2 -
    // selectFromSelect2 doesn't apply. This opens it and clicks the option
    // whose visible text contains `name`.
    const pickupLibraryRow = () =>
        cy.get(".express-bib-level-hold form fieldset.rows ol li:first-child");

    const selectPickupLibrary = name => {
        pickupLibraryRow().find(".vs__search").click({ force: true });
        pickupLibraryRow().find(".vs__dropdown-menu li").contains(name).click();
    };

    it("places a hold end to end and redirects to the patron's holds tab", () => {
        const expirationDate = dayjs().add(14, "day").format("YYYY-MM-DD");

        visit();
        waitForBootstrap();

        cy.get("h1").should(
            "have.text",
            `Place a hold on ${testData.biblio.title}`
        );
        cy.get(".express-bib-level-hold h2.card-title").should(
            "have.text",
            testData.biblio.title
        );
        cy.get(".holdability-shield .placeholder-glow").should("not.exist");
        cy.get(".express-bib-level-hold button[type=submit]").should("exist");

        cy.get("#expiration_date").selectFlatpickrDate(expirationDate);
        cy.get("#notes").type("Cypress hold note");

        cy.intercept("POST", "/api/v1/holds").as("createHold");

        cy.get(".express-bib-level-hold button.btn.btn-primary[type=submit]")
            .should("contain.text", "Place hold")
            .click();

        cy.wait("@createHold").then(({ request, response }) => {
            expect(request.body).to.deep.equal({
                patron_id: testData.patron.patron_id,
                biblio_id: testData.biblio.biblio_id,
                pickup_library_id: testData.libraries[0].library_id,
                expiration_date: expirationDate,
                notes: "Cypress hold note",
            });
            expect(request.headers).to.not.have.property("x-koha-override");
            expect(response.statusCode).to.eq(201);
        });

        cy.get(".express-bib-level-hold .toast.show .toast-body").should(
            "have.text",
            "Queue position: #1"
        );

        cy.location("pathname", { timeout: 6000 }).should(
            "eq",
            "/cgi-bin/koha/members/moremember.pl"
        );
        cy.location("search").should(
            "eq",
            `?borrowernumber=${testData.patron.patron_id}`
        );
        cy.location("hash").should("eq", "#holds");
    });

    it("shows the item/queue summary line with correct counts", () => {
        // beforeEach seeded 2 items. Damage one (so it's counted but not
        // holdable) and add an existing hold (so priority isn't just 1),
        // so the numbers are meaningfully different from the trivial case.
        cy.set_syspref("AllowHoldsOnDamagedItems", "0");

        cy.task("query", {
            sql: "UPDATE items SET damaged = 1 WHERE itemnumber = ?",
            values: [testData.items[1].item_id],
        })
            .then(() =>
                cy.task("insertSampleHold", {
                    biblio: testData.biblio,
                    library_id: testData.libraries[0].library_id,
                })
            )
            .then(holdResult => {
                testData.hold = holdResult.hold;
                testData.holdPatron = holdResult.patron;
                testData.holdPatronCategory = holdResult.patron_category;
            });

        visit();
        waitForBootstrap();

        cy.get(".holdability-shield p.text-muted").should(
            "have.text",
            "2 item(s), 1 holdable · Queue position: #2"
        );

        cy.then(() =>
            cy
                .task("query", {
                    sql: "DELETE FROM borrowers WHERE borrowernumber = ?",
                    values: [testData.holdPatron.patron_id],
                })
                .then(() =>
                    cy.task("query", {
                        sql: "DELETE FROM categories WHERE categorycode = ?",
                        values: [
                            testData.holdPatronCategory.patron_category_id,
                        ],
                    })
                )
        );
    });

    it("shows the hold fee alert", () => {
        cy.task("query", {
            sql: `INSERT INTO circulation_rules
                    (branchcode, categorycode, itemtype, rule_name, rule_value)
                  VALUES (NULL, NULL, ?, 'hold_fee', '3')`,
            values: [testData.item_type.item_type_id],
        });

        visit();
        waitForBootstrap();

        cy.get(".holdability-shield .alert.alert-info.py-2").should(
            "have.text",
            "A fee of 3.00 applies to this hold."
        );
    });

    describe("with AllowHoldPolicyOverride on", () => {
        // Mixed blockers, not a single non-overridable one, deliberately:
        // the interesting case is proving the "every blocker is overridable"
        // gate - one overridable blocker alongside one that isn't must still
        // leave the form with no way to submit. A single non-overridable
        // blocker wouldn't tell us whether the gate checks "every" or just
        // "some" blocker is overridable; this does.
        it("offers no way to submit when any blocker is not overridable", () => {
            setPrefOnce("AllowHoldPolicyOverride", "1");
            cy.task("query", {
                sql: "UPDATE borrowers SET lost = 1 WHERE borrowernumber = ?",
                values: [testData.patron.patron_id],
            });
            cy.task("query", {
                sql: "UPDATE circulation_rules SET rule_value = '0' WHERE itemtype = ? AND rule_name = 'reservesallowed'",
                values: [testData.item_type.item_type_id],
            });

            visit();
            waitForBootstrap();

            cy.get(".holdability-shield .alert.alert-danger p").should(
                "have.text",
                "This hold cannot be placed:"
            );
            cy.get(".holdability-shield .alert.alert-danger ul li").should(
                $lis => {
                    const texts = [...$lis].map(li => li.textContent);
                    expect(texts).to.have.length(2);
                    expect(texts).to.include(
                        "The patron's card has been reported lost"
                    );
                    expect(texts).to.include(
                        "No item on this record can fill a hold"
                    );
                }
            );
            // The pickup-library field stays reachable while blocked; only
            // the submit button (the only route to placing or overriding
            // the hold) is gated.
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "not.exist"
            );
        });

        it("overrides a blocked hold via the confirm dialog and places it", () => {
            const expirationDate = dayjs().add(14, "day").format("YYYY-MM-DD");

            setPrefOnce("AllowHoldPolicyOverride", "1");
            cy.task("query", {
                sql: "UPDATE borrowers SET lost = 1 WHERE borrowernumber = ?",
                values: [testData.patron.patron_id],
            });

            visit();
            waitForBootstrap();

            // There's only ever one button - "Place hold" - and it's
            // already visible for a blocked-but-overridable hold, since
            // clicking it is how the override confirmation gets triggered
            // in the first place. HoldabilityShield itself renders no
            // button at all any more, just the reasons.
            cy.get(".express-bib-level-hold button[type=submit]")
                .should("exist")
                .and("contain.text", "Place hold");
            cy.get(".holdability-shield .alert.alert-danger ul li")
                .should("have.length", 1)
                .and("have.text", "The patron's card has been reported lost");

            // The expiration date/notes fields must stay reachable while
            // blocked, same as the pickup library field - this is the
            // user's only chance to set them before the override flow
            // (triggered by the same submit button below) places the hold.
            cy.get("#expiration_date").selectFlatpickrDate(expirationDate);
            cy.get("#notes").type("Cypress override note");

            // Cancel path first: no confirmation, no request.
            cy.intercept("POST", "/api/v1/holds").as("createHoldCancelled");
            cy.get(".express-bib-level-hold button[type=submit]").click();
            cy.get("#confirmation.modal").should("be.visible");
            cy.get("#confirmation #close_modal").click();
            // v-if="confirmation" removes the modal from the DOM entirely
            // on cancel, rather than just CSS-hiding it.
            cy.get("#confirmation.modal").should("not.exist");
            cy.get("@createHoldCancelled.all").should("have.length", 0);
            // Cancelling leaves the hold unplaced, with the same button
            // still there to try again.
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "exist"
            );

            // Now confirm.
            cy.intercept("POST", "/api/v1/holds").as("createHold");
            cy.get(".express-bib-level-hold button[type=submit]").click();
            cy.get("#confirmation.modal").should("be.visible");
            cy.get("#confirmation .modal-header h1").should(
                "have.text",
                "Override required"
            );
            cy.get("#confirmation .modal-body ul li")
                .should("have.length", 1)
                .and("have.text", "The patron's card has been reported lost");
            cy.get("#accept_modal").should("contain.text", "Override").click();

            cy.wait("@createHold").then(({ request, response }) => {
                expect(request.headers).to.have.property(
                    "x-koha-override",
                    "card_lost"
                );
                expect(request.body).to.include({
                    expiration_date: expirationDate,
                    notes: "Cypress override note",
                });
                expect(response.statusCode).to.eq(201);
            });

            cy.get(".express-bib-level-hold .toast.show .toast-body").should(
                "have.text",
                "Queue position: #1"
            );
            cy.location("pathname", { timeout: 6000 }).should(
                "eq",
                "/cgi-bin/koha/members/moremember.pl"
            );
        });

        it("re-checks holdability when the pickup library changes", () => {
            setPrefOnce("AllowHoldPolicyOverride", "1");
            cy.set_syspref("UseBranchTransferLimits", "1");
            cy.set_syspref("BranchTransferLimitsType", "itemtype");

            cy.task("buildSampleObject", { object: "library" })
                .then(library =>
                    cy.task("insertObject", {
                        type: "library",
                        object: library,
                    })
                )
                .then(library => {
                    testData.libraries.push(library);
                    return cy.task("query", {
                        sql: `INSERT INTO branch_transfer_limits (toBranch, fromBranch, itemtype)
                              VALUES (?, ?, ?)`,
                        values: [
                            library.library_id,
                            testData.libraries[0].library_id,
                            testData.item_type.item_type_id,
                        ],
                    });
                });

            visit();
            waitForBootstrap();

            // The pickup-library field lives outside the availability
            // gate, but the rest of the form (and the submit button) is
            // still the right proxy for "is this hold placeable right now".
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "exist"
            );

            cy.intercept(
                "GET",
                `/api/v1/biblios/${testData.biblio.biblio_id}/holdability*`
            ).as("holdability");
            cy.then(() => selectPickupLibrary(testData.libraries[1].name));
            // testData.libraries[1] is set by an earlier .then() in this
            // same test - a callback form defers reading it until this
            // actually runs, rather than at enqueue time when it's still
            // undefined.
            cy.wait("@holdability")
                .its("request.url")
                .should(url =>
                    expect(url).to.include(
                        `pickup_library_id=${testData.libraries[1].library_id}`
                    )
                );

            cy.get(".express-bib-level-hold button[type=submit]").should(
                "not.exist"
            );
            cy.get(".holdability-shield .alert.alert-danger ul li").should(
                "have.text",
                "No item on this record can fill a hold"
            );

            // The round trip: the pickup-library field stays reachable
            // while blocked (that's the whole point of the fix), so
            // switching back to the working library must resolve the
            // block and bring the rest of the form back.
            cy.then(() => selectPickupLibrary(testData.libraries[0].name));
            cy.wait("@holdability")
                .its("request.url")
                .should(url =>
                    expect(url).to.include(
                        `pickup_library_id=${testData.libraries[0].library_id}`
                    )
                );
            cy.get(".holdability-shield .alert.alert-danger").should(
                "not.exist"
            );
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "exist"
            );
        });

        it("repaints instantly from cache while revalidating in the background", () => {
            setPrefOnce("AllowHoldPolicyOverride", "1");
            // A single artificial delay on the holdability GET, payload
            // unchanged - the point is to make the skeleton-vs-instant-
            // paint difference observable, not to test a different
            // response shape.
            cy.intercept(
                "GET",
                `/api/v1/biblios/${testData.biblio.biblio_id}/holdability*`,
                req => {
                    req.on("response", res => res.setDelay(1500));
                }
            ).as("holdability");

            cy.task("buildSampleObject", { object: "library" })
                .then(library =>
                    cy.task("insertObject", {
                        type: "library",
                        object: library,
                    })
                )
                .then(library => testData.libraries.push(library));

            visit();
            waitForBootstrap();
            cy.wait("@holdability");
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "exist"
            );

            // Never-seen combo: skeleton must appear.
            cy.then(() => selectPickupLibrary(testData.libraries[1].name));
            cy.get(".holdability-shield .placeholder-glow").should("exist");
            cy.wait("@holdability");

            // Back to a previously-seen combo within the same page load:
            // no skeleton flash, the background revalidation still fires.
            cy.then(() => selectPickupLibrary(testData.libraries[0].name));
            cy.get(".holdability-shield .placeholder-glow").should("not.exist");
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "exist"
            );
            cy.wait("@holdability");
        });
    });

    describe("with AllowHoldPolicyOverride off", () => {
        it("offers no way to submit even for an otherwise-overridable blocker", () => {
            setPrefOnce("AllowHoldPolicyOverride", "0");
            cy.task("query", {
                sql: "UPDATE borrowers SET lost = 1 WHERE borrowernumber = ?",
                values: [testData.patron.patron_id],
            });

            visit();
            waitForBootstrap();

            cy.get(".holdability-shield .alert.alert-danger ul li").should(
                "have.text",
                "The patron's card has been reported lost"
            );
            // A worker other than the one setPrefOnce() just updated may
            // have served this page's own bootstrap fetch of the same
            // pref - retry via reload rather than risk a false failure
            // from that race.
            reloadUntil(
                $body =>
                    $body.find(".express-bib-level-hold button[type=submit]")
                        .length === 0
            );
            cy.get(".express-bib-level-hold button[type=submit]").should(
                "not.exist"
            );
            cy.get("#confirmation.modal").should("not.exist");
        });
    });

    it("selects a patron via autocomplete and syncs the URL, preserving other params", () => {
        cy.visit(
            `${PLACE_HOLD_PATH}?biblionumber=${testData.biblio.biblio_id}&searchid=scs_1756200000`
        );
        cy.get("#holds").should("exist");
        cy.get(".holdability-shield").should("not.exist");

        cy.get("h1").should("contain.text", "Place a hold on");
        cy.get(".express-bib-level-hold").should("not.exist");

        cy.get("input.patron-search-input").type(testData.patron.cardnumber);
        cy.get("ul.ui-autocomplete li a")
            .contains(testData.patron.cardnumber)
            .click();

        cy.location("search", { timeout: 10000 })
            .should("include", `biblionumber=${testData.biblio.biblio_id}`)
            .and("include", "searchid=scs_1756200000")
            .and("include", `borrowernumber=${testData.patron.patron_id}`);
        cy.get("#patron_selection_place-hold-patron").should(
            "contain.text",
            testData.patron.surname
        );
        cy.get(".express-bib-level-hold").should("be.visible");

        cy.get("#patron_selection_place-hold-patron a.removePatron").click();
        cy.location("search")
            .should("not.include", "borrowernumber")
            .and("include", "searchid=scs_1756200000");
        cy.get(".express-bib-level-hold").should("not.exist");
    });

    it("pre-fills the patron chip when borrowernumber is already in the URL", () => {
        visit();
        cy.get("#patron_selection_place-hold-patron").should(
            "contain.text",
            testData.patron.surname
        );
        cy.get(".express-bib-level-hold").should("be.visible");
    });

    it("pre-fills the patron chip when findborrower (a cardnumber) is in the URL", () => {
        // reserve/request.pl resolves findborrower to a borrowernumber
        // itself (Koha::Patrons->find({ cardnumber => ... })) and hands
        // it to the Vue app via a data attribute - no borrowernumber
        // param here, only findborrower, to prove that path works on its
        // own rather than piggy-backing on borrowernumber also being set.
        cy.visit(
            `${PLACE_HOLD_PATH}?biblionumber=${testData.biblio.biblio_id}` +
                `&findborrower=${testData.patron.cardnumber}`
        );
        cy.get("#patron_selection_place-hold-patron").should(
            "contain.text",
            testData.patron.surname
        );
        cy.get(".express-bib-level-hold").should("be.visible");
    });

    it("unlocks the form and shows an error when placing the hold fails, then allows a retry", () => {
        visit();
        waitForBootstrap();
        cy.get(".express-bib-level-hold button[type=submit]").should("exist");

        cy.intercept("POST", "/api/v1/holds", {
            statusCode: 500,
            body: { error: "Hold could not be placed" },
        }).as("createHoldFail");

        cy.get(".express-bib-level-hold button[type=submit]").click();
        cy.wait("@createHoldFail");

        cy.get(".express-bib-level-hold .card-body > .alert.alert-danger")
            .should("be.visible")
            .and("contain.text", "Hold could not be placed");
        cy.get(".express-bib-level-hold button[type=submit]").should(
            "not.be.disabled"
        );
        cy.get(".express-bib-level-hold .toast.show").should("not.exist");
        cy.location("pathname").should("eq", PLACE_HOLD_PATH);

        // An empty pass-through intercept here wouldn't actually override
        // the 500 stub above - with no response of its own it falls
        // through to the next-older matching intercept, which is still
        // the 500 stub. A real stub is needed to actually replace it.
        cy.intercept("POST", "/api/v1/holds", {
            statusCode: 201,
            body: { hold_id: 999999, priority: 1 },
        }).as("createHoldRetry");
        cy.get(".express-bib-level-hold button[type=submit]").click();
        cy.wait("@createHoldRetry")
            .its("response.statusCode")
            .should("eq", 201);
        cy.get(".express-bib-level-hold .toast.show .toast-body").should(
            "have.text",
            "Queue position: #1"
        );
    });
});
