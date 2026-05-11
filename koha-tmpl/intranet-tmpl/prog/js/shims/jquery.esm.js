// ESM shim for jQuery — exposes the global loaded by the classic <script> tag.
// Used via import map so ESM bundles can `import $ from "jquery"`.
//
// IMPORTANT: This is a read-once snapshot, NOT a live binding. window.jQuery
// is read at module evaluation time and the value is captured into the
// exported bindings. Consequences:
//
//   - The classic <script src="jquery.js"> tag MUST execute before any
//     ESM bundle that imports from "jquery". Classic scripts without
//     async/defer run synchronously in document order, and module scripts
//     are implicitly deferred (run after the parser is done), so this
//     ordering holds for the standard staff-client templates.
//   - Do NOT load ESM bundles with `async` or via dynamic `import()` from
//     code that may run before jQuery's classic tag — the shim will
//     capture `undefined` permanently.
//   - Reassigning window.jQuery after this module has been evaluated
//     will NOT update consumers.
const jQuery = window.jQuery;
export default jQuery;
export { jQuery, jQuery as $ };
