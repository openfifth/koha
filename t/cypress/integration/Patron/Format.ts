describe("Display patron - search", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("query", {
            sql: "SELECT value FROM systempreferences WHERE variable='ShowPatronFirstnameIfDifferentThanPreferredname'",
        }).then(rows => {
            cy.wrap(rows[0].value).as(
                "syspref_ShowPatronFirstnameIfDifferentThanPreferredname"
            );
        });
        cy.set_syspref("ShowPatronFirstnameIfDifferentThanPreferredname", 0);
    });

    afterEach(function () {
        cy.set_syspref(
            "ShowPatronFirstnameIfDifferentThanPreferredname",
            this.syspref_ShowPatronFirstnameIfDifferentThanPreferredname
        );
    });

    const table_id = "memberresultst";

    it("should display all patron info", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 2,
            values: {},
        }).then(patrons => {
            // Needs more properties to not explode
            // account_balace: balance_str.escapeHtml(...).format_price is not a function
            patrons = patrons.map(p => ({ ...p, account_balance: 0 }));

            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "2",
                    "X-Total-Count": "2",
                },
            });

            cy.visit("/cgi-bin/koha/members/members-home.pl");

            cy.window().then(win => {
                win.categories_map = patrons.reduce((map, p) => {
                    map[p.category_id.toLowerCase()] = p.category_id;
                    return map;
                }, {});
            });

            cy.get("form.patron_search_form input[type='submit']").click();

            const patron = patrons[0];
            // invert_name is set
            cy.get(`#${table_id} tbody tr:eq(0) td:eq(2)`).should($el => {
                let re = new RegExp(
                    `${patron.surname}, ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\)`
                );
                const displayedText = $el.text().replace(/ /g, " ").trim();
                expect(displayedText).to.match(re);
                re = new RegExp(patron.cardnumber);
                expect(displayedText).to.not.match(re);
            });
        });
    });

    it("should have correct punctuation when surname is missing", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 2,
            values: { surname: null },
        }).then(patrons => {
            // Needs more properties to not explode
            // account_balace: balance_str.escapeHtml(...).format_price is not a function
            patrons = patrons.map(p => ({ ...p, account_balance: 0 }));

            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "2",
                    "X-Total-Count": "2",
                },
            });

            cy.visit("/cgi-bin/koha/members/members-home.pl");

            cy.window().then(win => {
                win.categories_map = patrons.reduce((map, p) => {
                    map[p.category_id.toLowerCase()] = p.category_id;
                    return map;
                }, {});
            });

            cy.get("form.patron_search_form input[type='submit']").click();

            const patron = patrons[0];
            // invert_name is set
            cy.get(`#${table_id} tbody tr:eq(0) td:eq(2)`).should($el => {
                let re = new RegExp(
                    `^${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\)`
                );
                const displayedText = $el.text().replace(/ /g, " ").trim();
                expect(displayedText).to.match(re);
                re = new RegExp(patron.cardnumber);
                expect(displayedText).to.not.match(re);
            });
        });
    });

    it("should display patron firstname and preferred name when different and ShowPatronFirstnameIfDifferentThanPreferredname is enabled", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 2,
            values: {},
        }).then(patrons => {
            // Needs more properties to not explode
            // account_balace: balance_str.escapeHtml(...).format_price is not a function
            patrons = patrons.map(p => ({ ...p, account_balance: 0 }));

            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "2",
                    "X-Total-Count": "2",
                },
            });

            cy.set_syspref(
                "ShowPatronFirstnameIfDifferentThanPreferredname",
                1
            ).then(() => {
                cy.visit("/cgi-bin/koha/members/members-home.pl");

                cy.window().then(win => {
                    win.categories_map = patrons.reduce((map, p) => {
                        map[p.category_id.toLowerCase()] = p.category_id;
                        return map;
                    }, {});
                });

                cy.get("form.patron_search_form input[type='submit']").click();

                const patron = patrons[0];
                // invert_name is set
                cy.get(`#${table_id} tbody tr:eq(0) td:eq(2)`).should($el => {
                    let re = new RegExp(
                        `${patron.surname}, ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\) \\[${patron.firstname}\\]`
                    );
                    const displayedText = $el.text().replace(/ /g, " ").trim();
                    expect(displayedText).to.match(re);
                    re = new RegExp(patron.cardnumber);
                    expect(displayedText).to.not.match(re);
                });
            });
        });
    });

    it("should not display patron firstname when same as preferred_name and ShowPatronFirstnameIfDifferentThanPreferredname is enabled", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 2,
            values: {
                firstname: "SameFirstnameAndPreferredname",
                preferred_name: "SameFirstnameAndPreferredname",
            },
        }).then(patrons => {
            // Needs more properties to not explode
            // account_balace: balance_str.escapeHtml(...).format_price is not a function
            patrons = patrons.map(p => ({ ...p, account_balance: 0 }));

            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "2",
                    "X-Total-Count": "2",
                },
            });

            cy.set_syspref(
                "ShowPatronFirstnameIfDifferentThanPreferredname",
                1
            ).then(() => {
                cy.visit("/cgi-bin/koha/members/members-home.pl");

                cy.window().then(win => {
                    win.categories_map = patrons.reduce((map, p) => {
                        map[p.category_id.toLowerCase()] = p.category_id;
                        return map;
                    }, {});
                });

                cy.get("form.patron_search_form input[type='submit']").click();

                const patron = patrons[0];
                // invert_name is set
                cy.get(`#${table_id} tbody tr:eq(0) td:eq(2)`).should($el => {
                    let re = new RegExp(
                        `${patron.surname}, ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\)`
                    );
                    const displayedText = $el.text().replace(/ /g, " ").trim();
                    expect(displayedText).to.match(re);
                    re = new RegExp(patron.cardnumber);
                    expect(displayedText).to.not.match(re);
                    re = new RegExp(`\\[${patron.firstname}\\]`);
                    expect(displayedText).to.not.match(re);
                });
            });
        });
    });
});

describe("Display patron - autocomplete", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("query", {
            sql: "SELECT value FROM systempreferences WHERE variable='ShowPatronFirstnameIfDifferentThanPreferredname'",
        }).then(rows => {
            cy.wrap(rows[0].value).as(
                "syspref_ShowPatronFirstnameIfDifferentThanPreferredname"
            );
        });
        cy.set_syspref("ShowPatronFirstnameIfDifferentThanPreferredname", 0);
    });

    afterEach(function () {
        cy.set_syspref(
            "ShowPatronFirstnameIfDifferentThanPreferredname",
            this.syspref_ShowPatronFirstnameIfDifferentThanPreferredname
        );
    });

    it("should display all patron info", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 1,
            values: {},
        }).then(patrons => {
            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "1",
                    "X-Total-Count": "1",
                },
            });

            cy.visit("/cgi-bin/koha/mainpage.pl");

            const patron = patrons[0];
            cy.get("#findborrower").type(patron.surname);

            // invert_name is set
            cy.get(`ul.ui-autocomplete li a`).should($el => {
                let re = new RegExp(
                    `${patron.surname}, ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\) \\(${patron.cardnumber}\\)`
                );
                const displayedText = $el.text().replace(/ /g, " ").trim();
                expect(displayedText).to.match(re);
            });
        });
    });

    it("should have correct punctuation when surname is missing", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 1,
            values: { surname: null },
        }).then(patrons => {
            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "1",
                    "X-Total-Count": "1",
                },
            });

            cy.visit("/cgi-bin/koha/mainpage.pl");

            const patron = patrons[0];
            cy.get("#findborrower").type(patron.firstname);

            // invert_name is set
            cy.get(`ul.ui-autocomplete li a`).should($el => {
                let re = new RegExp(
                    `^${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\) \\(${patron.cardnumber}\\)`
                );
                const displayedText = $el.text().replace(/ /g, " ").trim();
                expect(displayedText).to.match(re);
            });
        });
    });

    it("should display patron firstname and preferred name when different and ShowPatronFirstnameIfDifferentThanPreferredname is enabled", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 1,
            values: {},
        }).then(patrons => {
            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "1",
                    "X-Total-Count": "1",
                },
            });
            cy.set_syspref(
                "ShowPatronFirstnameIfDifferentThanPreferredname",
                1
            ).then(() => {
                cy.visit("/cgi-bin/koha/mainpage.pl");

                const patron = patrons[0];
                cy.get("#findborrower").type(patron.surname);

                // invert_name is set
                cy.get(`ul.ui-autocomplete li a`).should($el => {
                    let re = new RegExp(
                        `${patron.surname}, ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\) \\[${patron.firstname}\\] \\(${patron.cardnumber}\\)`
                    );
                    const displayedText = $el.text().replace(/ /g, " ").trim();
                    expect(displayedText).to.match(re);
                });
            });
        });
    });

    it("should not display patron firstname when same as preferred_name and ShowPatronFirstnameIfDifferentThanPreferredname is enabled", function () {
        cy.task("buildSampleObjects", {
            object: "patron",
            count: 1,
            values: {
                firstname: "SameFirstnameAndPreferredname",
                preferred_name: "SameFirstnameAndPreferredname",
            },
        }).then(patrons => {
            cy.intercept("GET", "/api/v1/patrons*", {
                statusCode: 200,
                body: patrons,
                headers: {
                    "X-Base-Total-Count": "1",
                    "X-Total-Count": "1",
                },
            });

            cy.set_syspref(
                "ShowPatronFirstnameIfDifferentThanPreferredname",
                1
            ).then(() => {
                cy.visit("/cgi-bin/koha/mainpage.pl");

                const patron = patrons[0];
                cy.get("#findborrower").type(patron.surname);

                // invert_name is set
                cy.get(`ul.ui-autocomplete li a`).should($el => {
                    let re = new RegExp(
                        `${patron.surname}, ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\) \\(${patron.cardnumber}\\)`
                    );
                    const displayedText = $el.text().replace(/ /g, " ").trim();
                    expect(displayedText).to.match(re);
                    re = new RegExp(`\\[${patron.firstname}\\]`);
                    expect(displayedText).to.not.match(re);
                });
            });
        });
    });
});

describe("Display patron - no search", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.task("insertSamplePatron").then(objects_patron => {
            cy.wrap(objects_patron).as("objects_patron");
        });
    });

    afterEach(function () {
        cy.task("deleteSampleObjects", this.objects_patron);
    });

    it("should display all patron info", function () {
        const patron = this.objects_patron.patron;
        cy.visit(
            `/cgi-bin/koha/members/moremember.pl?borrowernumber=${patron.patron_id}`
        );
        cy.get(".row .col-sm-12 h1").should($el => {
            const re = new RegExp(
                `${patron.title} ${patron.preferred_name} ${patron.middle_name} \\(${patron.other_name}\\) ${patron.surname} \\(${patron.cardnumber}\\)`
            );
            const displayedText = $el.text().replace(/ /g, " ").trim();
            expect(displayedText).to.match(re);
        });
    });
});

describe("$patron_to_html - hidden patron name", () => {
    beforeEach(() => {
        cy.login();
        cy.visit("/cgi-bin/koha/members/members-home.pl");
    });

    const patron = {
        patron_id: 42,
        surname: "Smith",
        preferred_name: "Jo",
        cardnumber: "CARD42",
        library: { name: "Centerville" },
    };
    const config = {
        url: true,
        display_cardnumber: true,
        hide_patron_name: true,
    };

    it("shows the cardnumber as a link", () => {
        cy.window().then(win => {
            const $el = Cypress.$("<div>").html(
                win.$patron_to_html(patron, config)
            );
            expect($el.find("a").text()).to.eq("CARD42");
            expect($el.find("a").attr("href")).to.contain(
                "moremember.pl?borrowernumber=42"
            );
        });
    });

    [null, ""].forEach(cardnumber => {
        it(`never renders an empty link when cardnumber is ${JSON.stringify(cardnumber)}`, () => {
            cy.window().then(win => {
                const $el = Cypress.$("<div>").html(
                    win.$patron_to_html({ ...patron, cardnumber }, config)
                );
                expect($el.find("a").text()).to.eq("A patron from Centerville");
                expect($el.find("a").attr("href")).to.contain(
                    "moremember.pl?borrowernumber=42"
                );
            });
        });
    });

    it("uses config.library_name when the patron has no embedded library", () => {
        cy.window().then(win => {
            const { library, ...p } = patron;
            const $el = Cypress.$("<div>").html(
                win.$patron_to_html(
                    { ...p, cardnumber: "" },
                    { ...config, library_name: "Fairview" }
                )
            );
            expect($el.find("a").text()).to.eq("A patron from Fairview");
        });
    });
});
