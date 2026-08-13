import { markRaw } from "vue";

import Home from "../components/Plugin-store/Home.vue";

import { $__ } from "../i18n";

export const routes = [
    {
        path: "",
        href: "/cgi-bin/koha/admin/admin-home.pl",
        is_default: true,
        is_base: true,
        title: $__("Administration"),
        children: [
            {
                path: "/cgi-bin/koha/plugin-store/plugin-store.pl",
                redirect: "/cgi-bin/koha/plugin-store/home",
                title: $__("Plugins"),
                is_end_node: true,
                children: [
                    {
                        path: "/cgi-bin/koha/plugin-store/home",
                        name: "Home",
                        component: markRaw(Home),
                    },
                ],
            },
        ],
    },
];
