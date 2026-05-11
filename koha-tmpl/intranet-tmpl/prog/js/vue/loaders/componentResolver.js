const businessContext = require.context("@koha-vue", true, /\.vue$/);

// Cypress fixture components are loaded via require.context only outside
// production. DefinePlugin replaces process.env.NODE_ENV with the literal
// build mode, so the bundler dead-codes both the require.context call and
// every Cypress .vue file out of staff-client builds (see rspack.config.js
// commonResolve — the @cypress alias is also omitted in production as a
// second layer of defense).
const cypressContext =
    process.env.NODE_ENV !== "production"
        ? require.context("@cypress", true, /\.vue$/)
        : null;

export function loadComponent(path) {
    if (path.startsWith("@koha-vue/")) {
        return () => Promise.resolve(businessContext("." + path.slice(9)));
    } else if (path.startsWith("@cypress/")) {
        if (!cypressContext) {
            throw new Error(
                "Cypress fixture components are not available in production builds"
            );
        }
        return () => Promise.resolve(cypressContext("." + path.slice(8)));
    } else {
        return () => import(`${path}`);
    }
}
