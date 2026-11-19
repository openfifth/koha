describe("plugins/plugins-upload.pl uploadlocation allow-list (bug 43682)", () => {
    beforeEach(() => {
        cy.login();
    });

    const postUploadLocation = (uploadlocation: string) => {
        cy.visit("/cgi-bin/koha/plugins/plugins-upload.pl");
        return cy
            .get('input[name="csrf_token"]')
            .first()
            .invoke("val")
            .then(csrf_token =>
                cy.request({
                    method: "POST",
                    url: "/cgi-bin/koha/plugins/plugins-upload.pl",
                    form: true,
                    body: {
                        op: "cud-Upload",
                        csrf_token,
                        // A plain (non-file) param, just so the unrelated
                        // "not a .kpz file" check doesn't also fire and mask
                        // whether the uploadlocation was accepted or not.
                        uploadfile: "fake.kpz",
                        uploadlocation,
                    },
                    failOnStatusCode: false,
                })
            );
    };

    it("Should refuse a disallowed host, even without plugins_restricted configured", () => {
        postUploadLocation(
            "https://169.254.169.254/bywatersolutions/x.kpz"
        ).then(resp => {
            expect(resp.body).to.contain(
                "Cannot install plugin from unknown source"
            );
        });
    });

    it("Should refuse the right host with the wrong org_name path (no substring bypass)", () => {
        postUploadLocation("https://github.com/not-an-allowed-org/x.kpz").then(
            resp => {
                expect(resp.body).to.contain(
                    "Cannot install plugin from unknown source"
                );
            }
        );
    });

    it("Should refuse a lookalike subdomain of an allowed host", () => {
        postUploadLocation(
            "https://github.com.evil.example/bywatersolutions/x.kpz"
        ).then(resp => {
            expect(resp.body).to.contain(
                "Cannot install plugin from unknown source"
            );
        });
    });

    it("Should refuse files under an allowed org that are not release assets", () => {
        postUploadLocation(
            "https://github.com/bywatersolutions/koha-plugin-foo/files/123/foo.kpz"
        ).then(resp => {
            expect(resp.body).to.contain(
                "Cannot install plugin from unknown source"
            );
        });
    });

    it("Should refuse a path that climbs out of the allowed org_name", () => {
        postUploadLocation(
            "https://github.com/bywatersolutions/%2e%2e/evil/koha-plugin-foo/releases/download/v1/foo.kpz"
        ).then(resp => {
            expect(resp.body).to.contain(
                "Cannot install plugin from unknown source"
            );
        });
    });

    it("Should accept an allowed host + org_name path (and attempt the fetch)", () => {
        postUploadLocation(
            "https://github.com/bywatersolutions/koha-plugin-foo/releases/download/v1/foo.kpz"
        ).then(resp => {
            expect(resp.body).not.to.contain(
                "Cannot install plugin from unknown source"
            );
        });
    });
});
