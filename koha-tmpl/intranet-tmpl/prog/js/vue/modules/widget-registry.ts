import { Component, defineAsyncComponent, markRaw } from "vue";

declare global {
    interface Window {
        __kohaWidgetRegistry?: Map<string, WidgetRegistryEntry>;
    }
}

/**
 * Metadata that the ModuleDashboard/WidgetPicker needs to display
 * a widget in the picker and on the dashboard.
 *
 * The `component` field is the raw Vue component (or an async wrapper)
 * and must expose the same contract as core widgets:
 *   - props: display (String), dashboardColumn (String)
 *   - emits: removed, added, moveWidget
 *   - uses useBaseWidget() internally
 */
export interface WidgetRegistryEntry {
    /** Unique identifier — must match the widget's `id` in useBaseWidget(). */
    id: string;
    /**
     * The module this widget belongs to (e.g. "erm", "preservation").
     * Plugins should use their own namespace (e.g. "plugin-myplugin").
     */
    module: string;
    /**
     * Either a raw Vue component or an async function that resolves to one.
     * If async, it will be wrapped in defineAsyncComponent automatically.
     */
    component: Component | (() => Promise<Component>);
}

/**
 * Shared widget registry on window so separate bundles
 * (erm.js, islands.esm.js) operate on the same Map.
 */
function getOrCreateRegistry(): Map<string, WidgetRegistryEntry> {
    if (!window.__kohaWidgetRegistry) {
        window.__kohaWidgetRegistry = new Map();
    }
    return window.__kohaWidgetRegistry;
}

const widgetRegistry = getOrCreateRegistry();

/**
 * Register a dashboard widget.
 *
 * Plugins call this from their intranet_js() hook.
 *
 * All Vue module bundles share a single Vue instance via the import map
 * (see doc-head-close.inc), so both Composition API (ref, reactive, etc.)
 * and Options API (data, methods, render) work correctly in plugin widgets.
 *
 * Plugins import from the islands ESM bundle which re-exports Vue APIs
 * and widget helpers (useBaseWidget, WidgetWrapper).
 *
 * @example
 * ```js
 * const {
 *     registerWidget, useBaseWidget, WidgetWrapper, h, ref,
 * } = await import(islandsSrc);
 * registerWidget({
 *     id: "PluginMyWidget",
 *     module: "erm",
 *     component: {
 *         name: "PluginMyWidget",
 *         props: { display: String, dashboardColumn: String },
 *         emits: ["removed", "added", "moveWidget"],
 *         setup(props, { emit }) {
 *             const base = useBaseWidget({
 *                 id: "PluginMyWidget",
 *                 name: "My Widget",
 *                 icon: "fas fa-puzzle-piece",
 *                 ...props,
 *             }, emit);
 *             const count = ref(0);
 *             base.onDashboardMounted(() => { base.loading.value = false; });
 *             return () => h(WidgetWrapper, base.widgetWrapperProps.value, {
 *                 default: () => [h("button", { onClick: () => count.value++ },
 *                     `Clicked ${count.value} times`)],
 *             });
 *         },
 *     },
 * });
 * ```
 */
export function registerWidget(entry: WidgetRegistryEntry): void {
    if (!entry.id) {
        console.warn("[widget-registry] Widget must have an id, skipping.");
        return;
    }
    if (!entry.module) {
        console.warn(
            `[widget-registry] Widget "${entry.id}" must specify a module, skipping.`
        );
        return;
    }
    if (!entry.component) {
        console.warn(
            `[widget-registry] Widget "${entry.id}" must provide a component, skipping.`
        );
        return;
    }
    if (widgetRegistry.has(entry.id)) {
        console.warn(
            `[widget-registry] Widget "${entry.id}" is already registered, skipping.`
        );
        return;
    }
    // Resolve the component once at registration time so
    // getRegisteredWidgets always returns the same object reference.
    let component: Component & { name?: string };
    if (typeof entry.component === "function") {
        component = defineAsyncComponent(
            entry.component as () => Promise<Component>
        );
    } else {
        component = entry.component;
    }
    if (!component.name) {
        component.name = entry.id;
    }
    entry.component = markRaw(component);

    widgetRegistry.set(entry.id, entry);
    window.dispatchEvent(
        new CustomEvent("koha:widget-registered", {
            detail: { id: entry.id, module: entry.module },
        })
    );
}

/**
 * Returns all registered widgets for a given module as an array of
 * raw Vue components ready for <component :is="widget">.
 *
 * Reads from the shared window registry so it picks up widgets
 * registered by any bundle (erm.js, islands.esm.js, plugins).
 */
export function getRegisteredWidgets(module: string): Component[] {
    const widgets: Component[] = [];
    for (const entry of widgetRegistry.values()) {
        if (entry.module !== module) continue;
        widgets.push(entry.component);
    }
    return widgets;
}
