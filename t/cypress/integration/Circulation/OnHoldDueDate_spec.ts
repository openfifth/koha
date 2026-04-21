describe("Circulation - AllowRenewalOnHoldOverride 'On hold due date'", () => {
    let checkout, patron, item;
    const HOLD_DUE = "2099-06-15 23:59";
    const RENEW_DUE = "2099-05-05 23:59";

    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.set_syspref("AllowRenewalOnHoldOverride", "1");
        cy.set_syspref("AlwaysLoadCheckoutsTable", "1");

        cy.task("insertSampleCheckout").then(objects => {
            checkout = objects.checkout;
            patron = objects.patron;
            item = objects.items[0];

            // Place a hold on the same biblio for a different patron so the
            // existing checkout shows as "on_reserve" / renewable-with-override.
            return cy.task("insertSampleHold", {
                item: item,
                library_id: item.home_library_id,
            });
        });
    });

    afterEach(() => {
        cy.set_syspref("AllowRenewalOnHoldOverride", "0");
        cy.set_syspref("AlwaysLoadCheckoutsTable", "0");
        cy.task("deleteSampleObjects", [{ checkout }]);
    });

    it("sends the 'On hold due date' value to svc/renew for on-hold items", () => {
        cy.intercept("POST", "/cgi-bin/koha/svc/renew").as("renew");

        cy.visit(
            `/cgi-bin/koha/members/moremember.pl?borrowernumber=${patron.patron_id}`
        );

        cy.get("#issues-table", { timeout: 20000 }).should("be.visible");

        // Reveal the on-reserve renewal checkbox (hidden until override is checked)
        cy.get("#override_limit").check();

        cy.get(`input.renew[value='${item.item_id}']`, {
            timeout: 20000,
        }).should("have.attr", "data-on-reserve");
        cy.get(`input.renew[value='${item.item_id}']`).check();

        cy.get("#newonholdduedate").should("be.visible");

        // flatpickr hides the underlying input; force the value + change event
        cy.get("#newduedate")
            .invoke("val", RENEW_DUE)
            .trigger("change", { force: true });
        cy.get("#newonholdduedatefield")
            .invoke("val", HOLD_DUE)
            .trigger("change", { force: true });

        cy.get("#RenewChecked").click();

        cy.wait("@renew").then(interception => {
            const body = interception.request.body;
            const params = new URLSearchParams(body);
            expect(params.get("itemnumber")).to.equal(String(item.item_id));
            expect(decodeURIComponent(params.get("date_due"))).to.equal(
                HOLD_DUE
            );
        });
    });

    it("falls back to 'Renewal due date' for non-on-hold items", () => {
        // Insert a second checkout for the same patron on a fresh biblio (no hold)
        cy.task("insertSampleCheckout", { patron: patron }).then(
            secondCheckout => {
                const plainItem = secondCheckout.items[0];

                cy.intercept("POST", "/cgi-bin/koha/svc/renew").as("renew");

                cy.visit(
                    `/cgi-bin/koha/members/moremember.pl?borrowernumber=${patron.patron_id}`
                );

                cy.get("#issues-table", { timeout: 20000 }).should(
                    "be.visible"
                );

                cy.get(`input.renew[value='${plainItem.item_id}']`, {
                    timeout: 20000,
                }).should("not.have.attr", "data-on-reserve");
                cy.get(`input.renew[value='${plainItem.item_id}']`).check();

                // flatpickr hides the underlying input; force the value + change event
                cy.get("#newduedate")
                    .invoke("val", RENEW_DUE)
                    .trigger("change", { force: true });

                cy.get("#RenewChecked").click();

                cy.wait("@renew").then(interception => {
                    const body = interception.request.body;
                    const params = new URLSearchParams(body);
                    expect(decodeURIComponent(params.get("date_due"))).to.equal(
                        RENEW_DUE
                    );
                });

                cy.task("deleteSampleObjects", [
                    { checkout: secondCheckout.checkout },
                ]);
            }
        );
    });
});
