describe("reports/dictionary.pl SQL injection (bug 43478)", () => {
    function cleanup() {
        cy.task("query", {
            sql: "DELETE FROM reports_dictionary WHERE name LIKE 'cypress_dict_%'",
        });
    }

    beforeEach(() => {
        cleanup();
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    afterEach(() => {
        cleanup();
    });

    it("Should save a legitimate definition end-to-end (regression check)", () => {
        cy.visit("/cgi-bin/koha/reports/dictionary.pl?op=add_form");

        cy.get("#definition_name").type("cypress_dict_legit");
        cy.get("#definition_description").type("cypress legit definition");
        cy.get("form").contains("Next").click();

        // Step 2: choose the area
        cy.get("#area").select("PAT");
        cy.get("form").contains("Next").click();

        // Step 3: choose a column
        cy.get("#availableColumns").select("borrowers.branchcode");
        cy.get("form").contains("Next").click();

        // Step 4: specify a value (branchcode is a distinct/select-type column)
        cy.get("select[id='borrowers.branchcode_value']").select("CPL");
        cy.get("form").contains("Next").click();

        // Step 5: confirm and save
        cy.get("input[name='sql']").should(
            "have.value",
            " AND borrowers.branchcode='CPL'"
        );
        cy.get("form").contains("Save").click();

        cy.get("table").contains("cypress_dict_legit");

        cy.task("query", {
            sql: "SELECT saved_sql FROM reports_dictionary WHERE name=?",
            values: ["cypress_dict_legit"],
        }).then(result => {
            expect(result.length).to.equal(1);
            expect(result[0].saved_sql).to.equal(
                " AND borrowers.branchcode='CPL'"
            );
        });
    });

    it("Should reject a malicious 'sql' value tampered in at the final save step", () => {
        cy.visit("/cgi-bin/koha/reports/dictionary.pl?op=add_form");

        cy.get("#definition_name").type("cypress_dict_pwn");
        cy.get("#definition_description").type("cypress pwn attempt");
        cy.get("form").contains("Next").click();

        cy.get("#area").select("PAT");
        cy.get("form").contains("Next").click();

        cy.get("#availableColumns").select("borrowers.branchcode");
        cy.get("form").contains("Next").click();

        cy.get("select[id='borrowers.branchcode_value']").select("CPL");
        cy.get("form").contains("Next").click();

        // Step 5: an attacker tampers with the hidden 'sql' field directly
        // (exactly the reported attack - save_dictionary() never validated it)
        cy.get("input[name='sql']").invoke(
            "val",
            "WHERE 1=1 UNION SELECT userid,password FROM borrowers-- -"
        );
        cy.get("form").contains("Save").click();

        cy.get(".alert").contains(/SQL was not valid/);

        cy.task("query", {
            sql: "SELECT COUNT(*) as count FROM reports_dictionary WHERE name=?",
            values: ["cypress_dict_pwn"],
        }).then(result => {
            expect(result[0].count).to.equal(0);
        });
    });

    it("Should silently drop a non-allowlisted criteria column tampered in at step 4", () => {
        cy.visit("/cgi-bin/koha/reports/dictionary.pl?op=add_form");

        cy.get("#definition_name").type("cypress_dict_critattack");
        cy.get("#definition_description").type("cypress criteria attack");
        cy.get("form").contains("Next").click();

        cy.get("#area").select("PAT");
        cy.get("form").contains("Next").click();

        cy.get("#availableColumns").select("borrowers.branchcode");
        cy.get("form").contains("Next").click();

        // Step 4: tamper with the hidden criteria_column/value pair to pose as
        // an injected, non-existent column
        cy.get("input[name='criteria_column']").invoke("val", "evil_col");
        cy.get("select[id='borrowers.branchcode_value']")
            .invoke("attr", "name", "evil_col_value")
            .select("CPL");
        cy.get("form").contains("Next").click();

        // Step 5: the bogus criterion must not have made it into the generated
        // SQL fragment at all
        cy.get("input[name='sql']").should("have.value", "");
        cy.get("table").should("not.contain", "evil_col");
    });
});
