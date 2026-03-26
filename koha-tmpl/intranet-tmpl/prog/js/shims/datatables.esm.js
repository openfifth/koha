// ESM shim for DataTables — exposes the global loaded by the classic <script> tag.
// Used via import map so ESM bundles can `import DataTable from "datatables.net"`.
const DataTable = window.DataTable;
export default DataTable;
export { DataTable };
