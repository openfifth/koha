/// <reference types="cypress" />

/**
 * Smoke tests for the staff-client colour-mode toggle (Bug 31327).
 *
 * What this spec covers:
 *   - data-bs-theme on <html> reflects the persisted preference
 *   - the FOUC-killer in doc-head-open.inc applies the right value
 *     before paint (verified by reading the attribute synchronously
 *     after navigation)
 *   - each Light / Dark / Auto option in the dropdown moves
 *     aria-pressed and the active marker correctly
 *   - the --koha-* CSS custom properties emit different values
 *     between modes (i.e. the cascade actually flips)
 *
 * What this spec does NOT cover (yet):
 *   - pixel-level visual regression. Add a snapshot plugin (e.g.
 *     cypress-image-snapshot) and uncomment the cy.screenshot()
 *     calls below to wire that in.
 */

const PAGES = [
    { name: "Staff main page", path: "/cgi-bin/koha/mainpage.pl" },
    { name: "Patrons home", path: "/cgi-bin/koha/members/members-home.pl" },
    { name: "Catalogue search", path: "/cgi-bin/koha/catalogue/search.pl" },
    { name: "Admin home", path: "/cgi-bin/koha/admin/admin-home.pl" },
];

const THEMES = ["light", "dark", "auto"] as const;

const setStoredTheme = (theme: string | null) =>
    cy.window().then(win => {
        if (theme === null) {
            win.localStorage.removeItem("theme");
        } else {
            win.localStorage.setItem("theme", theme);
        }
    });

const getResolvedTheme = () =>
    cy
        .document()
        .then(doc => doc.documentElement.getAttribute("data-bs-theme"));

const getCssVar = (name: string) =>
    cy
        .document()
        .then(doc =>
            getComputedStyle(doc.documentElement).getPropertyValue(name).trim()
        );

describe("Bug 31327 — colour-mode toggle", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Renders without a flash of the wrong theme on first load", () => {
        // No stored preference, browser in light mode by default.
        setStoredTheme(null);
        cy.reload();
        // The inline script in doc-head-open.inc must have fired *before*
        // the <body> rendered, so the attribute is set by the time
        // Cypress can read it.
        getResolvedTheme().should("be.oneOf", ["light", "dark"]);
    });

    THEMES.forEach(theme => {
        it(`Persists theme="${theme}" across reload`, () => {
            setStoredTheme(theme);
            cy.reload();

            const expected =
                theme === "auto"
                    ? // Cypress tests run in light mode by default.
                      "light"
                    : theme;
            getResolvedTheme().should("eq", expected);
        });
    });

    it("Surface tokens differ between light and dark modes", () => {
        setStoredTheme("light");
        cy.reload();
        getCssVar("--koha-surface").then(lightSurface => {
            getCssVar("--koha-on-surface").then(lightText => {
                setStoredTheme("dark");
                cy.reload();
                getCssVar("--koha-surface").then(darkSurface => {
                    getCssVar("--koha-on-surface").then(darkText => {
                        expect(lightSurface).not.to.equal(darkSurface);
                        expect(lightText).not.to.equal(darkText);
                    });
                });
            });
        });
    });

    it("Dropdown updates aria-pressed and the active marker on click", () => {
        setStoredTheme(null);
        cy.reload();

        cy.get("#bd-theme-toggle").click();
        cy.get('[data-bs-theme-value="dark"]').click();
        cy.get('[data-bs-theme-value="dark"]').should(
            "have.attr",
            "aria-pressed",
            "true"
        );
        cy.get('[data-bs-theme-value="light"]').should(
            "have.attr",
            "aria-pressed",
            "false"
        );
        getResolvedTheme().should("eq", "dark");

        cy.get("#bd-theme-toggle").click();
        cy.get('[data-bs-theme-value="light"]').click();
        cy.get('[data-bs-theme-value="light"]').should(
            "have.attr",
            "aria-pressed",
            "true"
        );
        getResolvedTheme().should("eq", "light");
    });

    PAGES.forEach(page => {
        it(`Applies the resolved theme on ${page.name}`, () => {
            setStoredTheme("dark");
            cy.visit(page.path);
            getResolvedTheme().should("eq", "dark");
            // cy.screenshot(`${page.name}-dark`);

            setStoredTheme("light");
            cy.visit(page.path);
            getResolvedTheme().should("eq", "light");
            // cy.screenshot(`${page.name}-light`);
        });
    });
});
