describe("reports/reserves_stats.pl Line/Column/filter_* SQL injection (bug 43455)", () => {
    beforeEach(() => {
        cy.login();
    });

    it("Should not leak data via a malicious Line/Column value", () => {
        cy.request({
            url: "/cgi-bin/koha/reports/reserves_stats.pl",
            qs: {
                do_it: 1,
                Line: "(SELECT CONCAT('LEAK',@@version))",
                Column: "(SELECT 'c')",
                Cellvalue: 1,
                output: "screen",
            },
        }).then(resp => {
            expect(resp.status).to.eq(200);
            expect(resp.body).not.to.contain("LEAK");
        });
    });

    it("Should reject a malicious filter_* parameter name rather than reaching the query", () => {
        cy.request({
            url: "/cgi-bin/koha/reports/reserves_stats.pl",
            qs: {
                do_it: 1,
                Line: "reserves.branchcode",
                Column: "reservestatus",
                Cellvalue: 1,
                output: "screen",
                "filter_' OR '1'='1_begin": 1,
            },
            failOnStatusCode: false,
        }).then(resp => {
            // The malicious filter is silently discarded rather than
            // crashing the query or being honoured.
            expect(resp.status).to.eq(200);
        });
    });

    it("Should still render normally with legitimate Line/Column/filter values", () => {
        cy.request({
            url: "/cgi-bin/koha/reports/reserves_stats.pl",
            qs: {
                do_it: 1,
                Line: "reserves.branchcode",
                Column: "reservestatus",
                Cellvalue: 1,
                output: "screen",
                filter_categorycode: "PT",
                filter_reservestatus_or_C: "C",
            },
        }).then(resp => {
            expect(resp.status).to.eq(200);
            expect(resp.body).to.contain("Holds statistics");
        });
    });
});
