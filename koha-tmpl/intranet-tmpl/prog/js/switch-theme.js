/*!
 * Colour-mode toggle for the Koha staff client.
 *
 * Adapted from Bootstrap docs' colour-modes.js
 * (https://getbootstrap.com/, CC BY 3.0).
 *
 * The actual data-bs-theme attribute is applied by the inline script in
 * doc-head-open.inc before first paint to avoid a flash of the wrong
 * theme. This file only:
 *   - keeps the dropdown's active marker / aria-pressed in sync,
 *   - persists the user's choice to localStorage,
 *   - keeps "auto" tracking the OS preference live.
 */

(() => {
    "use strict";

    const STORAGE_KEY = "theme";

    const safeGetStoredTheme = () => {
        try {
            return (
                window.localStorage && window.localStorage.getItem(STORAGE_KEY)
            );
        } catch (e) {
            // Privacy mode, kiosk lockdown — silently fall through.
            return null;
        }
    };

    const safeSetStoredTheme = theme => {
        try {
            if (window.localStorage) {
                window.localStorage.setItem(STORAGE_KEY, theme);
            }
        } catch (e) {
            // No persistence available; the chosen theme will still apply
            // for this page only.
        }
    };

    const systemPrefersDark = () =>
        window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)").matches;

    // The user's *preference* — what they picked in the dropdown.
    // May be "light", "dark", "auto" or null (never picked).
    const getStoredPreference = () => safeGetStoredTheme() || "auto";

    // The *resolved* theme actually applied to <html>.
    const resolveTheme = preference =>
        preference === "auto"
            ? systemPrefersDark()
                ? "dark"
                : "light"
            : preference;

    const applyTheme = preference => {
        document.documentElement.setAttribute(
            "data-bs-theme",
            resolveTheme(preference)
        );
    };

    const showActiveTheme = (preference, focus = false) => {
        const switcher = document.querySelector("#bd-theme");
        if (!switcher) {
            return;
        }

        const toggle = document.querySelector("#bd-theme-toggle");
        const activeIcon = switcher.querySelector(".theme-icon-active");

        // Mark the chosen option pressed; un-press the others.
        switcher.querySelectorAll("[data-bs-theme-value]").forEach(button => {
            const isActive =
                button.getAttribute("data-bs-theme-value") === preference;
            button.setAttribute("aria-pressed", String(isActive));
            button.classList.toggle("active", isActive);
        });

        // Sun / moon / half-circle icon on the dropdown toggle reflects
        // the *resolved* theme so users see at-a-glance what's applied.
        const resolved = resolveTheme(preference);
        if (activeIcon) {
            activeIcon.classList.remove(
                "fa-sun",
                "fa-moon",
                "fa-circle-half-stroke"
            );
            if (preference === "auto") {
                activeIcon.classList.add("fa-circle-half-stroke");
            } else if (resolved === "dark") {
                activeIcon.classList.add("fa-moon");
            } else {
                activeIcon.classList.add("fa-sun");
            }
        }

        if (toggle) {
            toggle.setAttribute(
                "aria-label",
                `Toggle colour theme (current: ${preference})`
            );
        }

        if (focus && toggle) {
            toggle.focus();
        }
    };

    // Live-track the OS preference while the user is on "auto".
    if (window.matchMedia) {
        window
            .matchMedia("(prefers-color-scheme: dark)")
            .addEventListener("change", () => {
                if (getStoredPreference() === "auto") {
                    applyTheme("auto");
                }
            });
    }

    window.addEventListener("DOMContentLoaded", () => {
        const initial = getStoredPreference();
        showActiveTheme(initial);

        document.querySelectorAll("[data-bs-theme-value]").forEach(button => {
            button.addEventListener("click", () => {
                const preference = button.getAttribute("data-bs-theme-value");
                safeSetStoredTheme(preference);
                applyTheme(preference);
                showActiveTheme(preference, true);
            });
        });
    });
})();
