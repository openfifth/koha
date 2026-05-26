import { markRaw } from "vue";

import Home from "../components/Display/Home.vue";
import DisplaysBatchAddItems from "../components/Display/DisplaysBatchAddItems.vue";
import DisplaysBatchRemoveItems from "../components/Display/DisplaysBatchRemoveItems.vue";

import ResourceWrapper from "../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "",
        name: "Home",
        component: markRaw(Home),
        redirect: "/cgi-bin/koha/display/displays",
        is_navigation_item: false,
    },
    {
        path: "/cgi-bin/koha/display/displays",
        title: $__("Displays"),
        icon: "fa-solid fa-image-portrait",
        is_end_node: true,
        resource: "Display/DisplaysResource.vue",
        children: [
            {
                path: "",
                name: "DisplaysList",
                component: markRaw(ResourceWrapper),
            },
            {
                path: ":display_id",
                name: "DisplaysShow",
                component: markRaw(ResourceWrapper),
                title: "{display_name}",
            },
            {
                path: "add",
                name: "DisplaysFormAdd",
                component: markRaw(ResourceWrapper),
                title: $__("Add display"),
            },
            {
                path: "edit/:display_id",
                name: "DisplaysFormAddEdit",
                component: markRaw(ResourceWrapper),
                title: "{display_name}",
                breadcrumbFormat: ({ match, params, query }) => {
                    match.name = "DisplaysShow";
                    return match;
                },
                additionalBreadcrumbs: [
                    { title: $__("Modify display"), disabled: true },
                ],
            },
            {
                path: "batch-add",
                name: "DisplaysBatchAddItems",
                component: markRaw(DisplaysBatchAddItems),
                title: $__("Batch add items from list"),
            },
            {
                path: "batch-remove",
                name: "DisplaysBatchRemoveItems",
                component: markRaw(DisplaysBatchRemoveItems),
                title: $__("Batch remove items from list"),
            },
        ],
    },
];
