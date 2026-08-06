import { onBeforeUnmount, onMounted } from "vue";

// Indentation step, in pixels, of a single tree level. Matches the `indent`
// default of the jquery.treetable plugin used by acqui-home.pl, whose
// stylesheet (lib/jquery/plugins/treetable/stylesheets/jquery.treetable.css)
// also styles the indenter and its expander arrow here.
const TREE_INDENT = 19;

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
 * Adds hierarchical (tree) behaviour to a KohaTable/DataTable, formatted to match the
 * funds table on acqui-home.pl: every node is indented inside one column by a
 * `span.indenter` whose padding-left is depth * 19px, carrying the jquery.treetable
 * expander arrow driven by the `tr.expanded` / `tr.collapsed` row classes. Descendants
 * are revealed as aligned rows via DataTables' native row.child() API, which keeps the
 * table compatible with server-side paging (unlike the jquery.treetable plugin, which
 * needs the whole tree in the DOM).
 *
 * The children field is expected to hold a FLAT list of every descendant at all depths
 * (see the `all_sub_funds` API embed); the hierarchy is rebuilt client-side by matching
 * `parentField` against `idField`.
 *
 * The indenter is injected into each row's first cell still in the DOM on every draw,
 * rather than through a column renderer, so a hidden first column cannot swallow it.
 *
 * Self-registers the lifecycle hooks it needs, so the caller invokes it once in
 * setup() and the rest is encapsulated. Call it BEFORE the host's own
 * onBeforeUnmount registration so the handlers are torn down in the right order.
 *
 * Descendant row objects are stamped with `_tree_depth` and `_tree_has_children`; consumers
 * may read `_tree_has_children` (e.g. in an action's `should_display`) to tell whether a row
 * has children, since nested rows carry no children field of their own.
 *
 * @param {Object}      params
 * @param {Object|null} params.tree         - Tree config, or null to disable (no hooks registered).
 *   Shape: { childrenField, idField, parentField, defaultExpanded?, column? }, where
 *   `column` is the `name`/`data` of the column that carries the indenter (defaults to
 *   the first visible column, as jquery.treetable does).
 * @param {Object}      params.tableRef      - Template ref to the <DataTable> (exposes `.dt`).
 * @param {import('vue').Ref<Array>} params.tableColumns - The column defs ref the host binds to <DataTable>.
 * @param {Object}      params.actions       - The host's action map, used to delegate clicks on child rows.
 * @param {Function}    params.onAction      - Called as (name, rowData, dt, event) for a child-row action click.
 * @returns {Object} `{ expandAll, collapseAll }` for the host's tree toolbar (no-ops when disabled).
 */
export function useTreeTable({
    tree,
    tableRef,
    tableColumns,
    actions,
    onAction,
}) {
    if (!tree) return { expandAll: () => {}, collapseAll: () => {} };

    const cf = tree.childrenField;
    const idField = tree.idField;

    // Ids of the nodes whose children are currently expanded. Held in memory so
    // the state survives server-side redraws (paging/sort/search recreate the row
    // nodes). Resets on a full page reload.
    const expandedIds = new Set();

    // Top-level row ids already considered for `defaultExpanded`, so a subtree the
    // user deliberately collapsed is not reopened on the next draw.
    const seededIds = new Set();

    const childrenOf = (node, descendants) =>
        descendants.filter(d => d[tree.parentField] === node[idField]);

    const hasChildren = (node, descendants) =>
        descendants.some(d => d[tree.parentField] === node[idField]);

    // Open every branch of a subtree, including its root.
    const expandSubtree = row => {
        const descendants = row[cf] || [];
        if (!descendants.length) return;
        expandedIds.add(row[idField]);
        descendants.forEach(descendant => {
            if (hasChildren(descendant, descendants))
                expandedIds.add(descendant[idField]);
        });
    };

    // The treetable indenter: a fixed-width span per depth level, carrying the
    // expander anchor on branch nodes only. Leaves keep an empty span so their
    // content stays aligned with their siblings'.
    const indenterHtml = (depth, branch) =>
        `<span class="indenter" style="padding-left: ${
            depth * TREE_INDENT
        }px">${branch ? '<a href="#">&nbsp;</a>' : ""}</span>`;

    // The column definitions behind the cells DataTables actually puts in the DOM.
    // Hidden columns produce no <td>, so child rows must skip them too or every
    // subtree ends up one cell wider than its parent.
    const visibleColumnIndexes = dt =>
        dt.columns(":visible").indexes().toArray();

    const visibleColumns = dt =>
        visibleColumnIndexes(dt).map(i => tableColumns.value[i]);

    // Position, among the cells actually rendered, of the column carrying the
    // indenter. Mirrors treetable's `column` option but resolved against visible
    // columns, so a hidden column cannot swallow the indenter. Defaults to the
    // first visible cell, which is what jquery.treetable itself uses.
    const indenterPosition = dt => {
        if (!tree.column) return 0;
        const position = visibleColumnIndexes(dt).findIndex(i => {
            const col = tableColumns.value[i];
            if (!col) return false;
            return (
                col.name === tree.column ||
                col.data === tree.column ||
                String(col.data ?? "").split(":")[0] === tree.column
            );
        });
        return position === -1 ? 0 : position;
    };

    // Build the rows for every visible descendant of `node` as real <tr> elements
    // (one <td> per visible column) so they align with the parent's columns and
    // border grid. DataTables' row.child() inserts a <tr> collection as-is into the
    // same <tbody>. Cells reuse the column renderers and replicate the display
    // escaping that the "_all" columnDef applies, since child cells bypass the
    // DataTables render pipeline.
    const buildChildRows = (dt, node, ownerNode, descendants, depth) => {
        const settings = dt.settings()[0];
        // Copy the classes DataTables computed on the owning row's cells
        // (dt-type-numeric, custom className, etc.) so child cells match.
        const ownerCells = $(ownerNode).children("td");
        const cols = visibleColumns(dt);
        const indenterAt = indenterPosition(dt);
        return childrenOf(node, descendants).reduce((acc, child) => {
            child._tree_depth = depth;
            child._tree_has_children = hasChildren(child, descendants);
            const expanded = expandedIds.has(child[idField]);
            const cells = cols
                .map((col, i) => {
                    const cls = ownerCells.eq(i).attr("class") || "";
                    // A renderer written for a fully embedded top-level row may not
                    // cope with a nested row, which carries no embeds of its own.
                    // One awkward column must not take the whole tree down with it.
                    let cell = "";
                    try {
                        const value = col?.data ? child[col.data] : null;
                        cell =
                            typeof col?.render === "function"
                                ? col.render(value, "display", child, {
                                      row: -1,
                                      col: i,
                                      settings,
                                  })
                                : value != null
                                  ? escape_str(String(value))
                                  : "";
                    } catch (e) {
                        cell = "";
                    }
                    if (i === indenterAt) {
                        cell =
                            indenterHtml(depth, child._tree_has_children) +
                            (cell || "");
                    }
                    return `<td class="${cls}">${cell || ""}</td>`;
                })
                .join("");
            const rowClasses = ["tree-child-row"];
            if (child._tree_has_children) {
                rowClasses.push("branch", expanded ? "expanded" : "collapsed");
            } else {
                rowClasses.push("leaf");
            }
            const $tr = $(`<tr class="${rowClasses.join(" ")}">${cells}</tr>`);
            $tr.data("koha-row-data", child);
            acc = acc.add($tr);
            if (expanded) {
                acc = acc.add(
                    buildChildRows(dt, child, ownerNode, descendants, depth + 1)
                );
            }
            return acc;
        }, $());
    };

    // Sync every top-level row's tree classes, indenter and descendant rows to
    // expandedIds. The child collection is rebuilt wholesale rather than patched, so
    // nesting several levels deep never leaves stale or duplicated rows behind.
    const applyTreeState = dt => {
        const indenterAt = indenterPosition(dt);
        dt.rows().every(function () {
            const data = this.data();
            const descendants = data[cf] || [];
            const branch = descendants.length > 0;
            const expanded = branch && expandedIds.has(data[idField]);
            const node = this.node();

            $(node)
                .toggleClass("branch", branch)
                .toggleClass("leaf", !branch)
                .toggleClass("expanded", expanded)
                .toggleClass("collapsed", branch && !expanded);

            // Prepend the indenter to a cell that is actually in the DOM, the way
            // jquery.treetable does (jquery.treetable.js:30), so a hidden column
            // cannot swallow it. Replaced rather than skipped so a row whose branch
            // status changed between draws picks up the right expander.
            const $cell = $(node).children("td").eq(indenterAt);
            if ($cell.length) {
                $cell.children("span.indenter").remove();
                $cell.prepend(indenterHtml(0, branch));
            }

            if (this.child.isShown()) this.child.hide();
            if (!expanded) return;
            this.child(buildChildRows(dt, data, node, descendants, 1)).show();
        });
    };

    // With `defaultExpanded`, open a top-level row's whole subtree the first time it
    // is drawn, matching acqui-home.pl's treetable('expandAll') on page load.
    const seedDefaultExpanded = dt => {
        if (!tree.defaultExpanded) return;
        dt.rows().every(function () {
            const data = this.data();
            if (seededIds.has(data[idField])) return;
            seededIds.add(data[idField]);
            expandSubtree(data);
        });
    };

    // Exposed to the host so it can render the expand/collapse-all controls in its
    // own template, the way acqui-home.pl does above its funds table.
    const expandAll = () => {
        const dt = tableRef.value?.dt;
        if (!dt) return;
        dt.rows().every(function () {
            expandSubtree(this.data());
        });
        applyTreeState(dt);
    };
    const collapseAll = () => {
        const dt = tableRef.value?.dt;
        if (!dt) return;
        expandedIds.clear();
        applyTreeState(dt);
    };

    onMounted(() => {
        const dt = tableRef.value.dt;
        const tableNode = dt.table().node();
        // Picks up the indenter and expander arrow styling from
        // lib/jquery/plugins/treetable/stylesheets/jquery.treetable.css.
        $(tableNode).addClass("treetable");

        $(tableNode).on("click.tree", "span.indenter a", function (e) {
            e.preventDefault();
            const $tr = $(this).closest("tr");
            const data = $tr.hasClass("tree-child-row")
                ? $tr.data("koha-row-data")
                : dt.row($tr).data();
            if (!data) return;
            const id = data[idField];
            if (expandedIds.has(id)) {
                expandedIds.delete(id);
            } else {
                expandedIds.add(id);
            }
            applyTreeState(dt);
        });

        dt.on("draw", () => {
            seedDefaultExpanded(dt);
            applyTreeState(dt);
        });

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
            $(dt.table().node()).off("click.tree");
            $(dt.table().node()).off(".tree-actions");
        }
    });

    return { expandAll, collapseAll };
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
