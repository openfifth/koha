// ESM shim for jQuery — exposes the global loaded by the classic <script> tag.
// Used via import map so ESM bundles can `import $ from "jquery"`.
const jQuery = window.jQuery;
export default jQuery;
export { jQuery, jQuery as $ };
