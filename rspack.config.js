const { VueLoaderPlugin } = require("vue-loader");
//const autoprefixer = require("autoprefixer");
const path = require("path");
const rspack = require("@rspack/core");

const vueDistPath = path.resolve(
    __dirname,
    "koha-tmpl/intranet-tmpl/prog/js/vue/dist/"
);

const opacVueDistPath = path.resolve(
    __dirname,
    "koha-tmpl/opac-tmpl/bootstrap/js/vue/dist/"
);

const commonModuleRules = [
    {
        test: /\.vue$/,
        loader: "vue-loader",
        options: {
            experimentalInlineMatchResource: true,
        },
    },
    {
        test: /\.ts$/,
        loader: "builtin:swc-loader",
        options: {
            jsc: {
                parser: {
                    syntax: "typescript",
                },
            },
            appendTsSuffixTo: [/\.vue$/],
        },
        exclude: [/node_modules/, path.resolve(__dirname, "t/cypress/")],
        type: "javascript/auto",
    },
    {
        test: /\.css$/i,
        type: "javascript/auto",
        use: ["style-loader", "css-loader"],
    },
];

const vueFeatureFlags = new rspack.DefinePlugin({
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: false,
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
});

const commonPlugins = [new VueLoaderPlugin(), vueFeatureFlags];

// Externals for ESM output — resolved via the import map in doc-head-close.inc.
// NOTE: The import map keys ("jQuery", "DataTable") are the external *values*,
// not the npm package names. rspack emits `import ... from "<value>"` in ESM
// mode. If these values change, the import map must be updated to match.
const esmExternals = {
    jquery: "jQuery",
    vue: "vue",
    "datatables.net": "DataTable",
    "datatables.net-buttons": "DataTable",
    "datatables.net-buttons/js/buttons.html5": "DataTable",
    "datatables.net-buttons/js/buttons.print": "DataTable",
    "datatables.net-buttons/js/buttons.colVis": "DataTable",
};

module.exports = (env, argv) => {
    const isProduction = argv.mode === "production";

    // The @cypress alias is intentionally omitted from production builds so
    // Cypress fixture components cannot be reached via componentResolver.js's
    // dynamic require.context. The companion guard in componentResolver.js
    // dead-codes the require.context call in production; together they ensure
    // no test code is bundled into the staff client.
    const commonResolve = {
        alias: {
            "@fetch": path.resolve(
                __dirname,
                "koha-tmpl/intranet-tmpl/prog/js/fetch"
            ),
            "@koha-vue": path.resolve(
                __dirname,
                "koha-tmpl/intranet-tmpl/prog/js/vue"
            ),
            ...(isProduction
                ? {}
                : { "@cypress": path.resolve(__dirname, "t/cypress") }),
        },
    };

    return [
        // Vue runtime ESM — bundles Vue with feature flags applied by DefinePlugin.
        // The import map resolves "vue" to this file so all other ESM bundles
        // share the same Vue instance with correct Options API / devtools settings.
        {
            experiments: {
                outputModule: true,
            },
            entry: {
                vue: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/vue-runtime.ts",
                ],
            },
            output: {
                filename: "[name].esm.js",
                path: vueDistPath,
                library: {
                    type: "module",
                },
            },
            module: {
                rules: [
                    {
                        test: /\.ts$/,
                        loader: "builtin:swc-loader",
                        options: {
                            jsc: {
                                parser: { syntax: "typescript" },
                            },
                        },
                        type: "javascript/auto",
                    },
                ],
            },
            plugins: [vueFeatureFlags],
            // No vue external here — this IS the Vue bundle.
        },

        // ESM bundles — all share the single Vue instance via import map.
        // Vue is externalized and resolved to vue.esm.js by the browser.
        {
            resolve: commonResolve,
            experiments: {
                outputModule: true,
            },
            externalsType: "module-import",
            entry: {
                erm: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/erm.ts",
                ],
                preservation: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/preservation.ts",
                ],
                "admin/record_sources": [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/admin/record_sources.ts",
                ],
                acquisitions: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/acquisitions.ts",
                ],
                islands: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/islands.ts",
                ],
                sip2: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/sip2.ts",
                ],
                ill: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/ill.ts",
                ],
            },
            output: {
                filename: "[name].esm.js",
                path: vueDistPath,
                chunkFilename: "[name].[contenthash].esm.js",
                globalObject: "window",
                library: {
                    type: "module",
                },
            },
            module: { rules: commonModuleRules },
            plugins: commonPlugins,
            externals: esmExternals,
        },

        // OPAC islands ESM — same source as the intranet islands entry, emitted
        // into the OPAC dist directory so opac-bootstrap templates can load it.
        {
            resolve: commonResolve,
            experiments: {
                outputModule: true,
            },
            externalsType: "module-import",
            entry: {
                islands: [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/islands.ts",
                ],
            },
            output: {
                filename: "[name].esm.js",
                path: opacVueDistPath,
                chunkFilename: "[name].[contenthash].esm.js",
                globalObject: "window",
                library: {
                    type: "module",
                },
            },
            module: { rules: commonModuleRules },
            plugins: commonPlugins,
            externals: esmExternals,
        },

        // Cypress API client — CJS for Node.js test runner
        {
            entry: {
                "api-client.cjs": [
                    "./koha-tmpl/intranet-tmpl/prog/js/vue/csp-nonce.js",
                    "./koha-tmpl/intranet-tmpl/prog/js/fetch/api-client.js",
                ],
            },
            devtool: false,
            output: {
                filename: "[name].js",
                path: path.resolve(__dirname, "t/cypress/plugins/dist/"),
                clean: true,
                library: {
                    type: "commonjs",
                },
                globalObject: "global",
            },
            target: "node",
            module: {
                rules: [
                    {
                        test: /\.js$/,
                        loader: "builtin:swc-loader",
                        options: {
                            jsc: {
                                parser: {
                                    syntax: "ecmascript",
                                },
                            },
                        },
                        exclude: [/node_modules/],
                        type: "javascript/auto",
                    },
                ],
            },
            externals: [],
            plugins: [],
        },
    ];
};
