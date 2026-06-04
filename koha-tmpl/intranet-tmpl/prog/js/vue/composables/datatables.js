import { onBeforeMount, onBeforeUnmount, onMounted } from "vue";

export function useDataTable(table_id) {
    onBeforeUnmount(() => {
        if ($.fn.DataTable.isDataTable("#" + table_id)) {
            $("#" + table_id)
                .DataTable()
                .destroy(true);
        }
    });
}

/**
 * Adds hierarchical (tree) behaviour to a KohaTable/DataTable: parent rows are
 * shown collapsed, with their children revealed as aligned child rows via
 * DataTables' native row.child() API.
 *
 * Self-registers the lifecycle hooks it needs, so the caller invokes it once in
 * setup() and the rest is encapsulated. Call it BEFORE the host's own
 * onBeforeMount/onBeforeUnmount registrations so the control column is prepended
 * and the click handler is torn down in the right order.
 *
 * @param {Object}      params
 * @param {Object|null} params.tree         - Tree config, or null to disable (no hooks registered).
 *   Shape: { childrenField, idField, parentField?, defaultExpanded? }.
 * @param {Object}      params.tableRef      - Template ref to the <DataTable> (exposes `.dt`).
 * @param {import('vue').Ref<Array>} params.tableColumns - The column defs ref the host binds to <DataTable>.
 */
export function useTreeTable({ tree, tableRef, tableColumns, actions, onAction }) {
    if (!tree) return;

    const cf = tree.childrenField;
    const idField = tree.idField;

    // Ids of the parent rows whose child rows are currently expanded. Held in
    // memory so the state survives server-side redraws (paging/sort/search
    // recreate the row nodes). Resets on a full page reload.
    const expandedIds = new Set();

    // Build child rows for a parent as real <tr> elements (one <td> per parent
    // column, with an empty cell under the toggle column) so they align with the
    // parent's columns and border grid. DataTables' row.child() inserts a <tr>
    // collection as-is into the same <tbody>. Cells reuse the parent column
    // renderers and replicate the display escaping that the "_all" columnDef
    // applies, since child cells bypass the DataTables render pipeline.
    const buildChildRows = (parentRow, parentNode) => {
        let children = parentRow[cf] || [];
        if (tree.parentField) {
            children = children.filter(
                child => child[tree.parentField] === parentRow[idField]
            );
        }
        const settings = tableRef.value.dt.settings()[0];
        // Copy the classes DataTables computed on the parent's cells
        // (dt-type-numeric, custom className, etc.) so child cells match.
        const parentCells = $(parentNode).children("td");
        return children.reduce((acc, child) => {
            const cells = tableColumns.value
                .map((col, i) => {
                    const cls = parentCells.eq(i).attr("class") || "";
                    if (col.name === "tree-control") {
                        return `<td class="${cls}"></td>`;
                    }
                    const value = col.data ? child[col.data] : null;
                    const cell =
                        typeof col.render === "function"
                            ? col.render(value, "display", child, {
                                  row: -1,
                                  col: i,
                                  settings,
                              })
                            : value != null
                              ? escape_str(String(value))
                              : "";
                    return `<td class="${cls}">${cell || ''}</td>`;
                })
                .join("");
            const $tr = $(`<tr class="tree-child-row">${cells}</tr>`);
            $tr.data("koha-row-data", child);
            return acc.add($tr);
        }, $());
    };

    // Sync every row's child visibility and toggle icon to expandedIds. Uses
    // isShown() guards so re-running on each draw never duplicates a child row.
    const applyTreeState = dt => {
        dt.rows().every(function () {
            const data = this.data();
            if (!data[cf]?.length) return;
            const expanded = expandedIds.has(data[idField]);
            const toggle = $(".tree-toggle", this.node());
            if (expanded && !this.child.isShown()) {
                this.child(buildChildRows(data, this.node())).show();
            }
            if (!expanded && this.child.isShown()) {
                const $childNodes = $(this.node()).nextUntil(
                    ":not(.tree-child-row)"
                );
                if (!$childNodes.first().hasClass("tree-child-row-collapsing")) {
                    const dtRow = this;
                    $childNodes.addClass("tree-child-row-collapsing");
                    $childNodes.first().one("animationend.tree-collapse", function () {
                        dtRow.child.hide();
                    });
                }
            }
            toggle
                .toggleClass("fa-minus-circle", expanded)
                .toggleClass("fa-plus-circle", !expanded);
        });
    };

    onBeforeMount(() => {
        tableColumns.value = [
            {
                name: "tree-control",
                className: "tree-control",
                title: "",
                orderable: false,
                searchable: false,
                data: null,
                render: (data, type, row) =>
                    row[cf]?.length
                        ? '<i class="tree-toggle fa fa-plus-circle" role="button"></i>'
                        : "",
            },
            ...tableColumns.value,
        ];
    });

    onMounted(() => {
        const dt = tableRef.value.dt;
        const tableNode = dt.table().node();
        $(tableNode).on(
            "click",
            "td.tree-control .tree-toggle",
            function () {
                const row = dt.row($(this).closest("tr"));
                const id = row.data()[idField];
                if (expandedIds.has(id)) {
                    expandedIds.delete(id);
                } else {
                    expandedIds.add(id);
                }
                applyTreeState(dt);
            }
        );
        dt.on("draw", () => applyTreeState(dt));

        if (actions && onAction) {
            Object.values(actions).forEach(colActions => {
                colActions.forEach(action => {
                    const actionName =
                        typeof action === "object"
                            ? Object.keys(action)[0]
                            : action;
                    const shouldDisplay =
                        typeof action === "object"
                            ? action[actionName].should_display
                            : null;
                    $(tableNode).on(
                        "click.tree-actions",
                        `.tree-child-row .${actionName}`,
                        function (e) {
                            const data = $(this)
                                .closest(".tree-child-row")
                                .data("koha-row-data");
                            if (!data) return;
                            if (
                                typeof shouldDisplay === "function" &&
                                !shouldDisplay(data)
                            )
                                return;
                            onAction(actionName, data, dt, e);
                        }
                    );
                });
            });
        }
    });

    onBeforeUnmount(() => {
        const dt = tableRef.value?.dt;
        if (dt) {
            $(dt.table().node()).off("click", "td.tree-control .tree-toggle");
            $(dt.table().node()).off(".tree-actions");
        }
    });
}

export function build_url_params(filters) {
    return Object.entries(filters)
        .map(([k, v]) => (v ? k + "=" + v : undefined))
        .filter(e => e !== undefined)
        .join("&");
}
export function build_url(base_url, filters) {
    let params = build_url_params(filters);
    return base_url + (params.length ? "?" + params : "");
}
