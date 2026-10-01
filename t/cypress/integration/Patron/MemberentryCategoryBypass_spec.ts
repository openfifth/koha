describe("members/memberentry.pl categorycode/staffaccess bypass (bug 43679)", () => {
    const staff_categorycode = "T43679S";
    const attacker_password = "AttackerChosenPassw0rd1!";

    let target: any;
    let attacker: any;
    let target_row_before: any;

    beforeEach(() => {
        cy.task("query", {
            sql: "DELETE FROM categories WHERE categorycode = ?",
            values: [staff_categorycode],
        });
        cy.task("query", {
            sql: "INSERT INTO categories (categorycode, description, category_type) VALUES (?, 'Bug 43679 staff test category', 'S')",
            values: [staff_categorycode],
        })
            .then(() =>
                cy.task("apiGet", {
                    endpoint: `/api/v1/patron_categories?q={"me.patron_category_id":"${staff_categorycode}"}`,
                })
            )
            .then((categories: any) => {
                return cy.task("insertSamplePatron", {
                    patron_category: categories[0],
                });
            })
            .then((result: any) => {
                target = result;
                return cy.task("apiPost", {
                    endpoint: `/api/v1/patrons/${target.patron.patron_id}/password`,
                    body: {
                        password: "OriginalPassw0rd1!",
                        password_2: "OriginalPassw0rd1!",
                    },
                });
            })
            .then(() =>
                cy.task("query", {
                    sql: "SELECT * FROM borrowers WHERE borrowernumber = ?",
                    values: [target.patron.patron_id],
                })
            )
            .then((rows: any) => {
                target_row_before = rows[0];
                // Same library as the target - otherwise plain edit_borrowers
                // isn't enough to even view the target's record cross-library
                // (can_see_patrons_from), which is a separate restriction
                // from the staffaccess bug under test here.
                return cy.task("insertSamplePatron", {
                    library: target.library,
                });
            })
            .then((result: any) => {
                attacker = result;
                return cy.task("apiPost", {
                    endpoint: `/api/v1/patrons/${attacker.patron.patron_id}/password`,
                    body: {
                        password: attacker_password,
                        password_2: attacker_password,
                    },
                });
            })
            .then(() =>
                cy.task("query", {
                    sql: "INSERT INTO user_permissions (borrowernumber, module_bit, code) VALUES (?, 4, 'edit_borrowers')",
                    values: [attacker.patron.patron_id],
                })
            )
            .then(() =>
                // bit 2 = catalogue: baseline access required for staff login
                // at all (see userflags.sql) - *not* staffaccess (bit 17).
                cy.task("query", {
                    sql: "UPDATE borrowers SET flags = 4 WHERE borrowernumber = ?",
                    values: [attacker.patron.patron_id],
                })
            );
    });

    afterEach(() => {
        cy.task("query", {
            sql: "DELETE FROM user_permissions WHERE borrowernumber = ?",
            values: [attacker.patron.patron_id],
        });
        cy.task("deleteSampleObjects", [attacker, target]);
        cy.task("query", {
            sql: "DELETE FROM categories WHERE categorycode = ?",
            values: [staff_categorycode],
        });
    });

    it("Should not let an edit_borrowers-only user reset a staff account's password/userid by also changing its category", () => {
        cy.login(attacker.patron.userid, attacker_password);

        // Load the real edit form as the attacker, exactly as a normal
        // editor would, to obtain a valid session + CSRF token.
        cy.visit(
            `/cgi-bin/koha/members/memberentry.pl?op=edit_form&borrowernumber=${target.patron.patron_id}`
        );

        cy.get('input[name="csrf_token"]')
            .first()
            .invoke("val")
            .then(csrf_token => {
                // Craft the malicious save exactly as described in the bug:
                // the target's full existing record, but with categorycode
                // switched away from the staff category in the SAME request
                // as a password/userid change.
                const body: Record<string, any> = {
                    op: "cud-save",
                    csrf_token,
                    nodouble: 1,
                    borrowernumber: target.patron.patron_id,
                    // Mandatory fields (BorrowerMandatoryField), unchanged:
                    surname: target_row_before.surname,
                    cardnumber: target_row_before.cardnumber,
                    // The malicious changes, submitted together as in the bug report:
                    categorycode: attacker.patron.category_id,
                    userid: "bug_43679_hijacked",
                    password: attacker_password,
                    password2: attacker_password,
                };

                cy.request({
                    method: "POST",
                    url: "/cgi-bin/koha/members/memberentry.pl",
                    form: true,
                    body,
                    failOnStatusCode: false,
                });
            });

        cy.task("query", {
            sql: "SELECT userid, password, categorycode FROM borrowers WHERE borrowernumber = ?",
            values: [target.patron.patron_id],
        }).then((rows: any) => {
            const target_row_after = rows[0];
            expect(target_row_after.userid, "userid must not change").to.eq(
                target_row_before.userid
            );
            expect(
                target_row_after.password,
                "password hash must not change"
            ).to.eq(target_row_before.password);
            expect(
                target_row_after.categorycode,
                "category must stay the staff category"
            ).to.eq(staff_categorycode);
        });
    });
});
