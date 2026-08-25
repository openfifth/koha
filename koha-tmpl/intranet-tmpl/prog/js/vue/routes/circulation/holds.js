import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/circ/circulation-home.pl",
        is_default: true,
        is_base: true,
        title: $__("Circulation"),
        children: [],
    },
];
