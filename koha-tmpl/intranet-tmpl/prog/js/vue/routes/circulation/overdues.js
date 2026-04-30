import { markRaw } from "vue";

import ResourceWrapper from "../../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export default {
    title: $__("Circulation"),
    path: "",
    href: "/cgi-bin/koha/circ/circulation-home.pl",
    is_base: true,
    is_default: true,
    children: [
        {
            title: $__("Overdues"),
            path: "/cgi-bin/koha/circulation/overdues",
            is_end_node: true,
            resource: "Circulation/Overdues/OverduesResource.vue",
            children: [
                {
                    path: "",
                    name: "OverduesList",
                    component: markRaw(ResourceWrapper),
                    alternateLeftMenu: () =>
                        import(
                            /* webpackChunkName: "overdues-filters" */
                            "../../components/Circulation/Overdues/OverdueFilters.vue"
                        ),
                },
            ],
        },
        {
            title: $__("Branch overdues"),
            path: "/cgi-bin/koha/circulation/overdues/branch",
            is_end_node: true,
            resource: "Circulation/Overdues/BranchOverduesResource.vue",
            children: [
                {
                    path: "",
                    name: "BranchOverduesList",
                    component: markRaw(ResourceWrapper),
                    alternateLeftMenu: () =>
                        import(
                            /* webpackChunkName: "circ-nav" */
                            "../../components/Islands/CircNav.vue"
                        ),
                },
            ],
        },
    ],
};
