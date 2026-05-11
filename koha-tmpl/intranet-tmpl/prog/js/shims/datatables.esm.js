// ESM shim for DataTables — exposes the global loaded by the classic <script> tag.
// Used via import map so ESM bundles can `import DataTable from "datatables.net"`.
//
// IMPORTANT: This is a read-once snapshot, NOT a live binding. window.DataTable
// is read at module evaluation time and the value is captured into the
// exported bindings. The classic DataTables <script> tag MUST execute
// before any ESM bundle that imports from "datatables.net" — see
// jquery.esm.js for the full set of consequences (same applies here).
const DataTable = window.DataTable;
export default DataTable;
export { DataTable };
