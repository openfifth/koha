import { markRaw } from "vue";

import Home from "../components/Plugin-store/Home.vue";

import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/plugin-store/plugin-store.pl",
        redirect: "/cgi-bin/koha/plugin-store/home",
        is_default: true,
        is_base: true,
        title: $__("Plugins"),
        children: [
            {
                path: "/cgi-bin/koha/plugin-store/home",
                title: $__("Home"),
                icon: "fa fa-puzzle-piece",
                is_end_node: true,
                children: [
                    {
                        path: "",
                        name: "Home",
                        component: markRaw(Home),
                    },
                ],
            },
        ],
    },
];
