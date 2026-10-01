describe("tools/viewlog.pl modules parameter JSON-in-script escaping", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Should not allow the modules param to break out of the inline <script> block", () => {
        const payload = "</script><script>window.__xss_fired = true;</script>";

        cy.visit(
            `/cgi-bin/koha/tools/viewlog.pl?do_it=1&modules=${encodeURIComponent(payload)}`
        );

        // The page must still render normally...
        cy.get("#logst").should("exist");

        // ...and the payload must never have executed as a second <script> element.
        cy.window().then(win => {
            expect(win.__xss_fired).to.be.undefined;
        });

        // The raw closing/opening tag pair must not appear unescaped in the response.
        cy.document().then(doc => {
            expect(doc.documentElement.innerHTML).not.to.contain(
                "</script><script>window.__xss_fired"
            );
        });
    });
});
