import { markRaw } from "vue";

import PlaceHold from "../../components/Circulation/Holds/PlaceHold.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/circ/circulation-home.pl",
        is_default: true,
        is_base: true,
        title: $__("Circulation"),
        children: [
            {
                path: "/cgi-bin/koha/reserve/request.pl",
                name: "PlaceHold",
                component: markRaw(PlaceHold),
                title: $__("Place a hold"),
                is_navigation_item: false,
            },
        ],
    },
];
