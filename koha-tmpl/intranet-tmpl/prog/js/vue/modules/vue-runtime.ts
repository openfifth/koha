// Dedicated Vue runtime entry point.
//
// This is built by rspack as a standalone ESM bundle that re-exports all
// of Vue's public API. Unlike the pre-built browser variants, this goes
// through rspack's DefinePlugin so the feature flags (__VUE_OPTIONS_API__,
// __VUE_PROD_DEVTOOLS__, etc.) are correctly applied for both development
// and production builds.
//
// The import map resolves "vue" to the built output (vue.esm.js),
// ensuring all bundles share this single Vue instance.
export * from "vue";
