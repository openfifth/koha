import { markRaw } from "vue";

import StorePluginsList from "../components/Plugin-store/StorePluginsList.vue";

import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/plugin-store/plugin-store.pl",
        redirect: "/cgi-bin/koha/plugin-store/store-plugins",
        is_default: true,
        is_base: true,
        title: $__("Plugins store"),
        children: [
            {
                path: "/cgi-bin/koha/plugin-store/store-plugins",
                title: $__("Store plugins"),
                icon: "fa fa-check-circle",
                is_end_node: true,
                children: [
                    {
                        path: "",
                        name: "StorePluginsList",
                        component: markRaw(StorePluginsList),
                    },
                ],
            },
        ],
    },
];
